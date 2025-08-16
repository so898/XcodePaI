//
//  LLMMCPToolUse.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/17.
//

import Foundation

class LLMMCPToolUse: NSObject {
    var toolName: String
    var arguments: String?
    
    var tool: LLMMCPTool?
    
    init(content: String) {
        var processContent = content.replacingOccurrences(of: "\n", with: "")
        processContent = processContent.replacingOccurrences(of: ToolUseStartMark, with: "")
        processContent = processContent.replacingOccurrences(of: ToolUseEndMark, with: "")
        
        toolName = ""
        
        while processContent.count > 0 {
            if processContent.substring(to: 6) == "<name>" {
                let components = processContent.replacingOccurrences(of: "<name>", with: "").components(separatedBy: "</name>")
                if components.count == 2 {
                    toolName = String(components[0])
                } else {
                    fatalError("MCP tool use name parser fail")
                }
                processContent = components[1]
            } else if processContent.substring(to: 6) == "<arguments>" {
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
    
}
