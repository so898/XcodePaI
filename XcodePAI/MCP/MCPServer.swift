//
//  MCPServer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/18.
//

import Foundation
import MCP
import Network
import Logger

/// Protocol for MCP clients to receive server notifications
protocol MCPServerClientDelegate: AnyObject {
    /// Called when the tool list changes on the server
    func mcpServerToolsDidChange()
}

/// A local MCP server that runs on a specified port and allows dynamic tool registration
/// External clients can connect via HTTP/SSE and call registered MCP tools
class MCPServer: ObservableObject {
    static let shared = MCPServer()
    
    // MARK: - Published Properties
    @Published var registeredTools: [LLMMCPTool] = []
    
    // MARK: - Connected Clients (by Session ID)
    /// Thread-safe storage for connected SSE clients, keyed by session ID
    private var sessions = [String: MCPServerClientDelegate]()
    private let sessionsQueue = DispatchQueue(label: "com.xcodepai.mcpserver.sessions")
    
    // MARK: - Lifecycle
    private init() {}
    
    /// Update the list of available MCP tools dynamically
    /// - Parameter tools: Array of LLMMCPTool to register
    func updateTools(_ tools: [LLMMCPTool]) {
        registeredTools = tools
        Logger.mcp.info("Updated MCP tools: \(tools.count) tools registered")
        
        // Notify all connected clients about tool changes
        notifyClientsOfToolChange()
    }
    
    /// Add a single MCP tool
    /// - Parameter tool: The LLMMCPTool to add
    func addTool(_ tool: LLMMCPTool) {
        if !registeredTools.contains(where: { $0.toolName == tool.toolName }) {
            registeredTools.append(tool)
            Logger.mcp.info("Added MCP tool: \(tool.toolName)")
            notifyClientsOfToolChange()
        }
    }
    
    /// Remove a MCP tool by name
    /// - Parameter toolName: The name of the tool to remove
    func removeTool(toolName: String) {
        registeredTools.removeAll { $0.toolName == toolName }
        Logger.mcp.info("Removed MCP tool: \(toolName)")
        notifyClientsOfToolChange()
    }
    
    private func notifyClientsOfToolChange() {
        sessionsQueue.async { [weak self] in
            guard let self = self else { return }
            let sessionCount = self.sessions.count
            Logger.mcp.info("Notifying \(sessionCount) connected sessions about tool changes")
            for (sessionId, client) in self.sessions {
                Logger.mcp.info("Notifying session: \(sessionId)")
                client.mcpServerToolsDidChange()
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Register a session to receive tool change notifications
    /// - Parameters:
    ///   - sessionId: The MCP session ID
    ///   - client: The client delegate to register
    func registerSession(_ sessionId: String, client: MCPServerClientDelegate) {
        sessionsQueue.async { [weak self] in
            self?.sessions[sessionId] = client
            Logger.mcp.info("Session registered: \(sessionId), total sessions: \(self?.sessions.count ?? 0)")
        }
    }
    
    /// Unregister a session from receiving notifications
    /// - Parameter sessionId: The session ID to unregister
    func unregisterSession(_ sessionId: String) {
        sessionsQueue.async { [weak self] in
            self?.sessions.removeValue(forKey: sessionId)
            Logger.mcp.info("Session unregistered: \(sessionId), total sessions: \(self?.sessions.count ?? 0)")
        }
    }
    
    /// Get the number of connected sessions
    var connectedSessionsCount: Int {
        var count = 0
        sessionsQueue.sync {
            count = sessions.count
        }
        return count
    }
}

// MARK: - Request Handling
extension MCPServer {
    /// Handle an MCP protocol request
    /// - Parameters:
    ///   - method: The MCP method name
    ///   - params: The parameters for the method
    ///   - id: The JSON-RPC request id (nil for notifications)
    ///   - completion: Completion handler with the result (nil means no response needed)
    func handleRequest(method: String, params: [String: Any], id: Any?, completion: @escaping ([String: Any]?) -> Void) {
        // Check if this is a notification (no id field)
        let isNotification = id == nil
        
        switch method {
        case "initialize":
            handleInitialize(params: params, completion: completion)
        case "tools/list":
            handleToolsList(completion: completion)
        case "tools/call":
            handleToolsCall(params: params, completion: completion)
        case "ping":
            handlePing(completion: completion)
        case "notifications/initialized":
            // Notifications don't require a response per JSON-RPC spec
            handleNotificationInitialized()
            completion(nil)  // Signal no response needed
        default:
            // Handle other notifications (methods starting with "notifications/")
            if method.hasPrefix("notifications/") || isNotification {
                completion(nil)  // No response for notifications
            } else {
                Logger.mcp.info("Unknown MCP method: \(method)")
                completion(["error": ["message": "Unknown method: \(method)"]])
            }
        }
    }
    
    private func handleInitialize(params: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        // Get client's protocol version and echo it back for compatibility
        let clientProtocolVersion = params["protocolVersion"] as? String ?? "2025-06-18"
        
        // Response per MCP 2025-06-18 spec
        // capabilities.tools must include listChanged field
        let response: [String: Any] = [
            "protocolVersion": clientProtocolVersion,
            "capabilities": [
                "tools": [
                    "listChanged": true
                ]
            ],
            "serverInfo": [
                "name": "xcodepai-mcp-server",
                "title": "XcodePaI Local MCP Server",
                "version": "1.0.0"
            ]
        ]
        
        completion(response)
    }
    
    private func handleToolsList(completion: @escaping ([String: Any]?) -> Void) {
        let tools = registeredTools.map { tool -> [String: Any] in
            var toolDict: [String: Any] = [
                "name": tool.toolName,
                "description": tool.description
            ]
            
            if let schema = tool.schema,
               let jsonData = schema.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                toolDict["inputSchema"] = json
            } else {
                // Provide empty schema if not specified
                toolDict["inputSchema"] = [
                    "type": "object",
                    "properties": [:]
                ]
            }
            
            return toolDict
        }
        
        completion(["tools": tools])
    }
    
    private func handleToolsCall(params: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        guard let name = params["name"] as? String,
              let arguments = params["arguments"] as? [String: Any] else {
            completion(["error": ["message": "Invalid parameters"]])
            return
        }
        
        // Parse tool name (format: mcp_toolName)
        let components = name.split(separator: "_", maxSplits: 1)
        guard components.count == 2 else {
            completion(["error": ["message": "Invalid tool name format"]])
            return
        }
        
        let mcpName = String(components[0])
        let toolName = String(components[1])
        
        // Execute the tool via MCPRunner
        Task {
            do {
                let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
                let argumentsString = String(data: argumentsData, encoding: .utf8)
                
                let result = try await MCPRunner.shared.run(
                    mcpName: mcpName,
                    toolName: toolName,
                    arguments: argumentsString
                )
                
                completion([
                    "content": [
                        ["type": "text", "text": result]
                    ]
                ])
            } catch {
                completion([
                    "error": [
                        "message": error.localizedDescription,
                        "type": "tool_execution_error"
                    ]
                ])
            }
        }
    }
    
    private func handlePing(completion: @escaping ([String: Any]?) -> Void) {
        completion([:])
    }
    
    private func handleNotificationInitialized() {
        // Notifications don't require a response per JSON-RPC specification
        // The client should now send tools/list or other requests
    }
}
