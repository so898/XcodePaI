import Foundation

public extension Locale {
    static var availableLocalizedLocales: [String] {
        let localizedLocales = Locale.LanguageCode.isoLanguageCodes.compactMap {
            Locale(identifier: "en-US").localizedString(forLanguageCode: $0.identifier)
        }
        .sorted()
        return localizedLocales
    }

    var languageName: String {
        localizedString(forLanguageCode: language.languageCode?.identifier ?? "") ?? ""
    }
}
