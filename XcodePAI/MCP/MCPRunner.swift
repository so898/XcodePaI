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

@MainActor
class MCPRunner {
    static let shared = MCPRunner()

    private var checkingMCP: LLMMCP?

    // Store processes per MCP name
    private var localProcesses: [String: Process] = [:]
    // Store clients per MCP name for keepAlive
    private var activeClients: [String: Client] = [:]
    // Store timeout tasks per MCP name
    private var timeoutTasks: [String: Task<Void, Never>] = [:]
    // Store last active time per MCP
    private var lastActiveTimes: [String: Date] = [:]

    // MARK: - Public Interface
    func check(mcp: LLMMCP, complete: @escaping (Bool, [LLMMCPTool]?) -> Void) {
        checkingMCP = mcp
        Task {
            // Clean up any existing process/client/timeout for this MCP before checking
            // This prevents crashes when checking an MCP that's already running
            await terminateMCPProcess(mcpName: mcp.name)

            let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)

            defer {
                Task {
                    await client.disconnect()
                }
            }

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
                    await terminateMCPProcess(mcpName: mcp.name)
                    return
                }
            }
            DispatchQueue.main.async {
                complete(false, nil)
            }

            await client.disconnect()
            await terminateMCPProcess(mcpName: mcp.name)
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
        // Update last active time
        lastActiveTimes[mcp.name] = Date()

        // Cancel any existing timeout task
        timeoutTasks[mcp.name]?.cancel()

        // Check if we have an existing client for keepAlive and validate it's still usable
        if mcp.keepAlive, let existingClient = activeClients[mcp.name] {
            // Validate client is still connected and process is running
            if await isClientValid(existingClient, mcpName: mcp.name) {
                // Update last active time
                lastActiveTimes[mcp.name] = Date()
                // Use existing client and process
                let result = try await callToolWithClient(existingClient, mcp: mcp, tool: tool, arguments: arguments)
                // Schedule timeout after successful call
                scheduleKeepAliveTimeout(mcp: mcp)
                return result
            } else {
                // Client is invalid (process crashed or disconnected) - clean up
                await terminateMCPProcess(mcpName: mcp.name)
            }
        }

        // Create new client and transport
        let client = Client(name: Constraint.AppName, version: Constraint.AppVersion)

        guard let transport = makeTransport(mcp: mcp) else {
            throw MCPError.invalidURL
        }

        // Connect to server
        try await client.connect(transport: transport)

        // Store client if keepAlive is enabled
        if mcp.keepAlive {
            activeClients[mcp.name] = client
        }

        let result = try await callToolWithClient(client, mcp: mcp, tool: tool, arguments: arguments)

        // Handle keepAlive logic
        if mcp.keepAlive {
            // Schedule timeout to terminate process
            scheduleKeepAliveTimeout(mcp: mcp)
        } else {
            // Disconnect and terminate immediately
            await client.disconnect()
            localProcesses[mcp.name]?.terminate()
            localProcesses.removeValue(forKey: mcp.name)
        }

        return result
    }

    private func callToolWithClient(_ client: Client, mcp: LLMMCP, tool: LLMMCPTool, arguments: [String: Value]?) async throws -> String {
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

        // Extract text content
        guard let textContent = content.compactMap({ contentItem -> String? in
            if case .text(let text, _, _) = contentItem {
                return text
            }
            return nil
        }).first else {
            throw MCPError.noTextContent
        }

        return textContent
    }

    private func scheduleKeepAliveTimeout(mcp: LLMMCP) {
        let timeout = mcp.keepAliveTimeout ?? 300 // Default 5 minutes

        timeoutTasks[mcp.name] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)

                // Check if task was cancelled
                try Task.checkCancellation()

                // Check if still idle - compare current lastActiveTime with when we started sleeping
                // If there's been activity since we scheduled this timeout, don't terminate
                if let self = self {
                    let currentLastActive = self.lastActiveTimes[mcp.name]
                    let scheduledTime = Date().addingTimeInterval(-Double(timeout))
                    
                    // Only terminate if there hasn't been any activity since we scheduled the timeout
                    if let lastActive = currentLastActive, lastActive < scheduledTime {
                        await self.terminateMCPProcess(mcpName: mcp.name)
                    }
                }
            } catch {
                // Task was cancelled or error occurred
            }
        }
    }

    private func terminateMCPProcess(mcpName: String) async {
        if let client = activeClients[mcpName] {
            await client.disconnect()
            activeClients.removeValue(forKey: mcpName)
        }

        localProcesses[mcpName]?.terminate()
        localProcesses.removeValue(forKey: mcpName)
        timeoutTasks[mcpName]?.cancel()
        timeoutTasks.removeValue(forKey: mcpName)
        lastActiveTimes.removeValue(forKey: mcpName)
    }

    private func isClientValid(_ client: Client, mcpName: String) async -> Bool {
        // Check if process is still running for local MCP
        if let process = localProcesses[mcpName] {
            // isRunning can return true even if process crashed, so we also check
            // the process terminationStatus - a negative value indicates abnormal termination
            if !process.isRunning || process.terminationStatus != 0 {
                return false
            }
        }
        // For remote MCP, we could ping the server but for simplicity we assume it's valid
        // The actual call will fail if there's an issue
        return true
    }

    private func makeTransport(mcp: LLMMCP) -> Transport? {
        if mcp.url == "local" {
            // Check if we already have a valid process for this MCP
            if let existingProcess = localProcesses[mcp.name] {
                // Verify process is actually running and healthy
                // isRunning can return true even after crash, so check terminationStatus too
                if existingProcess.isRunning && existingProcess.terminationStatus == 0 {
                    return existingProcess.stdioTransport()
                }
                // Process is dead or crashed - clean up
                existingProcess.terminate()
                localProcesses.removeValue(forKey: mcp.name)
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

            localProcesses[mcp.name] = process

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
