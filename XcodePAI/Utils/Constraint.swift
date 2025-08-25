//
//  Constraint.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/9.
//

import Foundation

class Constraint {
    // Static strings
    static let AppName = "XcodePaI"
    static let AppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    
    static let LFString = "\n"
    static let CRLFString = "\r\n"
    static let DoubleCRLFString = "\r\n\r\n"
    
    static let DoubleLFString = "\n\n"
    
    //Static Data
    static let LF = Data(Constraint.LFString.utf8)
    static let CRLF = Data(Constraint.CRLFString.utf8)
    static let DoubleCRLF = Data(Constraint.DoubleCRLFString.utf8)
    static let DoubleLF = Data(Constraint.DoubleLFString.utf8)
    
    // Storage
    static let modelProviderStorageKey = "LLMModelProviderStorage"
    static let modelStorageKeyPrefix = "LLMModelStorage_"
    static let mcpStorageKey = "LLMMCPStorage"
    static let mcpToolStorageKeyPrefix = "LLMMCPToolStorage_"
    static let llmConfigStorageKey = "LLMConfigStorage"
}
