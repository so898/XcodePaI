//
//  LLMMCPToolUse.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/17.
//

import Foundation

let ToolUseStartMark = "<tool_use>"
let ToolUseEndMark = "</tool_use>"

enum LLMMCPToolUseError: Error, LocalizedError {
    case invalidToolNameFormat
    case invalidArgumentFormat
    case unsupportedContent

    var errorDescription: String? {
        switch self {
        case .invalidToolNameFormat:
            return "Misformat <name> tag in MCP request"
        case .invalidArgumentFormat:
            return "Misformat <arguments> or <argument> tag in MCP request"
        case .unsupportedContent:
            return "Not supported tag in MCP request"
        }
    }
}

class LLMMCPToolUse: NSObject {
    let content: String?
    
    var toolName: String
    var arguments: String?
    
    var tool: LLMMCPTool?

    // Tool calls
    var tid: String?
    var type: String?
    
    init(content: String) throws {
        self.content = content
        
        var processContent = content
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ToolUseStartMark, with: "")
            .replacingOccurrences(of: ToolUseEndMark, with: "")
        
        toolName = ""
        
        while processContent.count > 0 {
            if processContent.count >= 6, processContent.substring(to: 6) == "<name>" {
                let components = processContent.replacingOccurrences(of: "<name>", with: "").components(separatedBy: "</name>")
                if components.count == 2 {
                    toolName = String(components[0])
                } else {
                    throw LLMMCPToolUseError.invalidToolNameFormat
                }
                processContent = components[1]
            } else if processContent.count >= 10, processContent.substring(to: 11) == "<argument>" {
                let components = processContent.replacingOccurrences(of: "<argument>", with: "").components(separatedBy: "</argument>")
                if components.count == 2 {
                    arguments = String(components[0])
                } else {
                    throw LLMMCPToolUseError.invalidArgumentFormat
                }
                processContent = components[1]
            } else if processContent.count >= 11, processContent.substring(to: 11) == "<arguments>" {
                let components = processContent.replacingOccurrences(of: "<arguments>", with: "").components(separatedBy: "</arguments>")
                if components.count == 2 {
                    arguments = String(components[0])
                } else {
                    throw LLMMCPToolUseError.invalidArgumentFormat
                }
                processContent = components[1]
            } else {
                throw LLMMCPToolUseError.unsupportedContent
            }
        }
    }

    init(toolName: String, arguments: String?, tid: String? = nil, type: String? = nil) {
        self.content = nil
        self.toolName = toolName
        self.arguments = arguments
        self.tid = tid
        self.type = type
    }
    
    // For request message
    func messageToolCall() -> LLMMessageToolCall {
        return LLMMessageToolCall(
            id: tid ?? "",
            type: type ?? "",
            function: LLMFunction(
                name: toolName,
                description: nil,
                parameters: nil,
                arguments: arguments
            )
        )
    }
}
