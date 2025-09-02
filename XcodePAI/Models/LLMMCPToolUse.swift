//
//  LLMMCPToolUse.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/17.
//

import Foundation

class LLMMCPToolUse: NSObject {
    let content: String?
    
    var toolName: String
    var arguments: String?
    
    var tool: LLMMCPTool?

    // Tool calls
    var tid: String?
    var type: String?
    
    init(content: String) {
        self.content = content
        
        var processContent = content.replacingOccurrences(of: "\n", with: "")
        processContent = processContent.replacingOccurrences(of: ToolUseStartMark, with: "")
        processContent = processContent.replacingOccurrences(of: ToolUseEndMark, with: "")
        
        toolName = ""
        
        while processContent.count > 0 {
            if processContent.count >= 6, processContent.substring(to: 6) == "<name>" {
                let components = processContent.replacingOccurrences(of: "<name>", with: "").components(separatedBy: "</name>")
                if components.count == 2 {
                    toolName = String(components[0])
                } else {
                    fatalError("MCP tool use name parser fail")
                }
                processContent = components[1]
            } else if processContent.count >= 10, processContent.substring(to: 11) == "<argument>" {
                let components = processContent.replacingOccurrences(of: "<argument>", with: "").components(separatedBy: "</argument>")
                if components.count == 2 {
                    arguments = String(components[0])
                } else {
                    fatalError("MCP tool use name parser fail")
                }
                processContent = components[1]
            } else if processContent.count >= 11, processContent.substring(to: 11) == "<arguments>" {
                let components = processContent.replacingOccurrences(of: "<arguments>", with: "").components(separatedBy: "</arguments>")
                if components.count == 2 {
                    arguments = String(components[0])
                } else {
                    fatalError("MCP tool use name parser fail")
                }
                processContent = components[1]
            } else {
                fatalError("Unsupported tool use value")
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
    
    // For reqeust message
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
