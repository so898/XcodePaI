//
//  LLMClaudeRequest.swift
//  XcodePAI
//
//  Created by Codex on 2026/2/9.
//

import Foundation

struct LLMClaudeRequest: Codable {
    let model: String
    let messages: [LLMClaudeMessage]
    let system: [LLMClaudeSystem]?
    let maxTokens: Int?
    let stopSequences: [String]?
    let stream: Bool?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let tools: [LLMClaudeTool]?
    let toolChoice: LLMClaudeToolChoice?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case system
        case maxTokens = "max_tokens"
        case stopSequences = "stop_sequences"
        case stream
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case tools
        case toolChoice = "tool_choice"
    }
}

struct LLMClaudeSystem: Codable {
    let type: String?
    let text: String?
}

struct LLMClaudeMessage: Codable {
    let role: String
    let content: [LLMClaudeContent]
}

struct LLMClaudeContent: Codable {
    let type: String
    let text: String?
    let source: LLMClaudeImageSource?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
    let toolUseId: String?
    let isError: Bool?
    let content: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, content
        case toolUseId = "tool_use_id"
        case isError = "is_error"
    }
}

struct LLMClaudeImageSource: Codable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

struct LLMClaudeTool: Codable {
    let name: String
    let description: String?
    let inputSchema: LLMCodexToolParameterModel // Reusing existing model if compatible

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
    
    func toPrompt() -> String {
        var ret = "<tool><name>\(name)</name>"
        if let description {
            ret += "<description>\(description)</description>"
        }
        if let data = try? JSONEncoder().encode(inputSchema), let schema = String(data: data, encoding: .utf8) {
            ret += "<arguments>\(schema)</arguments>"
        }
        ret += "</tool>"
        
        return ret
    }
}

struct LLMClaudeToolChoice: Codable {
    let type: String
    let name: String?
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let arrayVal = value as? [Any] {
            try container.encode(arrayVal.map { AnyCodable($0) })
        } else if let dictVal = value as? [String: Any] {
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}
