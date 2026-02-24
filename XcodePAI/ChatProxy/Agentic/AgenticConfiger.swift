//
//  AgenticConfiger.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/6.
//

import Foundation

/// Configuration manager for AI coding assistants (Codex and Claude) in Xcode.
///
/// Handles installation verification, configuration status checks, proxy setup,
/// and service management for AI coding assistant agents. Supports:
/// - Codex (TOML-based configuration)
/// - Claude Code (JSON-based configuration)
///
/// Ensures proper integration with XcodePAI's local proxy service at `LocalProxyServer`.
class AgenticConfiger {
    
    /// Represents the configuration state of an AI assistant agent.
    ///
    /// Used to determine installation status, configuration validity, and proxy alignment.
    enum AgenticConfigerConfigState: String {
        /// Initial or undetermined state (should not occur in normal operation)
        case unknown = "Unknown"
        
        /// Agent folder does not exist or is not installed
        case notInstalled = "Not installed"
        
        /// Agent is installed but lacks required configuration entries
        case notConfigured = "Not configured"
        
        /// Configuration exists but contains errors or missing critical fields
        case misconfigured = "Misconfigured"
        
        /// Correctly configured to use XcodePAI's local proxy service
        case configured = "Configured"
        
        /// Configured to use a provider other than XcodePAI's proxy
        case configuredWithOther = "Configured with other provider"
    }
    
    /// Local proxy server endpoint for XcodePAI's LLM service.
    ///
    /// All AI agents should route requests through this endpoint when properly configured.
    /// Format: `http://127.0.0.1:50222/v1`
    static let LocalProxyServer = "http://127.0.0.1:50222/v1"
    
    /// Local MCP server endpoint for XcodePAI's MCP service.
    ///
    /// Used by AI agents to access MCP tools for code operations.
    /// Format: `http://127.0.0.1:50222/mcp`
    static let LocalMCPServer = "http://127.0.0.1:50222/mcp"
    
    // MARK: - Codex Configuration Management
    
    /// Default filesystem path for Codex configuration directory.
    ///
    /// Path: `~/Library/Developer/Xcode/CodingAssistant/codex`
    /// Contains `config.toml` and related Codex resources.
    static let CodexFolderURL = {
        let folderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/codex")
        return folderURL
    }()
    
    /// Filename for Codex's primary configuration file.
    static let CodexConfigFileName = "config.toml"
    
    /// API protocol type used for communication between Codex and XcodePAI proxy.
    ///
    /// Must match the `wire_api` value expected by the proxy service.
    /// Current value: `"responses"`
    static let CurrentCodexAPIType = "responses"
    
    /// Verifies Codex installation status by checking directory existence.
    ///
    /// - Returns: `true` if the Codex configuration directory exists and is valid; `false` otherwise.
    static func checkCodexInstall() -> Bool {
        do {
            let resourceValues = try CodexFolderURL.resourceValues(forKeys: [.isDirectoryKey])
            
            if let isDir = resourceValues.isDirectory, isDir {
                return true
            } else {
                // Path exists but is not a directory
                return false
            }
        } catch {
            return false
        }
    }
    
    /// Analyzes Codex configuration state against XcodePAI requirements.
    ///
    /// Validation steps:
    /// 1. Verifies Codex installation
    /// 2. Reads and parses `config.toml`
    /// 3. Checks `model_provider` value against `Constraint.InternalModelName`
    /// 4. Validates `model_providers` table contains correct proxy details:
    ///    - `base_url` matches `LocalProxyServer`
    ///    - `wire_api` matches `CurrentCodexAPIType`
    ///
    /// - Returns: Current configuration state per `AgenticConfigerConfigState`
    static func checkCodexConfigState() -> AgenticConfigerConfigState {
        // 1. Verify installation and read config file
        guard checkCodexInstall(),
              let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8)
        else {
            return .notInstalled
        }
        
