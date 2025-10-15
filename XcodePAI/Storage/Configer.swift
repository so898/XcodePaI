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
        
        case english = "English"
        case chinese = "Chinese"
        case french = "French"
        case russian = "Russian"
        case japanese = "Japanese"
        case korean = "Korean"
    }
    
    // MARK: - Keys
    private static let openConfigurationWhenStartUpKey = "OpenConfigurationWhenStartUp"
    private static let chatProxyPortStorageKey = "ChatProxyPort"
    private static let chatProxyThinkStyleStorageKey = "ChatProxyThinkStyle"
    private static let chatProxyToolUseInRequestStorageKey = "chatProxyToolUseInRequest"
    private static let chatProxyCutSourceInSearchRequestStorageKey = "chatProxyCutSourceInSearchRequest"
    private static let completionSelectConfigIdStorageKey = "completionSelectConfigId"
    private static let selectedPluginIdStorageKey = "selectedPluginId"
    private static let forceLanguageStorageKey = "forceLanguage"
    private static let showXcodeInspectorDebugStorageKey = "showXcodeInspectorDebug"
    private static let showLoadingWhenRequestStorageKey = "showLoadingWhenRequest"
    
    // MARK: - Properties
    static var openConfigurationWhenStartUp: Bool {
        set {
            Self.setValue(openConfigurationWhenStartUpKey, value: newValue)
        }
        get {
            return Self.value(openConfigurationWhenStartUpKey, defaultValue: true) ?? true
        }
    }
    
    static var chatProxyPort: UInt16 {
        set {
            Self.setValue(chatProxyPortStorageKey, value: newValue)
        }
        get {
            return Self.value(chatProxyPortStorageKey, defaultValue: UInt16(50222)) ?? 50222
        }
    }
    
    static var chatProxyThinkStyle: ThinkParser {
        set {
            Self.setValue(chatProxyThinkStyleStorageKey, value: newValue.rawValue)
        }
        get {
            let rawValue: Int = Self.value(chatProxyThinkStyleStorageKey, defaultValue: 0) ?? 0
            return ThinkParser(rawValue: rawValue) ?? .inContentWithCodeSnippet
        }
    }
    
    static var chatProxyToolUseInRequest: Bool {
        set {
            Self.setValue(chatProxyToolUseInRequestStorageKey, value: newValue)
        }
        get {
            return Self.value(chatProxyToolUseInRequestStorageKey, defaultValue: true) ?? true
        }
    }
    
    static var chatProxyCutSourceInSearchRequest: Bool {
        set {
            Self.setValue(chatProxyCutSourceInSearchRequestStorageKey, value: newValue)
        }
        get {
            return Self.value(chatProxyCutSourceInSearchRequestStorageKey, defaultValue: false) ?? false
        }
    }
    
    static var completionSelectConfigId: UUID {
        set {
            Self.setValue(completionSelectConfigIdStorageKey, value: newValue.uuidString)
        }
        get {
            if let string = Self.value(Self.completionSelectConfigIdStorageKey, defaultValue: ""), !string.isEmpty, let uuid = UUID(uuidString: string) {
                return uuid
            }
            return UUID()
        }
    }
    
    static var selectedPluginId: String? {
        set {
            guard let newValue = newValue else {
                Self.remove(selectedPluginIdStorageKey)
                return
            }
            Self.setValue(selectedPluginIdStorageKey, value: newValue)
        }
        get {
            return Self.value(selectedPluginIdStorageKey, defaultValue: nil)
        }
    }
    
    static var forceLanguage: Configer.Language {
        set {
            Self.setValue(forceLanguageStorageKey, value: newValue.rawValue)
        }
        get {
            let rawValue: String = Self.value(forceLanguageStorageKey, defaultValue: Language.english.rawValue) ?? Language.english.rawValue
            return Configer.Language(rawValue: rawValue) ?? .english
        }
    }
    
    static var showXcodeInspectorDebug: Bool {
        set {
            Self.setValue(showXcodeInspectorDebugStorageKey, value: newValue)
        }
        get {
            return Self.value(showXcodeInspectorDebugStorageKey, defaultValue: false) ?? false
        }
    }
    
    static var showLoadingWhenRequest: Bool {
        set {
            Self.setValue(showLoadingWhenRequestStorageKey, value: newValue)
        }
        get {
            return Self.value(showLoadingWhenRequestStorageKey, defaultValue: true) ?? true
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
    
    private static func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
