//
//  MCPRunner.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/17.
//

import Foundation
import MCP

// MARK: - Error Definitions
enum MCPError: LocalizedError {
    case mcpNotFound
    case toolNotFound
    case invalidURL
    case noTextContent
    case toolExecutionError(String)
    
    var errorDescription: String? {
        switch self {
        case .mcpNotFound:
            return "MCP not found"
        case .toolNotFound:
            return "MCP tool not found"
        case .invalidURL:
            return "Invalid URL"
        case .noTextContent:
            return "MCP tool returned no text content"
        case .toolExecutionError(let message):
            return "Tool execution error: \(message)"
        }
    }
}

class MCPRunner {
    static let shared = MCPRunner()
    
    private var checkingMCP: LLMMCP?
    
    // MARK: - Public Interface
    func check(mcp: LLMMCP, complete: @escaping (Bool, [LLMMCPTool]?) -> Void) {
        checkingMCP = mcp
        Task {
            guard let url = URL(string: mcp.url) else {
                DispatchQueue.main.async {
                    complete(false, nil)
                }
                return
            }
            
            let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)
            
            let transport = HTTPClientTransport(
                endpoint: url,
                streaming: false) { request in
                    guard let headers = mcp.headers else {
                        return request
                    }
                    var newRequest = request
                    for key in headers.keys {
                        if let value = headers[key] {
                            newRequest.setValue(value, forHTTPHeaderField: key)
                        }
                    }
                    return newRequest
                }
            
            if let result = try? await client.connect(transport: transport) {
                if result.capabilities.tools != nil {
                    let (tools, _) = try await client.listTools()
                    
                    var mcpTools = [LLMMCPTool]()
                    for tool in tools {
                        mcpTools.append(LLMMCPTool(tool: tool, mcp: mcp.name))
                    }
                    
                    DispatchQueue.main.async {
                        complete(true, mcpTools)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                complete(false, nil)
            }
        }
    }
    
    func run(mcpName: String, toolName: String, arguments: String?, complete: @escaping (Result<String, Error>) -> Void) {
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let content = try await self.run(mcpName: mcpName, toolName: toolName, arguments: arguments)
                await MainActor.run {
                    complete(.success(content))
                }
            } catch {
                await MainActor.run {
                    complete(.failure(error))
                }
            }
        }
    }
    
    func run(mcpName: String, toolName: String, arguments: String?) async throws -> String {
        let (mcp, tool, arguments) = try processMCPToolArgument(mcpName: mcpName, toolName: toolName, arguments: arguments)
        return try await run(mcp: mcp, tool: tool, arguments: arguments)
    }
    
    // MARK: - Private Helpers
    private func processMCPToolArgument(mcpName: String, toolName: String, arguments: String?) throws -> (LLMMCP, LLMMCPTool, [String: Value]?) {
        // Find MCP
        guard let mcp = StorageManager.shared.availableMCPs().first(where: { $0.name == mcpName }) else {
            throw MCPError.mcpNotFound
        }
        
        // Find Tool
        guard let tool = StorageManager.shared.mcpTools.first(where: { $0.mcp == mcpName && $0.name == toolName }) else {
            throw MCPError.toolNotFound
        }
        
        // Parse arguments
        let parsedArguments: [String: Value]? = {
            guard let argumentsString = arguments,
                  let data = argumentsString.data(using: .utf8) else {
                return nil
            }
            
            return try? JSONDecoder().decode([String: Value].self, from: data)
        }()
        
        return (mcp, tool, parsedArguments)
    }
    
    private func run(mcp: LLMMCP, tool: LLMMCPTool, arguments: [String: Value]?) async throws -> String {
        // Validate URL
        guard let url = URL(string: mcp.url) else {
            throw MCPError.invalidURL
        }
        
        // Create client and transport
        let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)
        
        let transport = HTTPClientTransport(
            endpoint: url,
            streaming: true
        ) { request in
            guard let headers = mcp.headers else { return request }
            var newRequest = request
            for (key, value) in headers {
                newRequest.setValue(value, forHTTPHeaderField: key)
            }
            return newRequest
        }
        
        // Connect to server
        try await client.connect(transport: transport)
        
        // Call tool
        let (content, isError) = try await client.callTool(
            name: tool.name,
            arguments: arguments
        )
        
        // Handle errors
        if let isError = isError, isError {
            throw MCPError.toolExecutionError("Tool execution failed")
        }
        
        // Extract text content
        guard let textContent = content.compactMap({ contentItem -> String? in
            if case .text(let text) = contentItem {
                return text
            }
            return nil
        }).first else {
            throw MCPError.noTextContent
        }
        
        return textContent
    }
}
