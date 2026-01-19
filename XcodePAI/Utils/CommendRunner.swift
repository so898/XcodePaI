//
//  CommendRunner.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/1/20.
//

import Foundation

// MARK: - Command Result

/// Result of a command execution
struct CommandResult {
    /// Standard output content
    let output: String
    /// Standard error content
    let errorOutput: String
    /// Process exit code
    let exitCode: Int32
    
    /// Whether the command executed successfully (exit code 0)
    var isSuccess: Bool { exitCode == 0 }
    
    /// Trimmed output (removes leading/trailing whitespace and newlines)
    var trimmedOutput: String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Command Runner Error

enum CommandRunnerError: Error, LocalizedError {
    case executableNotFound(path: String)
    case executionFailed(error: Error)
    case invalidWorkingDirectory(path: String)
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found at path: \(path)"
        case .executionFailed(let error):
            return "Command execution failed: \(error.localizedDescription)"
        case .invalidWorkingDirectory(let path):
            return "Invalid working directory: \(path)"
        }
    }
}

// MARK: - Command Runner

/// Unified command execution utility
/// Provides both synchronous and asynchronous methods for running shell commands
struct CommandRunner {
    
    // MARK: - Synchronous Execution
    
    /// Execute a command synchronously
    /// - Parameters:
    ///   - executablePath: Full path to the executable
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory (optional)
    ///   - environment: Environment variables (optional)
    /// - Returns: CommandResult containing output, error output, and exit code
    /// - Throws: CommandRunnerError if execution fails
    static func run(
        executablePath: String,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
            if process.isRunning {
                process.terminate()
            }
        }
        
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        if let workingDirectory = workingDirectory {
            guard FileManager.default.fileExists(atPath: workingDirectory) else {
                throw CommandRunnerError.invalidWorkingDirectory(path: workingDirectory)
            }
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        if let environment = environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                processEnv[key] = value
            }
            process.environment = processEnv
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            return CommandResult(
                output: output,
                errorOutput: errorOutput,
                exitCode: process.terminationStatus
            )
        } catch {
            throw CommandRunnerError.executionFailed(error: error)
        }
    }
    
    /// Execute a command using /usr/bin/env (useful for commands in PATH)
    /// - Parameters:
    ///   - command: Command name (will be resolved via PATH)
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory (optional)
    /// - Returns: CommandResult
    /// - Throws: CommandRunnerError if execution fails
    static func runWithEnv(
        command: String,
        arguments: [String],
        workingDirectory: String? = nil
    ) throws -> CommandResult {
        return try run(
            executablePath: "/usr/bin/env",
            arguments: [command] + arguments,
            workingDirectory: workingDirectory
        )
    }
    
    // MARK: - Asynchronous Execution
    
    /// Execute a command asynchronously
    /// - Parameters:
    ///   - executablePath: Full path to the executable
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory (optional)
    ///   - environment: Environment variables (optional)
    /// - Returns: CommandResult containing output, error output, and exit code
    static func runAsync(
        executablePath: String,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async -> CommandResult {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                if let workingDirectory = workingDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                }
                
                if let environment = environment {
                    var processEnv = ProcessInfo.processInfo.environment
                    for (key, value) in environment {
                        processEnv[key] = value
                    }
                    process.environment = processEnv
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: CommandResult(
                        output: output,
                        errorOutput: errorOutput,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(returning: CommandResult(
                        output: "",
                        errorOutput: error.localizedDescription,
                        exitCode: -1
                    ))
                }
            }
        }
    }
    
    /// Execute a command asynchronously using /usr/bin/env
    /// - Parameters:
    ///   - command: Command name (will be resolved via PATH)
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory (optional)
    /// - Returns: CommandResult
    static func runAsyncWithEnv(
        command: String,
        arguments: [String],
        workingDirectory: String? = nil
    ) async -> CommandResult {
        return await runAsync(
            executablePath: "/usr/bin/env",
            arguments: [command] + arguments,
            workingDirectory: workingDirectory
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Execute a Git command
    /// - Parameters:
    ///   - arguments: Git command arguments
    ///   - repositoryPath: Path to the Git repository
    /// - Returns: CommandResult
    static func runGitCommand(
        _ arguments: [String],
        in repositoryPath: String
    ) async -> CommandResult {
        return await runAsync(
            executablePath: "/usr/bin/git",
            arguments: arguments,
            workingDirectory: repositoryPath
        )
    }
}
