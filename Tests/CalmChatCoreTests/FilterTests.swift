#if CALM_CHAT_STANDALONE_TESTS
import Foundation
class XCTestCase {}
private var assertions = 0
func XCTAssertTrue(_ value: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) { assertions += 1; precondition(value, message, file: file, line: line) }
func XCTAssertFalse(_ value: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) { XCTAssertTrue(!value, message, file: file, line: line) }
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) { XCTAssertTrue(lhs == rhs, message, file: file, line: line) }
@main enum TestRunner {
    static func main() {
        let tests = FilterTests()
        tests.testNeutralTacticsPass()
        tests.testKnownAbuseIsDetected()
        tests.testNativeChatGuard()
        tests.testDeleteEntireBlockedDraftAndClose()
        tests.testReplaceSelectedDraft()
        tests.testSelectAllDoesNotRestoreUnknownInput()
        tests.testVoiceCooldownAndPartialUpdates()
        tests.testVoicePhrasesAndRepeatedAbuse()
        print("PASS: 8 scenarios, \(assertions) assertions")
    }
}
#else
import XCTest
@testable import CalmChatCore
#endif

final class FilterTests: XCTestCase {
    func testNeutralTacticsPass() {
        for text in ["Не заходите, у меня нет маны", "БКБ через 20 секунд", "Не ставь варды тут", "Убей Рошана", "Focus Invoker, then back", "Let's smoke at 15:00", "Scunthorpe", "Ассист на топе", "Рошан находится внизу"] {
            XCTAssertFalse(ChatFilter.hasAggression(text), text)
        }
    }

    func testKnownAbuseIsDetected() {
        for text in ["ты дебил", "СДОХНИ", "kill yourself", "kys", "thanks idiot", "ты дeбил", "ты де\u{200B}бил", "ты опять слил", "спасибо за фид"] {
            XCTAssertTrue(ChatFilter.hasAggression(text), text)
        }
    }

    func testNativeChatGuard() {
        var guardState = ChatGuardState()
        let enter = ChatGuardState.Input.enter(repeatKey: false)
        func blocked(_ decision: ChatGuardState.Decision) -> Bool {
            if case .block = decision { return true }; return false
        }
        XCTAssertTrue(blocked(guardState.handle(enter)), "Must start uncertain")
        _ = guardState.handle(.escape)
        _ = guardState.handle(.text("gameplay keys"))
        XCTAssertEqual(guardState.text, "")
        XCTAssertEqual(guardState.handle(enter), .pass)
        _ = guardState.handle(.text("ты дебил"))
        XCTAssertTrue(blocked(guardState.handle(enter)))
        XCTAssertEqual(guardState.text, "ты дебил", "Blocking must preserve the draft")
        XCTAssertTrue(blocked(guardState.handle(enter)), "A repeated attempt must also block")
        for _ in 0..<8 { _ = guardState.handle(.backspace) }
        _ = guardState.handle(.text("Давайте вместе"))
        XCTAssertEqual(guardState.handle(enter), .pass)
        XCTAssertEqual(guardState.phase, .closed)
        XCTAssertEqual(guardState.text, "")
        _ = guardState.handle(enter)
        _ = guardState.handle(.text("hello"))
        _ = guardState.handle(.uncertainEdit)
        XCTAssertTrue(blocked(guardState.handle(enter)), "Pastes, selections and cursor changes must not bypass the filter")
        _ = guardState.handle(.escape)
        _ = guardState.handle(enter)
        _ = guardState.handle(.text("hello"))
        _ = guardState.handle(.focusLost)
        XCTAssertTrue(blocked(guardState.handle(enter)), "Switching away invalidates the draft")
        _ = guardState.handle(.escape)
        XCTAssertTrue(blocked(guardState.handle(.enter(repeatKey: true))))
        XCTAssertEqual(guardState.phase, .closed, "Holding Return must not reopen chat")
        _ = guardState.handle(enter)
        _ = guardState.handle(.text(String(repeating: "a", count: 2001)))
        XCTAssertTrue(blocked(guardState.handle(enter)), "Overlong text must not be partially tracked")
    }

    func testDeleteEntireBlockedDraftAndClose() {
        var state = ChatGuardState()
        let enter = ChatGuardState.Input.enter(repeatKey: false)
        _ = state.handle(.escape)
        XCTAssertEqual(state.handle(enter), .pass)
        XCTAssertEqual(state.handle(enter), .pass, "An untouched empty chat must close")
        XCTAssertEqual(state.phase, .closed)
        _ = state.handle(enter)
        _ = state.handle(.text("ты дебил"))
        XCTAssertTrue(isBlocked(state.handle(enter)))
        _ = state.handle(.selectAll)
        XCTAssertEqual(state.text, "ты дебил", "Selection alone must not erase abusive text")
        XCTAssertTrue(isBlocked(state.handle(enter)), "Selected abusive text still cannot be sent")
        _ = state.handle(.backspace)
        XCTAssertEqual(state.text, "")
        XCTAssertEqual(state.phase, .typing)
        XCTAssertEqual(state.handle(enter), .pass, "Deleting the selection must allow closing the empty chat")
        XCTAssertEqual(state.phase, .closed)
        _ = state.handle(enter)
        _ = state.handle(.text("Давайте вместе"))
        XCTAssertEqual(state.handle(enter), .pass, "The next chat must remain synchronized")
        _ = state.handle(enter)
        _ = state.handle(.text("ты дебил"))
        XCTAssertTrue(isBlocked(state.handle(enter)), "Protection must still work in the next chat")
    }

