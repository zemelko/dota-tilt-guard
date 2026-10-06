import SwiftUI
import AppKit

struct GuardView: View {
    let hotkeyAvailable: Bool
    @ObservedObject var guardState: NativeChatGuard
    @ObservedObject private var ui = InterfaceSettings.shared
    private let mint = Color(red: 0.55, green: 0.91, blue: 0.77)
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dota Tilt Guard").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(ui("Пишешь в Dota. Фильтр проверяет Enter.")).font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(ui(guardState.headline)).font(.system(size: 14, weight: .semibold)).foregroundStyle(statusColor)
                    Spacer()
                    Text(ui("ЛОКАЛЬНО")).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(mint)
                }
                Text(ui(guardState.status)).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button {
                        if guardState.enabled { guardState.disable() } else { guardState.enable() }
                    } label: {
                        Text(ui(guardState.enabled ? "Выключить защиту" : "Включить защиту"))
                            .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).frame(height: 36)
                            .foregroundStyle(Color.black).background(mint, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                    if !guardState.permissionGranted {
                        Button(ui("Открыть Accessibility…")) { guardState.openAccessibilitySettings() }.buttonStyle(.bordered)
                    }
                    Spacer()
                }
                Text(ui(guardState.permissionGranted ? "Доступ macOS подтверждён приложением" : "Переключатель в настройках сам по себе не подтверждает доступ новой сборки."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if guardState.enabled || guardState.keyCount > 0 {
                    Divider()
                    HStack(spacing: 16) {
                        Text(ui("Клавиши Dota: \(guardState.keyCount)"))
                        Text("Enter: \(guardState.enterCount)")
                        Text(ui("Блокировки: \(guardState.blockedCount)"))
                    }.font(.system(size: 11, weight: .medium)).monospacedDigit()
                    Text(ui(guardState.lastEvent)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.padding(19).frame(maxWidth: .infinity, alignment: .leading)
             .background(mint.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
             .overlay(RoundedRectangle(cornerRadius: 14).stroke(mint.opacity(0.18)))

            VStack(alignment: .leading, spacing: 15) {
                step("1", "Включи фильтр и вернись в Dota", "Нажми Esc, чтобы закрыть чат и начать с пустой строки.")
                step("2", "Открой чат обычным Enter и напиши", "Первый прототип рассчитан на стандартные клавиши чата.")
                step("3", "Нажми Enter для отправки", "Найденные ругательства остановят отправку. Исправь их через Backspace или начни заново через Esc.")
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(ui("Экспериментальный режим"), systemImage: "wrench.and.screwdriver")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.orange)
                Text(ui("Поддерживаются набор текста, Backspace и выделение всего через ⌘A / Ctrl+A с удалением или заменой. Вставка, частичное выделение, стрелки, щелчок мыши или смена окна требуют Esc и нового ввода."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(ui("Словарь ловит известные выражения, но не все оскорбления. При закрытии приложения защита прекращается."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(17).background(Color.orange.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Text(ui("Полностью локально · без нейросети"))
                Spacer()
                Text("v0.5.0")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            Text(ui(hotkeyAvailable ? "Окно: ⌃⌥Пробел. Закрытие окна не выключает защиту." : "Окно можно открыть через значок Dota Tilt Guard в строке меню."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(28)
         .frame(width: 680, height: 720, alignment: .top)
         .background(Color(red: 0.065, green: 0.08, blue: 0.095))
         .preferredColorScheme(.dark)
    }
    private var statusColor: Color {
        if !guardState.permissionGranted { return .red }
        if guardState.connected && guardState.keyCount > 0 { return mint }
        return guardState.enabled ? .orange : .secondary
    }
    private func step(_ number: String, _ title: UIMessage, _ subtitle: UIMessage) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(mint).frame(width: 26, height: 26).background(mint.opacity(0.07), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(ui(title)).font(.system(size: 14, weight: .medium))
                Text(ui(subtitle)).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
