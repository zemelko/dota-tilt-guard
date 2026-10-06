import Foundation

public enum ChatFilter {
    public static let maxInputCharacters = 2000

    public static func normalized(_ text: String) -> String {
        let scalars = text.precomposedStringWithCompatibilityMapping.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0)
        }.filter { !CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}\u{FEFF}").contains($0) }
        return String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func detectionText(_ text: String) -> String {
        let normalized = normalized(text).lowercased().replacingOccurrences(of: "ё", with: "е")
        let lookalikes: [Character: Character] = ["a":"а", "c":"с", "e":"е", "o":"о", "p":"р", "x":"х", "y":"у", "k":"к", "m":"м", "t":"т"]
        return normalized.split(separator: " ", omittingEmptySubsequences: false).map { token in
            guard matches(String(token), "[а-я]") else { return String(token) }
            return String(token.map { lookalikes[$0] ?? $0 })
        }.joined(separator: " ")
    }

    private static let patterns = [
            #"(?<![\p{L}\p{N}])(?:бля\p{L}*|блеать|сука|суки|суч\p{L}*|хуй\p{L}*|хуе\p{L}*|хуя\p{L}*|нах(?:уй|уи|ер|рен)\p{L}*|похуй\p{L}*|пизд\p{L}*|[еe]б[аоу]\p{L}*|заеб\p{L}*|уеб\p{L}*|долбо\p{L}*|мудак\p{L}*|мудил\p{L}*|гандон\p{L}*|гондон\p{L}*|дебил\p{L}*|идиот\p{L}*|кретин\p{L}*|имбецил\p{L}*|даун\p{L}*|аутист\p{L}*|тупой|тупые|тупая|тупица\p{L}*|урод\p{L}*|мраз\p{L}*|пид[ао]р\p{L}*|педик\p{L}*|пидр\p{L}*|чмо\p{L}*|говн\p{L}*|дерьм\p{L}*|сдох\p{L}*|сдохни|заткнись|дегенерат\p{L}*|охрене\p{L}*|шлюх\p{L}*)(?![\p{L}\p{N}])"#,
            #"\b(?:fuck\w*|shit\w*|bitch\w*|asshole\w*|idiot\w*|moron\w*|retard\w*|noob\w*|trash|stfu|kys|cunt\w*|fagg?ot\w*|nigg\w*|debil\w*|pid[oa]r\w*|blya\w*|suka|nahui|nahuy)\b"#,
            #"(?:убей\s+себя|удали\s+(?:игру|доту)|мать\s+твою|твою\s+мать|сын\s+шлюхи|какого\s+хрена|какого\s+черта|пош[её]л\s+вон|репорт\s+(?:ему|ей|этого|тебе)|вы\s+все\s+раки|ты\s+(?:рак|мусор|дно)|kill\s+yourself|uninstall|ez\s+(?:mid|game)|изи\s+(?:мид|игра))"#,
            #"(?:ты\s+(?:опять|снова|вечно)|вы\s+(?:опять|снова|вечно)|спасибо\s+за\s+(?:слив|фид)|зачем\s+ты|почему\s+ты\s+не|как\s+же\s+(?:вы|ты)\s+достал|report\s+(?:him|her|this|our))"#
        ]

    public static func hasAggression(_ text: String) -> Bool {
        let value = detectionText(text)
        return patterns.contains { matches(value, $0) }
    }

    /// Word positions ending an abusive match. Used to avoid re-triggering on old
    /// words when a streaming recognizer revises the same partial transcript.
    public static func aggressiveWordEnds(_ words: [String]) -> Set<Int> {
        let tokens = words.map(detectionText)
        let text = tokens.joined(separator: " ")
        var offsets: [NSRange] = []
        var offset = 0
        for token in tokens {
            offsets.append(NSRange(location: offset, length: token.utf16.count))
            offset += token.utf16.count + 1
        }
        var indices = Set<Int>()
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for match in expression.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
                let end = NSMaxRange(match.range) - 1
                if let index = offsets.firstIndex(where: { NSLocationInRange(end, $0) }) { indices.insert(index) }
            }
        }
        return indices
    }

}
