import Foundation

/// Best-effort mirror for the default Return-to-open Dota chat workflow.
/// Unknown edits fail closed until Escape; this is not a source of truth for the game UI.
public struct ChatGuardState {
    public enum Phase: Equatable { case unknown, closed, typing }
    public enum Decision: Equatable { case pass, block(String) }
    public enum Input {
        case enter(repeatKey: Bool), escape, text(String), selectAll, backspace, uncertainEdit, focusLost
    }
    public private(set) var phase: Phase = .unknown
    public private(set) var text = ""
    private var allSelected = false
    public init() {}

    public mutating func reset() { phase = .unknown; text = ""; allSelected = false }

    public mutating func handle(_ input: Input) -> Decision {
        switch input {
        case .escape:
            text = ""; phase = .closed; allSelected = false
        case .focusLost:
            // Any focus change can hide a chat transition or an IME commit.
            reset()
        case .enter(let isRepeat):
            guard !isRepeat else { return .block("") }
            switch phase {
            case .unknown:
                return .block("Не уверен в содержимом чата. Нажми Esc, открой чат заново и набери сообщение.")
            case .closed:
                phase = .typing; text = ""; allSelected = false
            case .typing:
                guard !ChatFilter.hasAggression(text) else {
                    return .block("Сообщение не отправлено: найдено ругательство или оскорбление. Измени текст или нажми Esc.")
                }
                phase = .closed; text = ""; allSelected = false
            }
        case .selectAll:
            // Selection alone changes no text; Enter must still check the entire draft.
            if phase == .typing { allSelected = true }
        case .uncertainEdit:
            if phase == .typing { reset() }
        case .text(let value):
            guard phase == .typing else { return .pass }
            guard !value.isEmpty, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  (allSelected ? 0 : text.count) + value.count <= ChatFilter.maxInputCharacters else {
                reset(); return .pass
            }
            if allSelected { text = value } else { text += value }
            allSelected = false
        case .backspace:
            guard phase == .typing else { return .pass }
            if allSelected { text = "" }
            else if !text.isEmpty { text.removeLast() }
            allSelected = false
        }
        return .pass
    }
}
