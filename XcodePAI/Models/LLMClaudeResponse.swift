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
}

struct LLMClaudeContentBlockResponse: Codable {
    let type: String // text, tool_use
    let text: String?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
}

struct LLMClaudeDeltaResponse: Codable {
    let type: String // text_delta, input_json_delta
    let text: String?
    let partialJson: String?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case partialJson = "partial_json"
    }
}

struct LLMClaudeMessageDeltaResponse: Codable {
    let stopReason: String?
    let stopSequence: String?
    
    enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct LLMClaudeUsageResponse: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct LLMClaudeErrorResponse: Codable {
    let type: String
    let message: String
}
