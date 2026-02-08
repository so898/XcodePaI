//
//  LLMCodexRequest.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/7.
//

import Foundation

struct LLMCodexRequest: Codable {
    let model: String
    let instructions: String?
    let input: [LLMCodexInputModel]?
    let tools: [LLMCodexToolModel]?
    let toolChoice: String?
    let parallelToolCalls: Bool?
    let promptCacheKey: String?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case tools
        case toolChoice = "tool_choice"
        case parallelToolCalls = "parallel_tool_calls"
        case promptCacheKey = "prompt_cache_key"
        case stream
    }
    
    init(
        model: String,
        instructions: String? = nil,
        input: [LLMCodexInputModel]? = nil,
        tools: [LLMCodexToolModel]? = nil,
        toolChoice: String? = nil,
        parallelToolCalls: Bool? = nil,
        promptCacheKey: String? = nil,
        stream: Bool = true
    ) {
        self.model = model
        self.instructions = instructions
        self.input = input
        self.tools = tools
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
        self.promptCacheKey = promptCacheKey
        self.stream = stream
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decode(String.self, forKey: .model)
        self.instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        self.input = try container.decodeIfPresent([LLMCodexInputModel].self, forKey: .input)
        self.tools = try container.decodeIfPresent([LLMCodexToolModel].self, forKey: .tools)
        self.toolChoice = try container.decodeIfPresent(String.self, forKey: .toolChoice)
        self.parallelToolCalls = try container.decodeIfPresent(Bool.self, forKey: .parallelToolCalls)
        self.promptCacheKey = try container.decodeIfPresent(String.self, forKey: .promptCacheKey)
        self.stream = try container.decodeIfPresent(Bool.self, forKey: .stream) ?? true
    }
}

struct LLMCodexInputModel: Codable {
    let id: String?
    let type: String?
    let role: String?
    let content: [LLMCodexInputContentModel]?
    
    // Funciton Call
    let name: String?
    let arguments: String?
    let callId: String?
    let output: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, name, arguments, output
        case callId = "call_id"
    }
    
    init(
        id: String? = nil,
        type: String? = nil,
        role: String? = nil,
        content: [LLMCodexInputContentModel]? = nil
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        
        self.name = nil
        self.arguments = nil
        self.callId = nil
        self.output = nil
    }
    
    init(
        id: String? = nil,
        type: String? = nil,
        name: String? = nil,
        arguments: String? = nil,
        callId: String? = nil,
        output: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.arguments = arguments
        self.callId = callId
        self.output = output
        
        self.role = nil
        self.content = nil
    }
}

struct LLMCodexInputContentModel: Codable {
    let type: String?
    let text: String?
    
    init(type: String? = nil, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

struct LLMCodexToolModel: Codable {
    let name: String
    let parameters: LLMCodexToolParameterModel
    let type: String
    let strict: Bool
    let description: String?
    
    init(
        name: String,
        parameters: LLMCodexToolParameterModel,
        type: String = "function",
        strict: Bool = false,
        description: String? = nil
    ) {
        self.name = name
        self.parameters = parameters
        self.type = type
        self.strict = strict
        self.description = description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "unknown"
        self.parameters = try container.decodeIfPresent(LLMCodexToolParameterModel.self, forKey: .parameters) ?? LLMCodexToolParameterModel()
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "function"
        self.strict = try container.decodeIfPresent(Bool.self, forKey: .strict) ?? false
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
    
    func toPrompt() -> String {
        var ret = "<tool><name>\(name)</name>"
        if let description {
            ret += "<description>\(description)</description>"
        }
        if let data = try? JSONEncoder().encode(parameters), let schema = String(data: data, encoding: .utf8) {
            ret += "<arguments>\(schema)</arguments>"
        }
        ret += "</tool>"
        
        return ret
    }
}

struct LLMCodexToolParameterModel: Codable {
    let type: String?
    let properties: [String: LLMCodexToolParameterPropertyInfoModel]?
    let required: [String]?
    let additionalProperties: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case required
        case additionalProperties = "additional_properties"
    }
    
    init(
        type: String? = nil,
        properties: [String: LLMCodexToolParameterPropertyInfoModel]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

struct LLMCodexToolParameterPropertyInfoModel: Codable {
    let type: String?
    let description: String?
    
    init(type: String? = nil, description: String? = nil) {
        self.type = type
        self.description = description
    }
}
