import SwiftUI
import AppKit

@MainActor final class AppNavigation: ObservableObject { @Published var screen = "chat" }

struct RootView: View {
    let hotkeyAvailable: Bool
    @ObservedObject var navigation: AppNavigation
    var body: some View {
        VStack(spacing: 0) {
            Picker("Защита", selection: $navigation.screen) {
                Text("Текстовый чат").tag("chat")
                Text("Голос · MVP").tag("voice")
            }.pickerStyle(.segmented).padding(.horizontal, 28).padding(.top, 32)
            if navigation.screen == "voice" { VoiceView(voice: .shared) }
            else { GuardView(hotkeyAvailable: hotkeyAvailable, guardState: .shared) }
        }.frame(width: 680, height: 775, alignment: .top)
         .background(Color(red: 0.065, green: 0.08, blue: 0.095)).preferredColorScheme(.dark)
    }
}

struct VoiceView: View {
    @ObservedObject var voice: VoiceGuard
    private let mint = Color(red: 0.55, green: 0.91, blue: 0.77)
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "mic.badge.xmark").font(.system(size: 30)).foregroundStyle(mint)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Пауза в голосе").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("Ругательство → тишина → возврат через 3 секунды.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 13) {
                Text(voice.headline).font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(voice.enabled && !voice.muted ? mint : .orange)
                Text(voice.status).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(voice.starting ? "Отменить" : voice.enabled ? "Выключить голосовую защиту" : "Включить голосовую защиту") {
                        if voice.enabled || voice.starting { voice.stop() } else { voice.start() }
                    }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
                    if voice.enabled {
                        Button("Тишина на 3 секунды") { voice.testMute() }.buttonStyle(.bordered)
                    }
                }
                if voice.enabled {
                    HStack {
                        Text("Микрофон")
                        ProgressView(value: Double(voice.level)).tint(mint)
                        Text("Срабатывания: \(voice.detections)").monospacedDigit()
                    }.font(.system(size: 11))
                }
            }.padding(19).frame(maxWidth: .infinity, alignment: .leading)
             .background(mint.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 12) {
                Picker("Твой микрофон", selection: $voice.selectedInput) {
                    if voice.devices.isEmpty { Text("Микрофон не найден").tag(UInt32(0)) }
                    ForEach(voice.devices) { device in Text(device.name).tag(device.id) }
                }
                Picker("Язык речи", selection: $voice.language) {
                    Text("Русский").tag("ru-RU")
                    Text("English").tag("en-US")
                }
                HStack {
                    Text(voice.bridgePresent ? "BlackHole 2ch установлен" : "Нужен виртуальный микрофон BlackHole 2ch")
                        .font(.system(size: 12)).foregroundStyle(voice.bridgePresent ? mint : .orange)
                    Spacer()
                    Button("Обновить устройства") { voice.refreshDevices() }.font(.system(size: 11))
                }
            }.disabled(voice.enabled || voice.starting)
            VStack(alignment: .leading, spacing: 8) {
                Text("Сейчас распознано").font(.system(size: 12, weight: .medium))
                Text(voice.transcript.isEmpty ? "Здесь появится речь с твоего микрофона." : voice.transcript)
                    .font(.system(size: 14)).foregroundStyle(voice.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            }.padding(16).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 9) {
                Text("Как работает MVP").font(.system(size: 13, weight: .semibold))
                Text("Речь распознаётся локально на Mac даже во время блокировки. Новое ругательство продлевает паузу ещё на 3 секунды; тишина и речь без новых срабатываний позволяют голосу вернуться.")
                Text("При включении системным микрофоном становится BlackHole 2ch. Фильтр действует в приложениях, использующих системный вход. Явно выбранный в игре другой микрофон обходит его.")
                Text("Первое слово может проскочить до распознавания. При выключении защиты возвращается прежний системный микрофон.")
            }.font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Без записи аудио и истории · локальные модели macOS")
                Spacer()
                Text("v0.4.0")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }.padding(28).frame(width: 680, height: 720, alignment: .top)
    }
}
