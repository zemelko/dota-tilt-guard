import Foundation
import AVFoundation
import Speech
import CoreMedia
import CalmChatCore

@available(macOS 26, *)
@MainActor final class VoiceRecognizer {
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var feed: SpeechAudioFeed?
    var onResult: ((String, [VoiceWord]) -> Void)?
    var onError: ((String) -> Void)?

    func prepare(language: String, inputFormat: AVAudioFormat) async throws -> (AVAudioPCMBuffer) -> Void {
        let locale = Locale(identifier: language)
        guard let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale),
              await DictationTranscriber.installedLocales.contains(where: { $0.identifier == supported.identifier }) else {
            throw VoiceError.message("Локальная модель этого языка не установлена. Включи диктовку для него в настройках macOS, затем попробуй снова.")
        }
        try Task.checkCancellation()
        // Explicitly omit etiquetteReplacements so profanity is not replaced by asterisks.
        let transcriber = DictationTranscriber(locale: supported, contentHints: [], transcriptionOptions: [], reportingOptions: [.volatileResults, .frequentFinalization], attributeOptions: [.audioTimeRange])
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .whileInUse))
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw VoiceError.message("Локальное распознавание не подготовило формат звука.")
        }
        try await analyzer.prepareToAnalyze(in: format)
        try Task.checkCancellation()
        self.analyzer = analyzer
        let stream = AsyncStream<AnalyzerInput>(bufferingPolicy: .bufferingNewest(64)) { self.continuation = $0 }
        guard let continuation else { throw VoiceError.message("Не удалось открыть поток распознавания.") }
        let feed = try SpeechAudioFeed(inputFormat: inputFormat, outputFormat: format, continuation: continuation)
        feed.onError = { [weak self] message in Task { @MainActor in self?.onError?(message) } }
        self.feed = feed
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard !Task.isCancelled else { return }
                    let text = String(result.text.characters)
                    // Volatile results do not have word times; final results add them.
                    // Anchor to the utterance instead, so finalization cannot mute old words again.
                    let start = result.range.start.seconds
                    guard start.isFinite else { continue }
                    let segment = Int64((start * 100).rounded())
                    let words = text.split(whereSeparator: { $0.isWhitespace }).enumerated().map {
                        VoiceWord(String($0.element), id: "\(segment):\($0.offset)")
                    }
                    self?.onResult?(text, words)
                }
                if !Task.isCancelled { self?.onError?("Распознавание остановилось. Перезапусти голосовую защиту.") }
            } catch {
                if !Task.isCancelled { self?.onError?("Ошибка локального распознавания: \(error.localizedDescription)") }
            }
        }
        analysisTask = Task { [weak self] in
            do { _ = try await analyzer.analyzeSequence(stream) }
            catch { if !Task.isCancelled { self?.onError?("Распознавание не получает звук: \(error.localizedDescription)") } }
        }
        return { buffer in feed.consume(buffer) }
    }

    func stop() {
        feed?.stop(); feed = nil
        continuation?.finish(); continuation = nil
        resultsTask?.cancel(); analysisTask?.cancel()
        resultsTask = nil; analysisTask = nil
        if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
        analyzer = nil
    }
}

/// Accessed serially from the capture queue. The only cross-thread action is stop.
@available(macOS 26, *)
private final class SpeechAudioFeed: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let lock = NSLock()
    private var stopped = false
    private var frames: Int64 = 0
    var onError: ((String) -> Void)?
    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { throw VoiceError.message("Не удалось преобразовать звук для распознавания.") }
        self.converter = converter; self.continuation = continuation
    }
    func stop() { lock.lock(); stopped = true; lock.unlock() }
    func consume(_ input: AVAudioPCMBuffer) {
        lock.lock(); let inactive = stopped; lock.unlock()
        guard !inactive else { return }
        do {
            guard let output = try VoiceAudio.convert(input, with: converter) else { return }
            let start = CMTime(value: frames, timescale: CMTimeScale(output.format.sampleRate))
            frames += Int64(output.frameLength)
            if case .dropped = continuation.yield(AnalyzerInput(buffer: output, bufferStartTime: start)) {
                stop(); onError?("Распознавание не успевает за звуком. Перезапусти голосовую защиту.")
            }
        } catch { stop(); onError?(error.localizedDescription) }
    }
}
