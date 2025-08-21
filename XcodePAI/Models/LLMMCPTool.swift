//
//  LLMMCPTool.swift
//  XcodePAI
//
//  Created by Bill Cheng on 8/15/25.
//

import Foundation
import MCP

final class LLMMCPTool: Identifiable, Codable, Sendable {
    let id: UUID
    
    var toolName: String {
        get {
            return "\(mcp)_\(name)"
        }
    }
    
    let mcp: String
    let name: String
    let description: String
    let schema: String?
    
    enum CodingKeys: CodingKey {
        case id
        case mcp
        case name
        case description
        case schema
    }
    
    init(id: UUID = UUID(), mcp: String, name: String, description: String, schema: String? = nil) {
        self.id = id
        self.mcp = mcp
        self.name = name
        self.description = description
        self.schema = schema
    }
    
    init(tool: Tool, mcp: String) {
        self.id = UUID()
        self.mcp = mcp
        self.name = tool.name
        self.description = tool.description
        if let jsonData = try? JSONEncoder().encode(tool.inputSchema), let schema = String(data: jsonData, encoding: .utf8) {
            self.schema = schema
        } else {
            self.schema = nil
        }
    }
    
    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mcp = try container.decode(String.self, forKey: .mcp)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        schema = try container.decodeIfPresent(String.self, forKey: .schema)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mcp, forKey: .mcp)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(schema, forKey: .schema)
    }
    
    func toPrompt() -> String {
        var ret = """
            <tool>
            <name>\(toolName)</name>
            <description>\(description)</description>
            """
        if let schema = schema {
            ret += "\n<arguments>\(schema)</arguments>"
        }
        ret += "\n</tool>\n"
        
        return ret
    }

    func toReqeustTool() -> LLMTool {
        return LLMTool(type: "function", function: LLMFunction(name: toolName, description: description, parameters: schema))
    }
}
