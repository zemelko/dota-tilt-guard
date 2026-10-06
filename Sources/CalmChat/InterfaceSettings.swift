import Foundation
import Combine

@MainActor final class InterfaceSettings: ObservableObject {
    static let shared = InterfaceSettings()
    @Published var language: UILanguage {
        didSet { defaults.set(language.rawValue, forKey: UILanguage.preferenceKey) }
    }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = UILanguage(rawValue: defaults.string(forKey: UILanguage.preferenceKey) ?? "") ?? .ru
    }
    func callAsFunction(_ message: UIMessage) -> String { message.text(in: language) }
}
