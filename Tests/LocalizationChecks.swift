import Foundation

@main struct LocalizationChecks {
    static func main() {
        let status: UIMessage = "Обнаружено ругательство. Возврат голоса через \("2.3") с."
        precondition(status.text(in: .ru).contains("2.3 с."))
        precondition(status.text(in: .en) == "Abuse detected. Voice returns in 2.3 s.")
        let error: UIMessage = "Аудиоустройство недоступно."
        let nested: UIMessage = "Ошибка локального распознавания: \(error)"
        precondition(nested.text(in: .en) == "Local speech recognition error: Audio device unavailable.")
        let route: UIMessage = "Вход: \("Mic {1}") → выход: \("BlackHole")"
        precondition(route.text(in: .en) == "Input: Mic {1} → output: BlackHole", "Values must not be reinterpreted as templates")

        let pattern = try! NSRegularExpression(pattern: #"\{\d+\}"#)
        func placeholders(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }.sorted()
        }
        for (ru, en) in UIStrings.english {
            precondition(!en.isEmpty && placeholders(ru) == placeholders(en), "Missing interpolation in: \(ru)")
        }
        var chat = ChatGuardState()
        if case .block(let message) = chat.handle(.enter(repeatKey: false)) {
            precondition(UIStrings.english[message] != nil, "Untranslated synchronization warning")
        } else { preconditionFailure("Expected synchronization warning") }
        _ = chat.handle(.escape); _ = chat.handle(.enter(repeatKey: false)); _ = chat.handle(.text("идиот"))
        if case .block(let message) = chat.handle(.enter(repeatKey: false)) {
            precondition(UIStrings.english[message] != nil, "Untranslated abuse warning")
        } else { preconditionFailure("Expected abuse warning") }
        print("PASS: stored status translation, nested errors, verbatim values, all translation placeholders, actual chat warnings")
    }
}
