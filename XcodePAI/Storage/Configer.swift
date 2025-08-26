//
//  Configer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/27.
//

import Foundation

class Configer {
    
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
