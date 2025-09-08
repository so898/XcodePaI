//
//  LanguageManager.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/9.
//

import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String? {
        didSet {
            Bundle.currentLanguage = currentLanguage
            NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        }
    }
    
    private init() {
        currentLanguage = UserDefaults.standard.string(forKey: "AppLanguage")
    }
    
    func setLanguage(_ languageCode: String?) {
        currentLanguage = languageCode
    }
    
    func supportedLanguages() -> [(key: String?, name: String)] {
        return [
            (key: nil, name: NSLocalizedString("System Default", comment: "")),
            (key: "en", name: "English"),
            (key: "zh-Hans", name: "简体中文"),
//            (key: "ja", name: "日本語")
        ]
    }
}
