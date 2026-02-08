//
//  ResponseCodeSnippetFixer.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/9.
//

import Foundation

// Fixer for Xcode 26.1.1+
class ResponseCodeSnippetFixer {
    private enum State {
        case normal
        case firstBacktick
        case secondBacktick
        case thirdBacktick
    }
    
    private var status = State.normal
    private var backtick: Character = "`"
    private var markdownLanguage: String = ""
    
    func processMessage(_ content: String) -> String {
        if status == .normal, !content.contains(backtick) {
            return content
        }
        var newContent = ""
        for char in content {
            switch status {
            case .normal:
                if char == backtick {
                    status = .firstBacktick
                }
            case .firstBacktick:
                if char == backtick {
                    status = .secondBacktick
                } else {
                    status = .normal
                }
            case .secondBacktick:
                if char == backtick {
                    status = .thirdBacktick
                } else {
                    status = .normal
                }
            case .thirdBacktick:
                if char == ":" {
                    // Has filename, just return
                    status = .normal
                    markdownLanguage = ""
                } else if char == "\n" {
                    status = .normal
                    if markdownLanguage.count > 0 {
                        // No filename, add filename
                        let ext = languageExtensions[markdownLanguage.lowercased()] ?? "txt"
                        markdownLanguage = ""
                        newContent.append(": Code Snippet.\(ext)")
                    }
                } else {
                    markdownLanguage.append(char)
                }
            }
            newContent.append(char)
        }
        
        return newContent
    }
    
    private let languageExtensions: [String: String] = [
        "swift": "swift",
        "python": "py",
        "javascript": "js",
        "typescript": "ts",
        "java": "java",
        "kotlin": "kt",
        "cpp": "cpp",
        "c": "c",
        "go": "go",
        "rust": "rs",
        "ruby": "rb",
        "php": "php",
        "html": "html",
        "css": "css",
        "json": "json",
        "xml": "xml",
        "yaml": "yaml",
        "sql": "sql",
        "shell": "sh",
        "bash": "sh",
        "markdown": "md",
        "m": "m",
        "h": "h",
        "objc": "m",
        "objective-c": "m",
        "text": "txt",
    ]
}
