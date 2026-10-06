import AppKit
import CoreGraphics
import SwiftUI
import CalmChatCore

@MainActor final class NativeChatGuard: ObservableObject {
    static let shared = NativeChatGuard()
    @Published private(set) var enabled = false
    @Published private(set) var connected = false
    @Published private(set) var status: UIMessage = "Выключен"
    @Published private(set) var blockedCount = 0
    @Published private(set) var permissionGranted = AXIsProcessTrusted()
    @Published private(set) var keyCount = 0
    @Published private(set) var enterCount = 0
    @Published private(set) var lastEvent: UIMessage = "Событий пока нет"
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var pid: pid_t?
    private var watchdog: Timer?
    private var permissionTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var state = ChatGuardState()
    private var swallowedEnter = Set<Int64>()
    private var toast: NSPanel?
    private var toastTask: Task<Void, Never>?

    private init() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    func refreshPermission() {
        let current = AXIsProcessTrusted()
        if permissionGranted != current { permissionGranted = current }
        if enabled && !current {
            disable()
            status = "macOS отозвала доступ к вводу. Защита не работает."
        }
    }

    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    var headline: UIMessage {
        if !permissionGranted { return "Нет доступа — защита не работает" }
        if !enabled { return "Защита выключена" }
        if !connected { return "Защита ожидает подключения" }
        if keyCount == 0 { return "Подключено — ждём клавиши Dota" }
        return "Перехват получает клавиши Dota"
    }

    func enable() {
        refreshPermission()
        guard permissionGranted else {
            status = "macOS не подтвердила доступ этой сборке. Если переключатель уже включён, удали Dota Tilt Guard из списка Accessibility и добавь заново."
            return
        }
        guard !enabled else { return }
        enabled = true
        keyCount = 0; enterCount = 0; blockedCount = 0; lastEvent = "Событий пока нет"
        state.reset()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.attach() }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.valvesoftware.dota2" else { return }
            MainActor.assumeIsolated { _ = self?.state.handle(.focusLost); self?.swallowedEnter.removeAll() }
        })
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshPermission()
                guard self.enabled else { return }
                self.attach()
                if let tap = self.tap, !CGEvent.tapIsEnabled(tap: tap) {
                    self.state.reset()
                    CGEvent.tapEnable(tap: tap, enable: true)
                    self.connected = CGEvent.tapIsEnabled(tap: tap)
                    self.status = "Перехват перезапущен. Нажми Esc в Dota."
                    self.showToast("Перехват был прерван. Нажми Esc перед новым сообщением.")
                }
            }
        }
        attach()
    }

    func disable() {
        enabled = false
        detach()
        watchdog?.invalidate(); watchdog = nil
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        toast?.orderOut(nil)
        status = "Выключен"
    }

    private func detach() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil; pid = nil; connected = false
        state.reset(); swallowedEnter.removeAll()
    }

    private func attach() {
        guard enabled else { return }
        guard let game = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.valvesoftware.dota2" }) else {
            detach(); status = "Ожидаю запуска Dota 2"; return
        }
        if pid == game.processIdentifier, tap != nil { return }
        detach()
        let types: [CGEventType] = [.keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreateForPid(pid: game.processIdentifier, place: .headInsertEventTap,
                options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<NativeChatGuard>.fromOpaque(context).takeUnretainedValue()
            return MainActor.assumeIsolated { owner.handle(type, event) }
        }, userInfo: pointer) else {
            status = "macOS не разрешила перехват событий Dota. Защита не работает."
            return
        }
        tap = created
        pid = game.processIdentifier
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: created, enable: true)
        connected = CGEvent.tapIsEnabled(tap: created)
        status = connected ? "В Dota сначала нажми Esc. Счётчик ниже должен расти при наборе." : "macOS не включила перехват. Защита не работает."
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.reset()
            connected = false
            status = "Перехват прерван. Нужна повторная синхронизация через Esc."
            return Unmanaged.passUnretained(event)
        }
        guard enabled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp {
            if swallowedEnter.remove(key) != nil { return nil }
            return Unmanaged.passUnretained(event)
        }
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            _ = state.handle(.uncertainEdit)
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        keyCount += 1
        if key == 36 || key == 76 { enterCount += 1; lastEvent = "Получен Enter" }
        else if key == 53 { lastEvent = "Получен Esc — начало нового чата" }
        else { lastEvent = "Получена клавиша Dota" }
        let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        let modified = !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty
        let input: ChatGuardState.Input
        if key == 53 { input = .escape }
        else if key == 36 || key == 76 {
            if modified { state.reset() }
            input = .enter(repeatKey: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        } else if key == 0 && (flags == .maskCommand || flags == .maskControl) {
            // Dota's select-all shortcuts; do not treat the shortcut as typed text.
            input = .selectAll
        } else if modified || (flags.contains(.maskShift) && [51, 117, 123, 124, 115, 119].contains(key)) {
            input = .uncertainEdit
        } else {
            switch key {
            case 51: input = .backspace
            case 117, 123, 124, 115, 119, 48, 125, 126: input = .uncertainEdit
            // Cursor movement, completion and editing shortcuts must be verified against Dota before being trusted.
            default:
                var count = 0
                var units = [UniChar](repeating: 0, count: 64)
                event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &count, unicodeString: &units)
                input = count > 0 && count < units.count ? .text(String(utf16CodeUnits: units, count: count)) : .uncertainEdit
            }
        }
        switch state.handle(input) {
        case .pass:
            if key == 53 { status = "Готов к новому чату · открытие через Enter"; toast?.orderOut(nil) }
            if (key == 36 || key == 76) && state.phase == .closed {
                toastTask?.cancel(); toast?.orderOut(nil)
            }
            return Unmanaged.passUnretained(event)
        case .block(let message):
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { swallowedEnter.insert(key) }
            if !message.isEmpty {
                blockedCount += 1
                // Keep the event callback short; display the warning on the next run-loop turn.
                DispatchQueue.main.async { [weak self] in self?.showToast(UIMessage(key: message)) }
            }
            return nil
        }
    }

    private func showToast(_ message: UIMessage) {
        guard enabled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
        if toast == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 112),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
            toast = panel
        }
        toast?.contentView = NSHostingView(rootView: GuardToast(message: message))
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            toast?.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 280, y: screen.visibleFrame.minY + 100))
        }
        toast?.orderFrontRegardless()
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled { self?.toast?.orderOut(nil) }
        }
    }
}

private struct GuardToast: View {
    let message: UIMessage
    @ObservedObject private var ui = InterfaceSettings.shared
    var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "hand.raised.fill").font(.system(size: 25)).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(ui("Dota Tilt Guard · отправка остановлена")).font(.system(size: 15, weight: .semibold))
                    Text(ui(message)).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(20).frame(width: 560, alignment: .leading)
             .background(Color(red: 0.08, green: 0.09, blue: 0.10), in: RoundedRectangle(cornerRadius: 16))
             .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.4)))
             .preferredColorScheme(.dark)
    }
}
