//
//  MCPRunner.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/17.
//

import Foundation
import MCP
import System

// MARK: - Error Definitions
enum MCPError: LocalizedError {
    case mcpNotFound
    case toolNotFound
    case invalidURL
    case noTextContent
    case toolExecutionError(String)
    case toolExecutionTimeout
    
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
        case .toolExecutionTimeout:
            return "Tool execution timeout"
        }
    }
}

class MCPRunner {
    static let shared = MCPRunner()
    
    private var checkingMCP: LLMMCP?
    
    private var localProcess: Process?
    
    // MARK: - Public Interface
    func check(mcp: LLMMCP, complete: @escaping (Bool, [LLMMCPTool]?) -> Void) {
        checkingMCP = mcp
        Task {
            let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)

            guard let transport = makeTransport(mcp: mcp) else {
                DispatchQueue.main.async {
                    complete(false, nil)
                }
                return
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
                    
                    await client.disconnect()
                    localProcess?.terminate()
                    
                    return
                }
            }
            DispatchQueue.main.async {
                complete(false, nil)
            }
            
            await client.disconnect()
            localProcess?.terminate()
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
        defer {
            localProcess?.terminate()
        }
        // Create client and transport
        let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)
        
        guard let transport = makeTransport(mcp: mcp) else {
            throw MCPError.invalidURL
        }
        
        // Connect to server
        try await client.connect(transport: transport)
        
        // Call tool
        let (content, isError) = try await Utils.withTimeout(seconds: TimeInterval(mcp.timeout ?? 60), throwError: MCPError.toolExecutionTimeout) {
            return try await client.callTool(
                name: tool.name,
                arguments: arguments
            )
        }
        
        // Handle errors
        if let isError = isError, isError {
            throw MCPError.toolExecutionError("Tool execution failed")
        }
        
        await client.disconnect()
        
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
    
    private func makeTransport(mcp: LLMMCP) -> Transport? {
        if mcp.url == "local" {
            // Terminate last process
            if let localProcess {
                localProcess.terminate()
            }
            
            let command: String = mcp.command ?? "npx"
            
            let result = CommandFinder.findCommand(command)
            var exe = ""
            if result.exists, let path = result.path {
                exe = path
            } else {
                return nil
            }
            
            // If a command is specified, launch it and redirect I/O
            let process = Process()
            process.executableURL = URL(fileURLWithPath: exe)
            process.arguments = mcp.args ?? []
            
            // copy current process environment
            var env = ProcessInfo.processInfo.environment
            
            let binDir = URL(fileURLWithPath: exe).deletingLastPathComponent().path
            if env["PATH"] == nil {
                env["PATH"] = binDir
            } else if !env["PATH"]!.contains(binDir) {
                env["PATH"] = binDir + ":" + env["PATH"]!
            }
            
            if let mcpEnv = mcp.env {
                for key in mcpEnv.keys {
                    if let value = mcpEnv[key] {
                        env[key] = value
                    }
                }
            }
            
            process.environment = env
            let transport = process.stdioTransport()
            
            do {
                try process.run()
            } catch {
                return nil
            }
            
            localProcess = process
            
            return transport
        } else if let url = URL(string: mcp.url) {
            return HTTPClientTransport(
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
        }
        
        return nil
    }
}

extension Process {
    
    func stdioTransport() -> StdioTransport {
        let input = Pipe()
        let output = Pipe()
        self.standardInput = input
        self.standardOutput = output
        
        return StdioTransport(
            input: FileDescriptor(rawValue: output.fileHandleForReading.fileDescriptor),
            output: FileDescriptor(rawValue: input.fileHandleForWriting.fileDescriptor)
        )
    }
    
}
