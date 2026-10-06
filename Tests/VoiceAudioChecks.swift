import Foundation
import AVFoundation

@main struct VoiceAudioChecks {
    static func main() throws {
        let queue = VoicePCMQueue()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16)!
        output.frameLength = 16
        func push(_ samples: [Float]) { samples.withUnsafeBufferPointer { queue.push($0.baseAddress!, count: $0.count) } }
        func render() -> [Float] {
            queue.render(16, buffers: UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList))
            let left = Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: 16))
            let right = Array(UnsafeBufferPointer(start: output.floatChannelData![1], count: 16))
            precondition(left == right, "Both output channels must match")
            return left
        }
        push([0.7, 0.5]); precondition(render().allSatisfy { $0 == 0 }, "Initially silent")
        precondition(queue.metrics().0 == 0.7 && queue.metrics().1 > 0, "Input is monitored while muted")
        queue.setMuted(false)
        precondition(render().allSatisfy { $0 == 0 }, "Muted speech must never be replayed")
        push([0.25, -0.5]); let sent = render()
        precondition(sent[0] == 0.25 && sent[1] == -0.5 && sent.dropFirst(2).allSatisfy { $0 == 0 })
        push([0.9, 0.8]); queue.setMuted(true)
        precondition(render().allSatisfy { $0 == 0 }, "Mute flushes queued audio immediately")
        push([0.6]); queue.setMuted(false)
        precondition(render().allSatisfy { $0 == 0 }, "Resume does not replay blocked speech")
        push([0.1]); precondition(render()[0] == 0.1, "Fresh audio resumes")
        push(Array(repeating: 0.4, count: 7000)); push(Array(repeating: 0.2, count: 1000))
        precondition(render().allSatisfy { $0 == 0.2 }, "Discard stale backlog")

        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4410)!
        input.frameLength = 4410
        for i in 0..<4410 { input.floatChannelData![0][i] = 0.2 }
        let copied = VoiceAudio.copy(input)!
        input.floatChannelData![0][0] = 0
        precondition(copied.floatChannelData![0][0] == 0.2, "Capture buffer must be independent")
        let target = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let converter = AVAudioConverter(from: inputFormat, to: target)!
        let converted = try VoiceAudio.convert(copied, with: converter)!
        // The first buffer is shorter due to the converter's priming latency.
        precondition(converted.frameLength > 4000 && converted.frameLength <= 4800, "Initial sample rate conversion: \(converted.frameLength) frames")
        precondition(converted.floatChannelData![0][100] > 0.15, "Converted audio retains signal")
        var total = Int(converted.frameLength)
        for _ in 1..<20 {
            total += Int(try VoiceAudio.convert(copied, with: converter)!.frameLength)
        }
        // Converter output chunks can vary while its internal priming buffer drains.
        precondition(abs(total - 96000) < 1024, "Continuous conversion must preserve duration: \(total)")
        print("PASS: audio mute, continued input metering, flush, resume, stereo output, queue bound, PCM copy, sample rate conversion")
    }
}
