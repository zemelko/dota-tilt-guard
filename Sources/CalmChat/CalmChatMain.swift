import AppKit
import SwiftUI

@main enum CalmChatMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

final class ChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let shortcut = GlobalShortcut()
    private let navigation = AppNavigation()
    private var panel: ChatPanel!
    private var statusItem: NSStatusItem!
    private var returnTo: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "О Calm Chat", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Завершить Calm Chat", action: #selector(quit), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
        NSApp.mainMenu = menu
        shortcut.action = { [weak self] in self?.invoke() }
        let hotkeyAvailable = shortcut.install()

        panel = ChatPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 660),
                          styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Calm Chat"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor(calibratedRed: 0.065, green: 0.08, blue: 0.095, alpha: 1)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: RootView(hotkeyAvailable: hotkeyAvailable, navigation: navigation))
        panel.setContentSize(NSSize(width: 680, height: 775))
        panel.center()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right", accessibilityDescription: "Calm Chat")
        statusItem.button?.toolTip = "Calm Chat · ⌃⌥Пробел"
        let statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "Открыть Calm Chat    ⌃⌥Пробел", action: #selector(openPanel), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Выключить перехват чата", action: #selector(disableGuard), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Как пользоваться", action: #selector(about), keyEquivalent: "")
        statusMenu.addItem(.separator())
        statusMenu.addItem(withTitle: "Завершить", action: #selector(quit), keyEquivalent: "q")
        for item in statusMenu.items { item.target = self }
        statusItem.menu = statusMenu
        showPanel()
    }

    private func invoke() {
        if panel.isKeyWindow { hidePanel(); return }
        openPanel()
    }

    @objc private func openPanel() {
        let active = NSWorkspace.shared.frontmostApplication
        returnTo = active?.bundleIdentifier == "com.valvesoftware.dota2" ? active : nil
        showPanel()
    }

    private func showPanel() {
        NativeChatGuard.shared.refreshPermission()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if let returnTo, !returnTo.isTerminated { returnTo.activate(options: []) }
        returnTo = nil
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Calm Chat · версия 0.4.0"
        alert.informativeText = "Разреши Универсальный доступ, включи защиту, вернись в Dota и нажми Esc. После этого открывай чат стандартным Enter. Найденное ругательство остановит отправку. Исправь текст через Backspace или выдели всё через Command+A / Control+A и удали либо замени. После удаления пустой чат можно закрыть Enter. Также можно начать заново через Esc. Сложное редактирование и смена окна требуют повторного Esc.\n\nТекстовый чат проверяется по локальному словарю. Голосовой MVP использует локальное распознавание macOS и BlackHole 2ch: ругательство отключает передачу на 3 секунды, а распознавание продолжает слушать. Аудио и история сообщений не сохраняются. Перехват подключается только к процессу Dota. Приложение не меняет файлы и память игры.\n\nСловарь распознаёт не все оскорбления. При завершении приложения защита прекращается. Окно можно закрывать — приложение продолжит работать в строке меню."
        alert.addButton(withTitle: "Понятно")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func disableGuard() { NativeChatGuard.shared.disable() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hidePanel(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { NativeChatGuard.shared.disable(); VoiceGuard.shared.stop(); shortcut.uninstall() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openPanel(); return true }
}
