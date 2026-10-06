import AVFoundation
import AudioToolbox
import CoreAudio

/// Short mono PCM queue shared by the physical capture and virtual output devices.
/// Muting flushes old audio; capture and recognition remain independent.
final class VoicePCMQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var samples = [Float](repeating: 0, count: 19200)
    private var read = 0, count = 0
    private var muted = true
    private var level: Float = 0
    private var lastInput: TimeInterval = 0
    func setMuted(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        if value != muted { read = 0; count = 0 }
        muted = value
    }
    func push(_ data: UnsafePointer<Float>, count frames: Int) {
        lock.lock(); defer { lock.unlock() }
        var peak: Float = 0
        for i in 0..<frames { peak = max(peak, abs(data[i])) }
        level = peak; lastInput = ProcessInfo.processInfo.systemUptime
        guard !muted else { return }
        // Keep at most 150 ms at 48 kHz. Never replay a stale queue after a stall.
        if count + frames > 7200 { read = 0; count = 0 }
        for i in 0..<min(frames, samples.count) {
            samples[(read + count) % samples.count] = data[i]
            count += 1
        }
    }
    func render(_ frames: Int, buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
        guard lock.try() else { return }
        defer { lock.unlock() }
        guard !muted else { read = 0; count = 0; return }
        let available = min(frames, count)
        for i in 0..<available {
            let value = samples[(read + i) % samples.count]
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for channel in 0..<Int(buffer.mNumberChannels) { data[i * Int(buffer.mNumberChannels) + channel] = value }
            }
        }
        read = (read + available) % samples.count; count -= available
    }
    func metrics() -> (Float, TimeInterval) {
        lock.lock(); defer { lock.unlock() }; return (level, lastInput)
    }
}

final class VoiceAudio {
    let pcm = VoicePCMQueue()
    private let capture = AVAudioEngine()
    private let playback = AVAudioEngine()
    private let queue = DispatchQueue(label: "CalmChat.voice-audio", qos: .userInitiated)
    private var source: AVAudioSourceNode?
    private var tapped = false
    private var active = false
    private var generation = 0
    private let activityLock = NSLock()
    var onError: ((UIMessage) -> Void)?

    func routeDescription() -> UIMessage {
        func current(_ unit: AudioUnit?) -> AudioDeviceID {
            guard let unit else { return 0 }
            var id: AudioDeviceID = 0
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            _ = AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, &size)
            return id
        }
        return "Вход: \(AudioDevices.string(current(capture.inputNode.audioUnit), kAudioObjectPropertyName)) → выход: \(AudioDevices.string(current(playback.outputNode.audioUnit), kAudioObjectPropertyName))"
    }

    func prepare(input: AudioDeviceID, output: AudioDeviceID) throws -> AVAudioFormat {
        let inputNode = capture.inputNode
        let outputNode = playback.outputNode
        try setDevice(inputNode.audioUnit, input)
        try setDevice(outputNode.audioUnit, output)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw VoiceError.message("Микрофон не отдаёт звук. Проверь его подключение.") }
        // One fixed format makes conversion and queue timing predictable.
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let pcm = self.pcm
        let source = AVAudioSourceNode(format: format) { _, _, frames, audio in
            pcm.render(Int(frames), buffers: UnsafeMutableAudioBufferListPointer(audio))
            return noErr
        }
        self.source = source
        playback.attach(source)
        playback.connect(source, to: playback.mainMixerNode, format: format)
        playback.mainMixerNode.outputVolume = 1
        return inputFormat
    }

    func start(inputFormat: AVAudioFormat, consume: @escaping (AVAudioPCMBuffer) -> Void) throws {
        let target = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        guard let converter = AVAudioConverter(from: inputFormat, to: target) else { throw VoiceError.message("Не удалось настроить формат микрофона.") }
        activityLock.lock(); active = true; generation += 1; let current = generation; activityLock.unlock()
        capture.inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let copy = Self.copy(buffer) else { return }
            self.queue.async {
                self.activityLock.lock(); let running = self.active && self.generation == current; self.activityLock.unlock()
                guard running else { return }
                // Recognition always receives the original microphone, including while muted.
                consume(copy)
                do {
                    if let output = try Self.convert(copy, with: converter), let data = output.floatChannelData?[0] {
                        self.pcm.push(data, count: Int(output.frameLength))
                    }
                } catch { self.pcm.setMuted(true); self.onError?(voiceMessage(error)) }
            }
        }
        tapped = true
        playback.prepare(); capture.prepare()
        try playback.start()
        do { try capture.start() } catch { playback.stop(); throw error }
    }

    func stop() {
        pcm.setMuted(true)
        activityLock.lock(); active = false; generation += 1; activityLock.unlock()
        if tapped { capture.inputNode.removeTap(onBus: 0); tapped = false }
        capture.stop(); playback.stop()
    }

    private func setDevice(_ unit: AudioUnit?, _ device: AudioDeviceID) throws {
        guard let unit else { throw VoiceError.message("Аудиоустройство недоступно.") }
        var value = device
        let result = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &value, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard result == noErr else { throw VoiceError.message("Не удалось подключить аудиоустройство (\(result)).") }
    }
    static func copy(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let result = AVAudioPCMBuffer(pcmFormat: input.format, frameCapacity: input.frameLength) else { return nil }
        result.frameLength = input.frameLength
        let src = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input.audioBufferList))
        let dst = UnsafeMutableAudioBufferListPointer(result.mutableAudioBufferList)
        for i in 0..<min(src.count, dst.count) {
            guard let from = src[i].mData, let to = dst[i].mData else { continue }
            memcpy(to, from, Int(min(src[i].mDataByteSize, dst[i].mDataByteSize)))
        }
        return result
    }
    static func convert(_ input: AVAudioPCMBuffer, with converter: AVAudioConverter) throws -> AVAudioPCMBuffer? {
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * converter.outputFormat.sampleRate / input.format.sampleRate)) + 128
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .noDataNow; return nil }
            supplied = true; state.pointee = .haveData; return input
        }
        if status == .error {
            if let error { throw error }
            throw VoiceError.message("Ошибка преобразования звука.")
        }
        return output.frameLength > 0 ? output : nil
    }
}
