//
//  AgenticConfiger.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/6.
//

import Foundation

/// Codex Agent Configuration Manager
/// Manages configuration for Xcode Coding Assistant (Codex), including installation checks, configuration status checks, and proxy settings
class AgenticConfiger {
    
    /// URL of the Codex configuration folder
    /// Default path: ~/Library/Developer/Xcode/CodingAssistant/codex
    static let CodexFolderURL = {
        let folderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/codex")
        return folderURL
    }()
    
    /// Codex configuration file name
    static let CodexConfigFileName = "config.toml"
    
    /// Local proxy server address
    /// Local LLM proxy service provided by XcodePAI
    static let LocalProxyServer = "http://127.0.0.1:50222/v1"
    
    /// Current Codex API type
    /// Specifies the API protocol type to use
    static let CurrentCodexAPIType = "responses"
    
    /// Checks if Codex is installed
    /// - Returns: Returns true if the Codex folder exists and is a directory; otherwise returns false
    static func checkCodexInstall() -> Bool {
        do {
            let resourceValues = try CodexFolderURL.resourceValues(forKeys: [.isDirectoryKey])
            
            if let isDir = resourceValues.isDirectory, isDir {
                return true
            } else {
                // Not a directory
                return false
            }
        } catch {
            return false
        }
    }
    
    /// Codex configuration status enumeration
    /// Represents different states of Codex configuration
    enum AgenticConfigerConfigState: String {
        /// Unknown state
        case unknown = "Unknown"
        /// Codex not installed
        case notInstalled = "Not installed"
        /// Codex installed but not configured
        case notConfigured = "Not configured"
        /// Configuration error or incomplete
        case misconfigured = "Misconfigured"
        /// Correctly configured to use XcodePAI proxy
        case configured = "Configured"
        /// Configured but using other provider
        case configuredWithOther = "Configured with other provider"
    }
    
    /// Checks the Codex configuration status
    /// - Returns: The current configuration status
    /// 
    /// Check steps:
    /// 1. Check if Codex is installed
    /// 2. Read the configuration file
    /// 3. Parse TOML configuration
    /// 4. Verify if configuration is correct
    static func checkCodexConfigState() -> AgenticConfigerConfigState {
        // 1. Check if Codex is installed
        guard checkCodexInstall(), let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8) else {
            return .notInstalled
        }
        
        do {
            // 2. Parse TOML configuration file
            let doc = try TOMLDocument(content: content)
            
            // 3. Check model_provider configuration
            if let modelProviderValue = doc["model_provider"],
               let modelProvider = modelProviderValue.stringValue {
                
                // 4. Check if configured with other provider
                if modelProvider != Constraint.InternalModelName.lowercased() {
                    // Configured with other model provider
                    return .configuredWithOther
                } else {
                    // 5. Verify XcodePAI configuration details
                    if let modelProviderTable = doc["model_providers"]?.tableValue,
                       let detailTable = modelProviderTable[Constraint.InternalModelName.lowercased()]?.tableValue,
                       detailTable["base_url"]?.stringValue == LocalProxyServer,
                       detailTable["wire_api"]?.stringValue == CurrentCodexAPIType {
                        // Configuration correct
                        return .configured
                    }
                    // Configuration incomplete or incorrect
                    return .misconfigured
                }
            }
        } catch _ {
            // TOML parsing failed
            return .unknown
        }
        
        // No model_provider configured
        return .notConfigured
    }
    
    /// Gets the default model name for Codex
    /// - Returns: The default model name set in the configuration file, or nil if not set or reading fails
    /// 
    /// Reads the "model" field from the config.toml file
    static func codexDefaultModelName() -> String? {
        guard checkCodexInstall(), let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8) else {
            return nil
        }
        
        do {
            let doc = try TOMLDocument(content: content)
            
            // Read the model field
            if let modelValue = doc["model"] {
                return modelValue.stringValue
            }
        } catch _ {
            return nil
        }
        return nil
    }
    
    /// Sets up proxy configuration
    /// 
    /// Configures Codex to use XcodePAI's local proxy service, including:
    /// 1. Add XcodePAI model provider configuration
    /// 2. Set default model provider to XcodePAI
    /// 3. Restart Codex service to apply configuration
    static func setupProxyConfig() {
        // 1. Check if Codex is installed and read configuration file
        guard checkCodexInstall(), let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8) else {
            return
        }
                
        do {
            // 2. Parse existing configuration
            let doc = try TOMLDocument(content: content)
            
            // 3. Create XcodePAI model provider configuration table
            let detailTable = TOMLValue.table([
                "name": .string("XcodePaI LLM Proxy"),
                "base_url": .string(LocalProxyServer),
                "wire_api": .string(CurrentCodexAPIType)
            ])
            
            // 4. Get or create the model_providers table
            var modelProvidersTable = {
                if let modelProviders = doc["model_providers"], let table = modelProviders.tableValue {
                    return table
                }
                return [String: TOMLValue]()
            }()
            
            // 5. Add/update XcodePAI configuration
            modelProvidersTable[Constraint.InternalModelName.lowercased()] = detailTable
            
            // 6. Update configuration file
            doc["model_providers"] = .table(modelProvidersTable)
            doc["model_provider"] = .string(Constraint.InternalModelName.lowercased())
            
            // 7. Write configuration file
            try doc.write(to: CodexFolderURL.appendingPathComponent(CodexConfigFileName))
            
            // 8. Restart Codex service to apply configuration
            if CommandRunner.isProcessRunning(name: "codex") {
                CommandRunner.killProcess(byName: "codex", force: true)
            }
        } catch _ {
            // Configuration update failed
            return
        }
    }
}
