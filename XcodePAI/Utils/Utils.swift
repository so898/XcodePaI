//
//  Utils.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/6.
//

import Foundation
import ApplicationServices

struct Utils {
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

// MARK: Extract code block from LLM reponse markdown
extension Utils {
    static func extractMarkdownCodeBlocks(from text: String) -> (Bool, [String]) {
        var codeBlocks: [String] = []
        var currentLines: [String] = []
        var inCodeBlock = false
        var foundCodeBlock = false
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if !inCodeBlock, isCodeBlockStart(line: line) {
                // New code block
                foundCodeBlock = true
                inCodeBlock = true
                currentLines = []
                continue
            } else if isCodeBlockEnd(line: line), inCodeBlock {
                // End current code block
                inCodeBlock = false
                if !currentLines.isEmpty {
                    if let lastLine = currentLines.last, lastLine.isEmpty {
                        // Ignore last blank line before end mark
                        currentLines.removeLast()
                    }
                    let codeContent = currentLines.joined(separator: "\n")
                    // Add \n at the last
                    codeBlocks.append(codeContent.appending("\n"))
                }
                continue
            }
            
            if inCodeBlock {
                // add line into code block
                if line.isEmpty, currentLines.count == 0 {
                    // Ignore first blank line after start mark
                    continue
                }
                currentLines.append(line)
            }
            
        }
        
        // Uncompleted code block
        if inCodeBlock && !currentLines.isEmpty {
            let codeContent = currentLines.joined(separator: "\n")
            codeBlocks.append(codeContent)
        }
        
        return (foundCodeBlock, codeBlocks)
    }
    
    // Check code block start mark
    static private func isCodeBlockStart(line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // support ``` and ~~~
        return trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
    }
    
    // Check code block end mark
    static private func isCodeBlockEnd(line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // support ``` and ~~~ as code block end mark
        return trimmedLine == "```" || trimmedLine == "~~~" ||
        trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
    }
}

// Async function helper
extension Utils {
    // Timeout
    static public func withTimeout<T>(
        seconds: TimeInterval,
        throwError: Error,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw throwError
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

enum FileSearchOption {
    case allFiles
    case withExtensions([String]) // Only include files with specific extensions
    case excludeExtensions([String]) // Exclude files with specific extensions
    case withPrefix(String) // Only include files with specific prefix
}

extension Utils {
    static func getAllFiles(in folderPath: String, options: FileSearchOption = .allFiles) -> [String]? {
        let fileManager = FileManager.default
        var allFiles: [String] = []
        
        // Check path validity
        guard fileManager.fileIsDirectory(atPath: folderPath) else {
            print("Error: Path does not exist or is not a directory")
            return nil
        }
        
        // Determine if file matches the options
        func shouldIncludeFile(_ filePath: String) -> Bool {
            let url = URL(fileURLWithPath: filePath)
            
            switch options {
            case .allFiles:
                return true
                
            case .withExtensions(let extensions):
                let fileExt = url.pathExtension.lowercased()
                return extensions.contains { $0.lowercased() == fileExt }
                
            case .excludeExtensions(let extensions):
                let fileExt = url.pathExtension.lowercased()
                return !extensions.contains { $0.lowercased() == fileExt }
                
            case .withPrefix(let prefix):
                return url.lastPathComponent.hasPrefix(prefix)
            }
        }
        
        // Recursive traversal function
        func traverseDirectory(at path: String) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                
                for item in contents {
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                        if isDir.boolValue {
                            // Skip some system folders (optional)
                            let fileName = (fullPath as NSString).lastPathComponent
                            if !fileName.hasPrefix(".") { // Skip hidden folders
                                traverseDirectory(at: fullPath)
                            }
                        } else {
                            // Check if it matches the filter criteria
                            if shouldIncludeFile(fullPath) {
                                allFiles.append(fullPath)
                            }
                        }
                    }
                }
            } catch {
                print("Error reading directory: \(error)")
            }
        }
        
        traverseDirectory(at: folderPath)
        
        // Sort alphabetically (optional)
        return allFiles.sorted()
    }
}
