//
//  LLMResponse.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMResponse {
    let id: String
    let model: String
    let object: String
    let created: Int
    let systemFingerprint: String?
    
    let choices: [LLMResponseChoice]
    
    let usage: LLMResponseUsage?
    
    init(id: String, model: String, object: String, created: Int = Date.currentTimeStamp(), systemFingerprint: String? = nil, choices: [LLMResponseChoice] = [], usage: LLMResponseUsage? = nil) {
        self.id = id
        self.model = model
        self.object = object
        self.created = created
        self.systemFingerprint = systemFingerprint
        self.choices = choices
        self.usage = usage
    }
    
    init(dict: [String: Any]) {
        if let id = dict["id"] as? String {
            self.id = id
        } else {
            fatalError("LLM response id could not be properly parsered.")
        }
        
        if let model = dict["model"] as? String {
            self.model = model
        } else {
            fatalError("LLM response model could not be properly parsered.")
        }
        
        if let object = dict["object"] as? String {
            self.object = object
        } else {
            fatalError("LLM response object could not be properly parsered.")
        }
        
        if let created = dict["created"] as? Int {
            self.created = created
        } else {
            fatalError("LLM response created could not be properly parsered.")
        }
        
        self.systemFingerprint = dict["system_fingerprint"] as? String
        
        if let choices = dict["choices"] as? [[String: Any]] {
            var parseredChoicesArray = [LLMResponseChoice]()
            for choice in choices {
                parseredChoicesArray.append(LLMResponseChoice(dict: choice))
            }
            self.choices = parseredChoicesArray
        } else {
            fatalError("LLM response choices could not be properly parsered.")
        }
        
        if let usage = dict["usage"] as? [String: Any] {
            self.usage = LLMResponseUsage(dict: usage)
        } else {
            self.usage = nil
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["id": id, "model": model, "object": object, "created": created]
        if let systemFingerprint = systemFingerprint {
            dict["system_fingerprint"] = systemFingerprint
        }
        
        var choicesArray = [Any]()
        for choice in choices {
            choicesArray.append(choice.toDictionary())
        }
        dict["choices"] = choicesArray
        
        if let usage = usage {
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
    
    init(dict: [String: Any]) {
        if let index = dict["index"] as? Int {
            self.index = index
        } else {
            fatalError("LLM choice could not be properly parsered.")
        }
        
        self.finishReason = dict["finish_reason"] as? String
        
        // Some API return this value with `message` key
        // maybe compatible with it later
        if let delta = dict["delta"] as? [String: Any] {
            self.isFullMessage = false
            self.message = LLMResponseChoiceMessage(dict: delta)
        } else if let message = dict["message"] as? [String: Any] {
            self.isFullMessage = true
            self.message = LLMResponseChoiceMessage(dict: message)
        }else {
            fatalError("LLM choice could not be properly parsered.")
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["index": index]
        if isFullMessage {
            dict["message"] = message.toDictionary()
        } else {
            dict["delta"] = message.toDictionary()
        }
        if let finishReason = finishReason {
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
    
    let type: LLMResponseChoiceMessageType
    
    let content: String?
    let toolCallId: String?
    
    let toolCalls: [LLMMessageToolCall]?
    
    init(role: String?, type: LLMResponseChoiceMessageType = .content, content: String? = nil, toolCallId: String? = nil, toolCalls: [LLMMessageToolCall]? = nil) {
        self.role = role
        self.type = type
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
    
    init(role: String, content: String? = nil, toolCallId: String? = nil) {
        self.role = role
        self.type = .content
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }
    
    init(role: String, content: String) {
        self.role = role
        self.type = .content
        self.content = content
        self.toolCallId = nil
        self.toolCalls = nil
    }
    
    init(role: String, toolCallId: String) {
        self.role = role
        self.type = .content
        self.content = nil
        self.toolCallId = toolCallId
        self.toolCalls = nil
    }
    
    init(role: String, toolCalls: [LLMMessageToolCall]) {
        self.role = role
        self.type = .toolCall
        self.content = nil
        self.toolCallId = nil
        self.toolCalls = toolCalls
    }
    
    init(content: String) {
        self.role = nil
        self.type = .content
        self.content = content
        self.toolCallId = nil
        self.toolCalls = nil
    }
    
    init(dict: [String: Any]) {
        self.role = dict["role"] as? String
        
        if let content = dict["content"] as? String {
            self.type = .content
            self.content = content
            if let toolCallId = dict["tool_call_id"] as? String {
                self.toolCallId = toolCallId
            } else {
                self.toolCallId = nil
            }
            self.toolCalls = nil
        } else if let toolCallId = dict["tool_call_id"] as? String {
            self.type = .content
            self.toolCallId = toolCallId
            self.content = nil
            self.toolCalls = nil
        } else if let toolCalls = dict["tool_calls"] as? [[String: Any]] {
            self.type = .toolCall
            var parseredToolCalls = [LLMMessageToolCall]()
            for toolCall in toolCalls {
                parseredToolCalls.append(LLMMessageToolCall(dict: toolCall))
            }
            self.toolCalls = parseredToolCalls
            self.content = nil
            self.toolCallId = nil
        } else {
            self.type = .empty
            self.content = nil
            self.toolCallId = nil
            self.toolCalls = nil
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        if let role = role {
            dict["role"] = role
        }

        switch type {
        case .empty: break
        case .content:
            if let content = content {
                dict["content"] = content
            }
            if let toolCallId = toolCallId {
                dict["content"] = toolCallId
            }
        case .toolCall:
            if let toolCalls = toolCalls {
                var toolCallsArray = [Any]()
                for toolCall in toolCalls {
                    toolCallsArray.append(toolCall.toDictionary())
                }
                dict["tool_calls"] = toolCallsArray
            }
        }
        return dict
    }
}

class LLMResponseUsage {
    let comletionTokens: Int?
    let promptTokens: Int?
    let totalTokens: Int?
    
    init(comletionTokens: Int?, promptTokens: Int?, totalTokens: Int?) {
        self.comletionTokens = comletionTokens
        self.promptTokens = promptTokens
        self.totalTokens = totalTokens
    }
    
    init(dict: [String: Any]) {
        self.comletionTokens = dict["completion_tokens"] as? Int
        self.promptTokens = dict["prompt_tokens"] as? Int
        self.totalTokens = dict["total_tokens"] as? Int
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        if let comletionTokens = comletionTokens {
            dict["completion_tokens"] = comletionTokens
        }
        if let promptTokens = promptTokens {
            dict["prompt_tokens"] = promptTokens
        }
        if let totalTokens = totalTokens {
            dict["total_tokens"] = totalTokens
        }
        return dict
    }
}