        do {
            // 2. Parse TOML configuration
            let doc = try TOMLDocument(content: content)
            
            // 3. Check active model provider
            if let modelProviderValue = doc["model_provider"],
               let modelProvider = modelProviderValue.stringValue {
                
                // 4. Detect non-XcodePAI provider configuration
                if modelProvider != Constraint.InternalModelName.lowercased() {
                    return .configuredWithOther
                } else {
                    // 5. Validate XcodePAI-specific configuration details
                    if let modelProviderTable = doc["model_providers"]?.tableValue,
                       let detailTable = modelProviderTable[Constraint.InternalModelName.lowercased()]?.tableValue,
                       detailTable["base_url"]?.stringValue == LocalProxyServer,
                       detailTable["wire_api"]?.stringValue == CurrentCodexAPIType {
                        return .configured
                    }
                    // Required fields missing or incorrect values
                    return .misconfigured
                }
            }
        } catch {
            // TOML parsing failure
            return .unknown
        }
        
        // Configuration file exists but lacks model_provider declaration
        return .notConfigured
    }
    
    /// Retrieves the default model name specified in Codex configuration.
    ///
    /// - Returns: Model name string from `model` field in `config.toml`, or `nil` if:
    ///   - Codex is not installed
    ///   - Configuration file is unreadable
    ///   - `model` field is missing or unparsable
    static func codexDefaultModelName() -> String? {
        guard checkCodexInstall(),
              let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8)
        else {
            return nil
        }
        
        do {
            let doc = try TOMLDocument(content: content)
            return doc["model"]?.stringValue
        } catch {
            return nil
        }
    }
    
    /// Configures Codex to use XcodePAI's local proxy service.
    ///
    /// Performs:
    /// 1. Reads existing `config.toml`
    /// 2. Injects/updates XcodePAI model provider entry in `model_providers` table
    /// 3. Sets `model_provider` to XcodePAI's internal identifier
    /// 4. Configures local MCP server endpoint in `mcp_servers` table
    /// 5. Persists updated configuration
    /// 6. Restarts Codex process to apply changes
    ///
    /// Uses `Constraint.InternalModelName` as the provider key (lowercased).
    /// Does not throw errors; failures are silently ignored.
    static func setupCodexProxyConfig() {
        guard checkCodexInstall(),
              let content = try? String(contentsOf: CodexFolderURL.appendingPathComponent(CodexConfigFileName), encoding: .utf8)
        else {
            return
        }
        
        do {
            // Parse existing configuration
            let doc = try TOMLDocument(content: content)
            
            // Create XcodePAI provider configuration
            let detailTable = TOMLValue.table([
                "name": .string("XcodePaI LLM Proxy"),
                "base_url": .string(LocalProxyServer),
                "wire_api": .string(CurrentCodexAPIType)
            ])
            
            // Get or initialize model_providers table
            var modelProvidersTable: [String: TOMLValue] = {
                if let existing = doc["model_providers"]?.tableValue {
                    return existing
                }
                return [:]
            }()
            
            // Inject/update XcodePAI configuration
            modelProvidersTable[Constraint.InternalModelName.lowercased()] = detailTable
            
            // Update document with new configuration
            doc["model_providers"] = .table(modelProvidersTable)
            doc["model_provider"] = .string(Constraint.InternalModelName.lowercased())
            
            // Configure local MCP server
            let mcpServerConfig = TOMLValue.table([
                "url": .string(LocalMCPServer),
                "enabled": .boolean(true)
            ])
            
            // Get or initialize mcp_servers table
            var mcpServersTable: [String: TOMLValue] = {
                if let existing = doc["mcp_servers"]?.tableValue {
                    return existing
                }
                return [:]
            }()
            
            // Inject/update XcodePAI MCP server configuration
            mcpServersTable[Constraint.InternalModelName.lowercased()] = mcpServerConfig
            doc["mcp_servers"] = .table(mcpServersTable)
            
            // Persist changes
            try doc.write(to: CodexFolderURL.appendingPathComponent(CodexConfigFileName))
            
            // Restart Codex service to apply configuration
            if CommandRunner.isProcessRunning(name: "codex") {
                CommandRunner.killProcess(byName: "codex", force: true)
            }
        } catch {
            // Silent failure on configuration update error
            return
        }
    }
    
    // MARK: - Claude Code Configuration Management
    
    /// Default filesystem path for Claude Code configuration directory.
    ///
    /// Path: `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig`
    /// Contains `.claude.json` configuration file.
    static let ClaudeFolderURL = {
        let folderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig")
        return folderURL
    }()
    
    /// Filename for Claude Code's configuration file (hidden file).
    static let ClaudeConfigFileName = ".claude.json"
    
    /// Verifies Claude Code installation status by checking directory existence.
    ///
    /// - Returns: `true` if the Claude configuration directory exists and is valid; `false` otherwise.
    static func checkClaudeInstall() -> Bool {
        do {
            let resourceValues = try ClaudeFolderURL.resourceValues(forKeys: [.isDirectoryKey])
            
            if let isDir = resourceValues.isDirectory, isDir {
                return true
            } else {
                // Path exists but is not a directory
                return false
            }
        } catch {
            return false
        }
    }
    
    /// Analyzes Claude Code configuration state against XcodePAI requirements.
    ///
    /// Validation steps:
    /// 1. Verifies Claude installation
    /// 2. Parses `.claude.json` as JSON
    /// 3. Checks `env.ANTHROPIC_BASE_URL` value
    ///
    /// - Returns:
    ///   - `.configured` if `ANTHROPIC_BASE_URL` matches `LocalProxyServer`
    ///   - `.configuredWithOther` if URL is set but differs from proxy
    ///   - `.notConfigured` if `env` or `ANTHROPIC_BASE_URL` missing
    ///   - `.misconfigured` on JSON parsing errors
    static func checkClaudeConfigState() -> AgenticConfigerConfigState {
        guard checkClaudeInstall(),
              let data = try? Data(contentsOf: ClaudeFolderURL.appendingPathComponent(ClaudeConfigFileName))
        else {
            return .notInstalled
        }
        
        do {
            if let configuration = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let env = configuration["env"] as? [String: Any],
               let baseUrl = env["ANTHROPIC_BASE_URL"] as? String {
                
                return baseUrl == LocalProxyServer ? .configured : .configuredWithOther
            }
            // env block or ANTHROPIC_BASE_URL missing
            return .notConfigured
        } catch {
            return .misconfigured
        }
    }
    
    /// Configures Claude Code to use XcodePAI's local proxy service.
    ///
    /// Performs:
    /// 1. Reads existing `.claude.json`
    /// 2. Sets `env.ANTHROPIC_BASE_URL` to `LocalProxyServer`
    /// 3. Persists updated configuration
    /// 4. Restarts Claude process to apply changes
    ///
    /// Does not throw errors; failures are silently ignored.
    static func setupClaudeProxyConfig() {
        guard checkClaudeInstall(),
              let data = try? Data(contentsOf: ClaudeFolderURL.appendingPathComponent(ClaudeConfigFileName))
        else {
            return
        }
        
        do {
            if var configuration = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Update or create env dictionary with proxy URL
                var env = configuration["env"] as? [String: Any] ?? [:]
                env["ANTHROPIC_BASE_URL"] = LocalProxyServer
                configuration["env"] = env
                
                // Write updated configuration
                let updatedData = try JSONSerialization.data(withJSONObject: configuration)
                try updatedData.write(to: ClaudeFolderURL.appendingPathComponent(ClaudeConfigFileName))
            }
            
            // Restart Claude service to apply configuration
            if CommandRunner.isProcessRunning(name: "claude") {
                CommandRunner.killProcess(byName: "claude", force: true)
            }
        } catch {
            // Silent failure on configuration update error
            return
        }
    }
}
