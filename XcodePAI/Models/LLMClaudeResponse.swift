//
//  LLMClaudeResponse.swift
//  XcodePAI
//
//  Created by Codex on 2026/2/9.
//

import Foundation

enum LLMClaudeResponseEvent: Codable {
    case messageStart(MessageStartEvent)
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop(ContentBlockStopEvent)
    case messageDelta(MessageDeltaEvent)
    case messageStop(MessageStopEvent)
    case ping(PingEvent)
    case error(ErrorEvent)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "message_start":
            self = .messageStart(try MessageStartEvent(from: decoder))
        case "content_block_start":
            self = .contentBlockStart(try ContentBlockStartEvent(from: decoder))
        case "content_block_delta":
            self = .contentBlockDelta(try ContentBlockDeltaEvent(from: decoder))
        case "content_block_stop":
            self = .contentBlockStop(try ContentBlockStopEvent(from: decoder))
        case "message_delta":
            self = .messageDelta(try MessageDeltaEvent(from: decoder))
        case "message_stop":
            self = .messageStop(try MessageStopEvent(from: decoder))
        case "ping":
            self = .ping(try PingEvent(from: decoder))
        case "error":
            self = .error(try ErrorEvent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .messageStart(let event): try event.encode(to: encoder)
        case .contentBlockStart(let event): try event.encode(to: encoder)
        case .contentBlockDelta(let event): try event.encode(to: encoder)
        case .contentBlockStop(let event): try event.encode(to: encoder)
        case .messageDelta(let event): try event.encode(to: encoder)
        case .messageStop(let event): try event.encode(to: encoder)
        case .ping(let event): try event.encode(to: encoder)
        case .error(let event): try event.encode(to: encoder)
        }
    }
}

struct MessageStartEvent: Codable {
    let type: String = "message_start"
    let message: LLMClaudeMessageResponse
}

struct ContentBlockStartEvent: Codable {
    let type: String = "content_block_start"
    let index: Int
    let contentBlock: LLMClaudeContentBlockResponse
    
    enum CodingKeys: String, CodingKey {
        case type, index
        case contentBlock = "content_block"
    }
}

struct ContentBlockDeltaEvent: Codable {
    let type: String = "content_block_delta"
    let index: Int
    let delta: LLMClaudeDeltaResponse
}

struct ContentBlockStopEvent: Codable {
    let type: String = "content_block_stop"
    let index: Int
}

struct MessageDeltaEvent: Codable {
    let type: String = "message_delta"
    let delta: LLMClaudeMessageDeltaResponse
    let usage: LLMClaudeUsageResponse
}

struct MessageStopEvent: Codable {
    let type: String = "message_stop"
}

struct PingEvent: Codable {
    let type: String = "ping"
}

struct ErrorEvent: Codable {
    let type: String = "error"
    let error: LLMClaudeErrorResponse
}

// Supporting structures

struct LLMClaudeMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [LLMClaudeContentBlockResponse]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: LLMClaudeUsageResponse
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
    
    // Custom encoding to ensure stop_reason and stop_sequence are always encoded
    // even when nil (as JSON null), since Claude API requires these fields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(model, forKey: .model)
        try container.encode(stopReason, forKey: .stopReason)  // Encodes null if nil
        try container.encode(stopSequence, forKey: .stopSequence)  // Encodes null if nil
        try container.encode(usage, forKey: .usage)
    }
}

struct LLMClaudeContentBlockResponse: Codable {
    let type: String // text, tool_use, thinking
    let text: String?
    let thinking: String?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case type, text, thinking, id, name, input
    }
    
    // Custom encoding to skip nil values
    // Claude API expects different fields for different content block types:
    // - text: { "type": "text", "text": "..." }
    // - thinking: { "type": "thinking", "thinking": "..." }
    // - tool_use: { "type": "tool_use", "id": "...", "name": "...", "input": {} }
    //   NOTE: input MUST be an empty object {} in streaming content_block_start
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(thinking, forKey: .thinking)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(input, forKey: .input)
    }
}

struct LLMClaudeDeltaResponse: Codable {
    let type: String // text_delta, input_json_delta, thinking_delta
    let text: String?
    let thinking: String?
    let partialJson: String?
    
    enum CodingKeys: String, CodingKey {
        case type, text, thinking
        case partialJson = "partial_json"
    }
    
    // Custom encoding to skip nil values
    // Claude API expects different fields for different delta types:
    // - text_delta: { "type": "text_delta", "text": "..." }
    // - thinking_delta: { "type": "thinking_delta", "thinking": "..." }
    // - input_json_delta: { "type": "input_json_delta", "partial_json": "..." }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(thinking, forKey: .thinking)
        try container.encodeIfPresent(partialJson, forKey: .partialJson)
    }
}

struct LLMClaudeMessageDeltaResponse: Codable {
    let stopReason: String?
    let stopSequence: String?
    
    enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
    
    // Custom encoding to ensure stop_sequence is always encoded even when nil
    // Claude API expects stop_sequence field to be present (as null)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stopReason, forKey: .stopReason)  // Encodes null if nil
        try container.encode(stopSequence, forKey: .stopSequence)  // Encodes null if nil
    }
}

struct LLMClaudeUsageResponse: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct LLMClaudeErrorResponse: Codable {
    let type: String
    let message: String
}
