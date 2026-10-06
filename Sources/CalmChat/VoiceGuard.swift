import AppKit
import AVFoundation
import Combine
import CoreAudio
import CalmChatCore

@MainActor final class VoiceGuard: ObservableObject {
    static let shared = VoiceGuard()
    @Published var devices: [AudioDevice] = []
    @Published var selectedInput: AudioDeviceID = 0
    @Published var language = "ru-RU"
    @Published private(set) var bridgePresent = false
    @Published private(set) var enabled = false
    @Published private(set) var starting = false
    @Published private(set) var muted = true
    @Published private(set) var remaining: Double = 0
    @Published private(set) var level: Float = 0
    @Published private(set) var detections = 0
    @Published private(set) var status: UIMessage = "Голосовая защита выключена"
    @Published private(set) var transcript = ""
    private var gate = VoiceGate()
    private var audio: VoiceAudio?
    private var stopRecognizer: (() -> Void)?
    private var startTask: Task<Void, Never>?
    private var timer: Timer?
    private var fault: UIMessage?
    private var priorInput: AudioDeviceID?
    private var virtualInput: AudioDeviceID?
    private var startedAt: TimeInterval = 0
    private var generation = 0
    private init() { refreshDevices() }

    var headline: UIMessage {
        if starting { return "Подготовка микрофона…" }
        if !enabled { return "Голосовая защита выключена" }
        if fault != nil { return "Передача отключена · нужна проверка" }
        return muted ? "В игру идёт тишина" : "Голос передаётся"
    }
    func refreshDevices() {
        let all = AudioDevices.list()
        bridgePresent = all.contains(where: \.isVoiceBridge)
        devices = all.filter { $0.inputChannels > 0 && !$0.isVoiceBridge }
        if !devices.contains(where: { $0.id == selectedInput }) {
            let preferred = AudioDevices.defaultInput()
            selectedInput = devices.first(where: { $0.id == preferred })?.id ?? devices.first?.id ?? 0
        }
    }
    func start() {
        guard !enabled && !starting else { return }
        guard #available(macOS 26, *) else { status = "Для локального голосового режима нужна macOS 26 или новее."; return }
        refreshDevices()
        guard let bridge = AudioDevices.list().first(where: \.isVoiceBridge), selectedInput != 0 else {
            status = "Нужны микрофон и установленный BlackHole 2ch. После установки нажми «Обновить устройства»."; return
        }
        starting = true; muted = true; transcript = ""; detections = 0; fault = nil
        generation += 1; let current = generation
        let input = selectedInput, language = language
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                let allowed = await AVCaptureDevice.requestAccess(for: .audio)
                try Task.checkCancellation()
                guard allowed else { throw VoiceError.message("Разреши Dota Tilt Guard доступ к микрофону в настройках macOS.") }
                // Set the system default before creating engines. Changing it after starting
                // an AVAudioEngine can migrate its input to the virtual device.
                let previous = AudioDevices.defaultInput()
                self.priorInput = previous == bridge.id ? input : previous
                self.virtualInput = bridge.id
                try AudioDevices.setDefaultInput(bridge.id)
                let audio = VoiceAudio()
                self.audio = audio
                let format = try audio.prepare(input: input, output: bridge.id)
                let recognizer = VoiceRecognizer()
                self.stopRecognizer = { recognizer.stop() }
                recognizer.onResult = { [weak self] text, words in
                    guard let self, self.generation == current, self.enabled else { return }
                    self.transcript = String(text.suffix(220))
                    _ = self.gate.observe(words, now: ProcessInfo.processInfo.systemUptime)
                    self.detections = self.gate.detections
                    self.tick()
                }
                recognizer.onError = { [weak self] message in
                    guard let self, self.generation == current else { return }
                    self.fail(message)
                }
                let consume = try await recognizer.prepare(language: language, inputFormat: format)
                try Task.checkCancellation()
                guard self.generation == current else { return }
                audio.onError = { [weak self] message in
                    Task { @MainActor in
                        guard let self, self.generation == current else { return }
                        self.fail(message)
                    }
                }
                try audio.start(inputFormat: format, consume: consume)
                self.gate = VoiceGate()
                self.startedAt = ProcessInfo.processInfo.systemUptime
                self.enabled = true; self.starting = false
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.tick() }
                }
                self.tick()
            } catch {
                guard self.generation == current else { return }
                let restoration = self.cleanup()
                self.starting = false; self.enabled = false
                self.status = .joined([voiceMessage(error), restoration].compactMap { $0 }, " ")
            }
        }
    }
    func testMute() {
        guard enabled, fault == nil else { return }
        gate.mute(now: ProcessInfo.processInfo.systemUptime); tick()
    }
    private func fail(_ message: UIMessage) {
        fault = message; audio?.pcm.setMuted(true); muted = true; status = message
    }
    private func tick() {
        guard enabled, let audio else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let metrics = audio.pcm.metrics()
        level = min(1, metrics.0 * 3)
        if now - max(startedAt, metrics.1) > 3 { fail("Микрофон перестал отдавать звук. Проверь подключение и перезапусти защиту.") }
        if let virtualInput, AudioDevices.defaultInput() != virtualInput {
            fail("Системный микрофон изменился. Перезапусти защиту, чтобы вернуть передачу через фильтр.")
        }
        if let fault { status = fault; muted = true; audio.pcm.setMuted(true); return }
        remaining = gate.remaining(at: now)
        muted = gate.isMuted(at: now)
        audio.pcm.setMuted(muted)
        status = muted ? "Обнаружено ругательство. Возврат голоса через \(String(format: "%.1f", remaining)) с." : audio.routeDescription()
    }
    func stop() {
        generation += 1; startTask?.cancel(); startTask = nil
        let restoration = cleanup()
        enabled = false; starting = false; muted = true; remaining = 0; level = 0; transcript = ""
        status = restoration ?? "Голосовая защита выключена."
    }
    /// A restoration error must remain visible: the user may otherwise be left with a silent input.
    @discardableResult private func cleanup() -> UIMessage? {
        timer?.invalidate(); timer = nil
        audio?.stop(); audio = nil
        stopRecognizer?(); stopRecognizer = nil
        var restoration: UIMessage?
        if let old = priorInput, let bridge = virtualInput, AudioDevices.defaultInput() == bridge {
            do {
                guard AudioDevices.list().contains(where: { $0.id == old }) else {
                    throw VoiceError.message("Прежний микрофон отключён.")
                }
                try AudioDevices.setDefaultInput(old)
            } catch {
                restoration = "Выбери обычный микрофон в настройках macOS → Звук → Вход: автоматически вернуть его не удалось."
            }
        }
        priorInput = nil; virtualInput = nil; fault = nil
        return restoration
    }
}
