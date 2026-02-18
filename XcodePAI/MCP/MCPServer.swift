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

/// A local MCP server that runs on a specified port and allows dynamic tool registration
/// External clients can connect via HTTP/SSE and call registered MCP tools
class MCPServer: ObservableObject {
    static let shared = MCPServer()
    
    // MARK: - Published Properties
    @Published var registeredTools: [LLMMCPTool] = []
    
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
        // In a real implementation, this would notify SSE clients
        // For now, tools are fetched on demand via the tools/list endpoint
    }
}

// MARK: - Request Handling
extension MCPServer {
    /// Handle an MCP protocol request
    /// - Parameters:
    ///   - method: The MCP method name
    ///   - params: The parameters for the method
    ///   - completion: Completion handler with the result
    func handleRequest(method: String, params: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        switch method {
        case "initialize":
            handleInitialize(params: params, completion: completion)
        case "tools/list":
            handleToolsList(completion: completion)
        case "tools/call":
            handleToolsCall(params: params, completion: completion)
        case "ping":
            handlePing(completion: completion)
        default:
            Logger.mcp.info("Unknown MCP method: \(method)")
            completion(["error": ["message": "Unknown method: \(method)"]])
        }
    }
    
    private func handleInitialize(params: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        let response: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [
                    "listChanged": true
                ]
            ],
            "serverInfo": [
                "name": "XcodePaI Local MCP Server",
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
}