    func testReplaceSelectedDraft() {
        var state = ChatGuardState()
        let enter = ChatGuardState.Input.enter(repeatKey: false)
        _ = state.handle(.escape)
        _ = state.handle(enter)
        _ = state.handle(.text("ты дебил"))
        _ = state.handle(.selectAll)
        _ = state.handle(.selectAll)
        _ = state.handle(.text("Давайте вместе"))
        XCTAssertEqual(state.text, "Давайте вместе")
        _ = state.handle(.backspace)
        XCTAssertEqual(state.text, "Давайте вмест", "Typing must clear the previous selection")
        _ = state.handle(.text("е"))
        XCTAssertEqual(state.handle(enter), .pass)
        _ = state.handle(enter)
        _ = state.handle(.text("Давайте вместе"))
        _ = state.handle(.selectAll)
        _ = state.handle(.text("ты дебил"))
        XCTAssertTrue(isBlocked(state.handle(enter)), "Replacement text must be checked too")
        _ = state.handle(.selectAll)
        _ = state.handle(.backspace)
        _ = state.handle(.backspace)
        _ = state.handle(.text("Отходим"))
        XCTAssertEqual(state.handle(enter), .pass)
    }

    func testSelectAllDoesNotRestoreUnknownInput() {
        let enter = ChatGuardState.Input.enter(repeatKey: false)
        for invalidation in [ChatGuardState.Input.uncertainEdit, .focusLost] {
            var state = ChatGuardState()
            _ = state.handle(.escape)
            _ = state.handle(enter)
            _ = state.handle(.text("ты дебил"))
            _ = state.handle(.selectAll)
            _ = state.handle(invalidation)
            _ = state.handle(.selectAll)
            _ = state.handle(.backspace)
            XCTAssertTrue(isBlocked(state.handle(enter)), "Unsupported editing must still require Escape")
            _ = state.handle(.escape)
            _ = state.handle(enter)
            _ = state.handle(.text("hello"))
            _ = state.handle(.backspace)
            XCTAssertEqual(state.text, "hell", "Reset must clear the old selection")
        }
    }

    func testVoiceCooldownAndPartialUpdates() {
        var gate = VoiceGate()
        let first = [VoiceWord("ты", id: "1"), VoiceWord("дебил", id: "2")]
        XCTAssertTrue(gate.observe(first, now: 10))
        XCTAssertTrue(gate.isMuted(at: 12.9))
        XCTAssertFalse(gate.isMuted(at: 13))
        XCTAssertFalse(gate.observe(first + [VoiceWord("поставь", id: "3")], now: 14), "Old abusive words in a partial transcript must not mute again")
        XCTAssertFalse(gate.isMuted(at: 14))
        XCTAssertEqual(gate.detections, 1)
        XCTAssertTrue(gate.observe(first + [VoiceWord("сука", id: "4")], now: 15))
        XCTAssertTrue(gate.isMuted(at: 17.9))
        XCTAssertFalse(gate.isMuted(at: 18))
        XCTAssertEqual(gate.detections, 2)
        gate.mute(now: 20)
        XCTAssertEqual(gate.remaining(at: 21), 2)
        XCTAssertFalse(gate.isMuted(at: 23), "Silence should let the cooldown expire")
    }

    func testVoicePhrasesAndRepeatedAbuse() {
        var gate = VoiceGate()
        XCTAssertFalse(gate.observe([VoiceWord("Давайте", id: "a"), VoiceWord("вместе", id: "b")], now: 1))
        XCTAssertTrue(gate.observe([VoiceWord("убей", id: "c"), VoiceWord("себя", id: "d")], now: 2))
        XCTAssertFalse(gate.observe([VoiceWord("Убей", id: "c"), VoiceWord("себя!", id: "d"), VoiceWord("сейчас", id: "e")], now: 3), "Punctuation revisions must not restart the timer")
        XCTAssertTrue(gate.observe([VoiceWord("kill", id: "f"), VoiceWord("yourself", id: "g")], now: 4))
        XCTAssertTrue(gate.isMuted(at: 6))
        XCTAssertFalse(gate.isMuted(at: 7))
        XCTAssertTrue(gate.observe([VoiceWord("сука", id: "h")], now: 8))
        XCTAssertTrue(gate.observe([VoiceWord("сука", id: "i")], now: 9), "The same word spoken again is a new event")
        XCTAssertTrue(gate.isMuted(at: 11))
        XCTAssertEqual(ChatFilter.aggressiveWordEnds(["поставь", "дебил", "варды"]), Set([1]))
    }

    private func isBlocked(_ decision: ChatGuardState.Decision) -> Bool {
        if case .block = decision { return true }
        return false
    }
}
