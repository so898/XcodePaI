import Foundation
import Preferences
import SuggestionBasic

public class DisabledLanguageList {
    public static let shared = DisabledLanguageList()

    private init() {}

    public var activeDocumentLanguage: CodeLanguage? {
        let activeURL = XcodeInspector.shared.activeDocumentURL
        return activeURL.map(languageIdentifierFromFileURL)
    }

    public var list: [String] {
        UserDefaults.shared.value(for: \.suggestionFeatureDisabledLanguageList)
    }

    public func isEnabled(_ language: CodeLanguage) -> Bool {
        return !list.contains(language.rawValue)
    }

    public func enable(_ language: CodeLanguage) {
        UserDefaults.shared.set(
            list.filter { $0 != language.rawValue },
            for: \.suggestionFeatureDisabledLanguageList
        )
    }

    public func disable(_ language: CodeLanguage) {
        let currentList = list

        if !currentList.contains(language.rawValue) {
            UserDefaults.shared.set(
                currentList + [language.rawValue],
                for: \.suggestionFeatureDisabledLanguageList
            )
        }
    }
}
