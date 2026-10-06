import SwiftUI
import AppKit

@MainActor final class AppNavigation: ObservableObject { @Published var screen = "chat"; @Published var showingSetup = false }

struct RootView: View {
    let hotkeyAvailable: Bool
    @ObservedObject var navigation: AppNavigation
    @ObservedObject private var ui = InterfaceSettings.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Picker(ui("Защита"), selection: $navigation.screen) {
                    Text(ui("Текстовый чат")).tag("chat")
                    Text(ui("Голос · MVP")).tag("voice")
                }.pickerStyle(.segmented).labelsHidden()
                Picker(ui("Язык интерфейса"), selection: $ui.language) {
                    Text("Русский").tag(UILanguage.ru)
                    Text("English").tag(UILanguage.en)
                }.labelsHidden().frame(width: 110).help(ui("Язык интерфейса"))
                Button { navigation.showingSetup = true } label: { Image(systemName: "gearshape") }
                    .help(ui("Установка компонентов")).accessibilityLabel(ui("Установка компонентов"))
            }.padding(.horizontal, 28).padding(.top, 32)
            if navigation.screen == "voice" { VoiceView(voice: .shared) }
            else { GuardView(hotkeyAvailable: hotkeyAvailable, guardState: .shared) }
        }.sheet(isPresented: $navigation.showingSetup) { VoiceSetupView() }
        .frame(width: 680, height: 775, alignment: .top)
         .background(Color(red: 0.065, green: 0.08, blue: 0.095)).preferredColorScheme(.dark)
    }
}

struct VoiceView: View {
    @ObservedObject var voice: VoiceGuard
    @ObservedObject private var ui = InterfaceSettings.shared
    private let mint = Color(red: 0.55, green: 0.91, blue: 0.77)
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "mic.badge.xmark").font(.system(size: 30)).foregroundStyle(mint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(ui("Пауза в голосе")).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(ui("Ругательство → тишина → возврат через 3 секунды.")).font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 13) {
                Text(ui(voice.headline)).font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(voice.enabled && !voice.muted ? mint : .orange)
                Text(ui(voice.status)).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(ui(voice.starting ? "Отменить" : voice.enabled ? "Выключить голосовую защиту" : "Включить голосовую защиту")) {
                        if voice.enabled || voice.starting { voice.stop() } else { voice.start() }
                    }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
                    if voice.enabled {
                        Button(ui("Тишина на 3 секунды")) { voice.testMute() }.buttonStyle(.bordered)
                    }
                }
                if voice.enabled {
                    HStack {
                        Text(ui("Микрофон"))
                        ProgressView(value: Double(voice.level)).tint(mint)
                        Text(ui("Срабатывания: \(voice.detections)")).monospacedDigit()
                    }.font(.system(size: 11))
                }
            }.padding(19).frame(maxWidth: .infinity, alignment: .leading)
             .background(mint.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 12) {
                Picker(ui("Твой микрофон"), selection: $voice.selectedInput) {
                    if voice.devices.isEmpty { Text(ui("Микрофон не найден")).tag(UInt32(0)) }
                    ForEach(voice.devices) { device in Text(device.name).tag(device.id) }
                }
                Picker(ui("Язык речи"), selection: $voice.language) {
                    Text("Русский").tag("ru-RU")
                    Text("English").tag("en-US")
                }
                HStack {
                    Text(ui(voice.bridgePresent ? "BlackHole 2ch установлен" : "Нужен виртуальный микрофон BlackHole 2ch"))
                        .font(.system(size: 12)).foregroundStyle(voice.bridgePresent ? mint : .orange)
                    Spacer()
                    Button(ui("Обновить устройства")) { voice.refreshDevices() }.font(.system(size: 11))
                }
            }.disabled(voice.enabled || voice.starting)
            VStack(alignment: .leading, spacing: 8) {
                Text(ui("Сейчас распознано")).font(.system(size: 12, weight: .medium))
                Text(voice.transcript.isEmpty ? ui("Здесь появится речь с твоего микрофона.") : voice.transcript)
                    .font(.system(size: 14)).foregroundStyle(voice.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            }.padding(16).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 9) {
                Text(ui("Как работает MVP")).font(.system(size: 13, weight: .semibold))
                Text(ui("Речь распознаётся локально на Mac даже во время блокировки. Новое ругательство продлевает паузу ещё на 3 секунды; тишина и речь без новых срабатываний позволяют голосу вернуться."))
                Text(ui("При включении системным микрофоном становится BlackHole 2ch. Фильтр действует в приложениях, использующих системный вход. Явно выбранный в игре другой микрофон обходит его."))
                Text(ui("Первое слово может проскочить до распознавания. При выключении защиты возвращается прежний системный микрофон."))
            }.font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(ui("Без записи аудио и истории · локальные модели macOS"))
                Spacer()
                Text("v0.5.1")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }.padding(28).frame(width: 680, height: 720, alignment: .top)
    }
}
