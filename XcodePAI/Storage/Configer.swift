//
//  Configer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/27.
//

import Foundation

class Configer {
    
    public enum Language: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        
        case English = "English"
        case Chinese = "Chinese"
        case France = "France"
        case Russian = "Russian"
        case Japanese = "Japanese"
        case Korean = "Korean"
    }
    
    static private let openConfigurationWhenStartUpKey = "OpenConfigurationWhenStartUp"
    static var openConfigurationWhenStartUp: Bool {
        set {
            Self.setValue(Self.openConfigurationWhenStartUpKey, value: newValue)
        }
        get {
            return Self.value(Self.openConfigurationWhenStartUpKey, defaultValue: true)!
        }
    }
    
    static private let chatProxyPortStorageKey = "ChatProxyPort"
    static var chatProxyPort: UInt16 {
        set {
            Self.setValue(Self.chatProxyPortStorageKey, value: newValue)
        }
        get {
            return Self.value(Self.chatProxyPortStorageKey, defaultValue: UInt16(50222))!
        }
    }
    
    static private let chatProxyThinkStyleStorageKey = "ChatProxyThinkStyle"
    static var chatProxyThinkStyle: ThinkParser {
        set {
            Self.setValue(Self.chatProxyThinkStyleStorageKey, value: newValue.rawValue)
        }
        get {
            return .init(rawValue: Self.value(Self.chatProxyThinkStyleStorageKey, defaultValue: 0)!) ?? .inContentWithCodeSnippet
        }
    }
    
    static private let chatProxyToolUseInRequestStorageKey = "chatProxyToolUseInRequest"
    static var chatProxyToolUseInRequest: Bool {
        set {
            Self.setValue(Self.chatProxyToolUseInRequestStorageKey, value: newValue)
        }
        get {
            return Self.value(Self.chatProxyToolUseInRequestStorageKey, defaultValue: true)!
        }
    }
    
    static private let completionSelectConfigIdStorageKey = "completionSelectConfigId"
    static var completionSelectConfigId: UUID {
        set {
            Self.setValue(Self.completionSelectConfigIdStorageKey, value: newValue.uuidString)
        }
        get {
            if let string = Self.value(Self.completionSelectConfigIdStorageKey, defaultValue: ""), !string.isEmpty, let uuid = UUID(uuidString: string) {
                return uuid
            }
            return UUID()
        }
    }
    
    static private let forceLanguageStorageKey = "forceLanguage"
    static var forceLanguage: Configer.Language {
        set {
            Self.setValue(Self.forceLanguageStorageKey, value: newValue.rawValue)
        }
        get {
            return Configer.Language(rawValue: Self.value(Self.forceLanguageStorageKey, defaultValue: Configer.Language.English.rawValue)!) ?? .English
        }
    }
    
}

// MARK: Private Functions
extension Configer {
    private static func setValue<T>(_ key: String, value: T) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private static func value<T>(_ key: String, defaultValue: T? = nil) -> T? {
        return UserDefaults.standard.value(forKey: key) as? T ?? defaultValue
    }
}
