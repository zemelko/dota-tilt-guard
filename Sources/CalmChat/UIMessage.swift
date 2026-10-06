import Foundation

enum UILanguage: String, CaseIterable {
    case ru, en
    static let preferenceKey = "CalmChat.interfaceLanguage"
    static var saved: UILanguage { UILanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .ru }
}

/// Store the message, not its rendered translation, so existing statuses change language too.
indirect enum UIMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    case template(String, [UIMessage])
    case verbatim(String)
    case joined([UIMessage], String)

    init(stringLiteral value: String) { self = .template(value, []) }
    init(key: String) { self = .template(key, []) }
    init(stringInterpolation value: StringInterpolation) { self = .template(value.key, value.arguments) }

    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [UIMessage] = []
        init(literalCapacity: Int, interpolationCount: Int) { arguments.reserveCapacity(interpolationCount) }
        mutating func appendLiteral(_ value: String) { key += value }
        mutating func appendInterpolation(_ value: UIMessage) {
            key += "{\(arguments.count)}"; arguments.append(value)
        }
        mutating func appendInterpolation<T>(_ value: T) { appendInterpolation(.verbatim(String(describing: value))) }
    }

    func text(in language: UILanguage) -> String {
        switch self {
        case .verbatim(let value): return value
        case .joined(let messages, let separator): return messages.map { $0.text(in: language) }.joined(separator: separator)
        case .template(let key, let arguments):
            let format = language == .en ? UIStrings.english[key] ?? key : key
            // Substitute only the template. Device names and other values are never reinterpreted.
            var result = "", cursor = format.startIndex
            for match in Self.placeholder.matches(in: format, range: NSRange(format.startIndex..., in: format)) {
                guard let range = Range(match.range, in: format), let number = Range(match.range(at: 1), in: format),
                      let index = Int(format[number]), arguments.indices.contains(index) else { continue }
                result += format[cursor..<range.lowerBound]
                result += arguments[index].text(in: language)
                cursor = range.upperBound
            }
            result += format[cursor...]
            return result
        }
    }
    private static let placeholder = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
}
