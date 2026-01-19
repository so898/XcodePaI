//
//  CommandFinder.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/12/12.
//

import Foundation

class CommandFinder {
    
    /// Checks if a command exists and returns its binary file path.
    /// - Parameter command: The command name.
    /// - Returns: A tuple `(exists: Bool, path: String?)` indicating whether the command exists and its binary path (nil if not found).
    static func findCommand(_ command: String) -> (exists: Bool, path: String?) {
        // Method 1: Use the `which` command (preferred)
        if let whichPath = runShellCommand("which", arguments: [command]) {
            return (true, whichPath.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Method 2: Use the `type` command (fallback for shell built-ins)
        if let typePath = runShellCommand("type", arguments: ["-p", command]) {
            return (true, typePath.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Method 3: Check standard paths
        let standardPaths = [
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/opt/homebrew/bin",  // Apple Silicon Homebrew
            "/usr/local/opt",      // Intel Homebrew
            NSHomeDirectory() + "/.local/bin"
        ]
        
        for path in standardPaths {
            let fullPath = "\(path)/\(command)"
            if FileManager.default.fileExists(atPath: fullPath) {
                return (true, fullPath)
            }
        }
        
        // Method 4: Search through the PATH environment variable
        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            let paths = envPath.components(separatedBy: ":")
            for path in paths {
                let fullPath = "\(path)/\(command)"
                if FileManager.default.fileExists(atPath: fullPath) {
                    return (true, fullPath)
                }
            }
        }
        
        return (false, nil)
    }
    
    /// Checks if a command exists.
    /// - Parameter command: The command name.
    /// - Returns: `true` if the command exists, otherwise `false`.
    static func commandExists(_ command: String) -> Bool {
        return findCommand(command).exists
    }
    
    /// Gets the binary file path of a command.
    /// - Parameter command: The command name.
    /// - Returns: The binary file path, or `nil` if the command does not exist.
    static func getCommandPath(_ command: String) -> String? {
        return findCommand(command).path
    }
    
    /// Executes a shell command and returns its output.
    private static func runShellCommand(_ command: String, arguments: [String]) -> String? {
        do {
            let result = try CommandRunner.runWithEnv(
                command: command,
                arguments: arguments
            )
            
            if result.isSuccess {
                let output = result.output
                return output.isEmpty ? nil : output
            }
        } catch {
            print("Error executing command: \(error)")
        }
        
        return nil
    }
}
