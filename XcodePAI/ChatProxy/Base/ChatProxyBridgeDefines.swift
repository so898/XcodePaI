//
//  ChatProxyBridgeDefines.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/9.
//

// Think state enumeration
enum ThinkState {
    case notStarted  // Not started
    case inProgress  // In progress
    case completed   // Completed
}

// Think parser type enumeration
enum ThinkParser: Int {
    case inContentWithCodeSnippet = 0  // Content with code snippet
    case inContentWithEOT = 1           // Content with EOT marker
    case inReasoningContent = 2        // Reasoning content
}

// Source code in content structure
struct SourceCodeInContent {
    let fileType: String?  // File type (optional)
    let fileName: String?  // File name (optional)
    let content: String    // Source code content
}
