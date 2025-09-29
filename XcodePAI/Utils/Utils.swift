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
    static func extractMarkdownCodeBlocks(from text: String) -> [String] {
        var codeBlocks: [String] = []
        var currentLines: [String] = []
        var inCodeBlock = false
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if !inCodeBlock, isCodeBlockStart(line: line) {
                // New code block
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
        
        return codeBlocks
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
