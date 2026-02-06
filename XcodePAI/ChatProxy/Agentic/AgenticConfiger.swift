//
//  AgenticConfiger.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/6.
//

import Foundation

class AgenticConfiger {
    
    static let CodexFolderURL = {
        let folderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/codex")
        return folderURL
    }()
    
    static let CodexConfigFileName = "config.toml"
    
    static let LocalProxyServer = "http://127.0.0.1:50222/v1"
    
    static let CurrentCodexAPIType = "responses"
    
    static func checkCodexInstall() -> Bool {
        do {
            let resourceValues = try CodexFolderURL.resourceValues(forKeys: [.isDirectoryKey])
            
            if let isDir = resourceValues.isDirectory, isDir {
                return true
            } else {
                // Not directory
                return false
            }
        } catch {
            return false
        }
    }
    
    enum AgenticConfigerConfigState: String {
        case unknown = "Unknown"
        case notInstalled = "Not installed"
        case notConfigured = "Not configured"
        case misconfigured = "Misconfigured"
        case configured = "Configured"
        case configuredWithOther = "Configured with other provider"
    }
    
    static func checkCodexConfigState() -> AgenticConfigerConfigState {
        guard checkCodexInstall(), let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8) else {
            return .notInstalled
        }
        
        do {
            let doc = try TOMLDocument(content: content)
            
            if let modelProviderValue = doc["model_provider"],
               let modelProvider = modelProviderValue.stringValue {
                
                if modelProvider != Constraint.InternalModelName.lowercased() {
                    // Has model provider set
                    return .configuredWithOther
                } else {
                    if let modelProviderTable = doc["model_providers"]?.tableValue,
                       let detailTable = modelProviderTable[Constraint.InternalModelName.lowercased()]?.tableValue,
                       detailTable["base_url"]?.stringValue == LocalProxyServer,
                       detailTable["wire_api"]?.stringValue == CurrentCodexAPIType {
                        return .configured
                    }
                    return .misconfigured
                }
            }
        } catch _ {
            return .unknown
        }
        
        return .notConfigured
    }
    
    static func setupProxyConfig() {
        guard checkCodexInstall(), let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8) else {
            return
        }
                
        do {
            let doc = try TOMLDocument(content: content)
            
            let detailTable = TOMLValue.table([
                "name": .string("XcodePaI LLM Proxy"),
                "base_url": .string(LocalProxyServer),
                "wire_api": .string(CurrentCodexAPIType)
            ])
            
            var modelProvidersTable = {
                if let modelProviders = doc["model_providers"], let table = modelProviders.tableValue {
                    return table
                }
                return [String: TOMLValue]()
            }()
            modelProvidersTable[Constraint.InternalModelName.lowercased()] = detailTable
            
            doc["model_providers"] = .table(modelProvidersTable)
            doc["model_provider"] = .string(Constraint.InternalModelName.lowercased())
            
            try doc.write(to: CodexFolderURL.appendingPathComponent(CodexConfigFileName))
            
            if CommandRunner.isProcessRunning(name: "codex") {
                CommandRunner.killProcess(byName: "codex", force: true)
            }
        } catch _ {
            return
        }
    }
}
