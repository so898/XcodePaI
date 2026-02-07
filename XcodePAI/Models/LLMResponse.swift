//
//  LLMResponse.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

enum LLMResponseError: Error, LocalizedError {
    case invalidChoices
    case invalidChoice
    
    var errorDescription: String? {
        switch self {
        case .invalidChoices:
            return "LLM response choices could not be properly parsed."
        case .invalidChoice:
            return "LLM choice could not be properly parsed."
        }
    }
}

class LLMResponse {
    let id: String?
    let model: String?
    let object: String?
    let created: Int?
    let systemFingerprint: String?
    
    let choices: [LLMResponseChoice]
    
    let usage: LLMResponseUsage?
    
    init(id: String, model: String? = nil, object: String, created: Int = Date.currentTimeStamp(), systemFingerprint: String? = nil, choices: [LLMResponseChoice] = [], usage: LLMResponseUsage? = nil) {
        self.id = id
        self.model = model
        self.object = object
        self.created = created
        self.systemFingerprint = systemFingerprint
        self.choices = choices
        self.usage = usage
    }
    
    init(dict: [String: Any]) throws {
        self.id = dict["id"] as? String
        self.model = dict["model"] as? String
        self.object = dict["object"] as? String
        self.created = dict["created"] as? Int
        self.systemFingerprint = dict["system_fingerprint"] as? String
        
        if let choices = dict["choices"] as? [[String: Any]] {
            var parsedChoicesArray = [LLMResponseChoice]()
            for choice in choices {
                try parsedChoicesArray.append(LLMResponseChoice(dict: choice))
            }
            self.choices = parsedChoicesArray
        } else {
            throw LLMResponseError.invalidChoices
        }
        
        if let usage = dict["usage"] as? [String: Any] {
            self.usage = try LLMResponseUsage(dict: usage)
        } else {
            self.usage = nil
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        if let id {
            dict["id"] = id
        }
        
        if let object {
            dict["object"] = object
        }

        if let model {
            dict["model"] = model
        }
        
        if let created {
            dict["created"] = created
        }

        if let systemFingerprint {
            dict["system_fingerprint"] = systemFingerprint
        }
        
        var choicesArray = [Any]()
        for choice in choices {
            choicesArray.append(choice.toDictionary())
        }
        dict["choices"] = choicesArray
        
        if let usage {
            dict["usage"] = usage.toDictionary()
        }
        return dict
    }
}

class LLMResponseChoice {
    let index: Int
    let finishReason: String?
    let isFullMessage: Bool
    let message: LLMResponseChoiceMessage
    
    init(index: Int, finishReason: String? = nil, isFullMessage: Bool = true, message: LLMResponseChoiceMessage = LLMResponseChoiceMessage(content: "")) {
        self.index = index
        self.finishReason = finishReason
        self.isFullMessage = isFullMessage
        self.message = message
    }
    
    init(dict: [String: Any]) throws {
        if let index = dict["index"] as? Int {
            self.index = index
        } else {
            throw LLMResponseError.invalidChoice
        }
        
        self.finishReason = dict["finish_reason"] as? String
        
        // Some API return this value with `message` key
        // maybe compatible with it later
        if let delta = dict["delta"] as? [String: Any] {
            self.isFullMessage = false
            self.message = try LLMResponseChoiceMessage(dict: delta)
        } else if let message = dict["message"] as? [String: Any] {
            self.isFullMessage = true
            self.message = try LLMResponseChoiceMessage(dict: message)
        } else {
            throw LLMResponseError.invalidChoice
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["index": index]
        if isFullMessage {
            dict["message"] = message.toDictionary()
        } else {
            dict["delta"] = message.toDictionary()
        }
        if let finishReason {
            dict["finish_reason"] = finishReason
        }
        return dict
    }
}

enum LLMResponseChoiceMessageType {
    case empty
    case content
    case toolCall
}

class LLMResponseChoiceMessage {
    let role: String?
        
    let content: String?
    let reasoningContent: String?
    let toolCallId: String?
    
    let toolCalls: [LLMMessageToolCall]?
    
    init(role: String?, type: LLMResponseChoiceMessageType = .content, content: String? = nil, reasoningContent: String? = nil, toolCallId: String? = nil, toolCalls: [LLMMessageToolCall]? = nil) {
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
    
    init(role: String, content: String? = nil, reasoningContent: String? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }
    
    init(role: String, content: String, reasoningContent: String? = nil) {
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.toolCallId = nil
        self.toolCalls = nil
    }
    
    init(role: String, toolCallId: String) {
        self.role = role
        self.content = nil
        self.reasoningContent = nil
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }
    
    init(role: String, toolCalls: [LLMMessageToolCall]) {
        self.role = role
        self.content = nil
        self.reasoningContent = nil
        self.toolCallId = nil
        self.toolCalls = toolCalls
    }
    
    init(content: String) {
        self.role = nil
        self.content = content
        self.reasoningContent = nil
        self.toolCallId = nil
        self.toolCalls = nil
    }
    
    init(dict: [String: Any]) throws {
        self.role = dict["role"] as? String
        
        var thisContent: String? = nil
        var thisReasoningContent: String? = nil
        var thisToolCallId: String? = nil
        var thisToolCalls: [LLMMessageToolCall]? = nil
        
        if let content = dict["content"] as? String {
            thisContent = content
            if let reasoningContent = dict["reasoning_content"] as? String {
                thisReasoningContent = reasoningContent
            }
        }
        if let reasoningContent = dict["reasoning_content"] as? String {
            thisReasoningContent = reasoningContent
            
        }
        if let toolCallId = dict["tool_call_id"] as? String {
            thisToolCallId = toolCallId
        }
        if let toolCalls = dict["tool_calls"] as? [[String: Any]] {
            var parsedToolCalls = [LLMMessageToolCall]()
            for toolCall in toolCalls {
                try parsedToolCalls.append(LLMMessageToolCall(dict: toolCall))
            }
            thisToolCalls = parsedToolCalls
        }
        
        self.content = thisContent
        self.reasoningContent = thisReasoningContent
        self.toolCallId = thisToolCallId
        self.toolCalls = thisToolCalls
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        if let role = role {
            dict["role"] = role
        }

        if let content {
            dict["content"] = content
        }
        if let reasoningContent {
            dict["reasoning_content"] = reasoningContent
        }
        if let toolCallId {
            dict["tool_call_id"] = toolCallId
        }
        if let toolCalls {
            var toolCallsArray = [Any]()
            for toolCall in toolCalls {
                toolCallsArray.append(toolCall.toDictionary())
            }
            dict["tool_calls"] = toolCallsArray
        }
        
        return dict
    }
}

class LLMResponseUsage {
    let completionTokens: Int?
    let promptTokens: Int?
    let totalTokens: Int?
    
    init(completionTokens: Int?, promptTokens: Int?, totalTokens: Int?) {
        self.completionTokens = completionTokens
        self.promptTokens = promptTokens
        self.totalTokens = totalTokens
    }
    
    init(dict: [String: Any]) throws {
        self.completionTokens = dict["completion_tokens"] as? Int
        self.promptTokens = dict["prompt_tokens"] as? Int
        self.totalTokens = dict["total_tokens"] as? Int
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        if let completionTokens {
            dict["completion_tokens"] = completionTokens
        }
        if let promptTokens {
            dict["prompt_tokens"] = promptTokens
        }
        if let totalTokens {
            dict["total_tokens"] = totalTokens
        }
        return dict
    }
}
