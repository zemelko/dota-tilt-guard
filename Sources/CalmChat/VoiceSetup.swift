import AppKit
import Speech
import SwiftUI

@MainActor final class VoiceSetup: ObservableObject {
    static let shared = VoiceSetup()
    @Published var language = "ru-RU"
    @Published private(set) var busy = false
    @Published private(set) var bridgePresent = false
    @Published private(set) var installed = false
    @Published private(set) var status: UIMessage = "Проверка компонентов…"
    private var task: Task<Void, Never>?

    func check() { run(download: false) }
    func install() { run(download: true) }

    private func run(download: Bool) {
        guard !busy else { return }
        bridgePresent = AudioDevices.list().contains(where: \.isVoiceBridge)
        installed = false
        guard #available(macOS 26, *) else {
            status = "Для локального голосового режима нужна macOS 26 или новее."
            return
        }
        busy = true
        status = download ? "macOS загружает язык. Дождись завершения…" : "Проверка компонентов…"
        let selectedLanguage = language
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.task = nil }
            do {
                guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: selectedLanguage)) else {
                    throw VoiceError.message("Этот язык недоступен для локального распознавания на этом Mac.")
                }
                // A download starts only after an explicit click. No microphone is opened here.
                if download {
                    let module = DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
                    if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                        try await request.downloadAndInstall()
                    }
                }
                try Task.checkCancellation()
                self.installed = await DictationTranscriber.installedLocales.contains { $0.identifier == locale.identifier }
                self.status = self.installed ? "Язык установлен. Распознавание работает без интернета." : "Язык ещё не установлен. Для однократной загрузки нужен интернет."
            } catch {
                self.status = "Не удалось подготовить язык: \(voiceMessage(error))"
            }
        }
    }
}

struct VoiceSetupView: View {
    @ObservedObject private var setup = VoiceSetup.shared
    @ObservedObject private var ui = InterfaceSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(ui("Установка компонентов")).font(.title2.bold())
                Spacer()
                Button(ui("Готово")) { dismiss() }
            }
            Text(ui("Текстовый фильтр готов к работе: ему нужен только доступ Accessibility. Компоненты ниже нужны для голоса."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Label(ui(setup.bridgePresent ? "BlackHole 2ch установлен" : "Нужен виртуальный микрофон BlackHole 2ch"), systemImage: setup.bridgePresent ? "checkmark.circle.fill" : "arrow.down.circle")
            Text(ui("Установи BlackHole 2ch с сайта разработчика и перезагрузи Mac. Если он уже установлен, повторная установка не нужна."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Link(ui("Скачать BlackHole 2ch"), destination: URL(string: "https://existential.audio/downloads/BlackHole2ch-0.7.1.pkg")!)
                Link(ui("Сайт и условия BlackHole"), destination: URL(string: "https://github.com/ExistentialAudio/BlackHole")!)
            }.font(.callout)
            Divider()
            Picker(ui("Язык речи"), selection: $setup.language) {
                Text("Русский").tag("ru-RU")
                Text("English").tag("en-US")
            }.disabled(setup.busy)
             .onChange(of: setup.language) { _ in setup.check() }
            HStack {
                if setup.busy { ProgressView().controlSize(.small) }
                Text(ui(setup.status)).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(ui("Загрузить язык через macOS")) { setup.install() }
                    .disabled(setup.busy || setup.installed || ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26)
                Button(ui("Проверить снова")) { setup.check(); VoiceGuard.shared.refreshDevices() }.disabled(setup.busy)
            }
            Text(ui("Загрузка получает языковые данные от Apple. Аудио и текст никуда не отправляются. После установки выбери этот же язык на вкладке голоса."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(ui("Dota 2 устанавливается отдельно через Steam. Для игры выбери системный микрофон или BlackHole 2ch, затем включи голосовую защиту."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(26).frame(width: 560).preferredColorScheme(.dark)
         .onAppear { setup.check() }
    }
}
