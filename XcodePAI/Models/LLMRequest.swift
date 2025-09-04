//
//  LLMRequest.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMRequest {
    var model: String
    var messages: [LLMMessage]
    var stream: Bool
    var streamOptions: LLMStreamOption?
    var tools: [LLMTool]?
    
    // LLM Parameters
    var seed: Int?
    var maxTokens: Int?
    var temperature: Float?
    var topP: Float?
    
    init(model: String, messages: [LLMMessage], stream: Bool = true, usage: Bool = false, tools: [LLMTool]? = nil, seed: Int? = nil, maxTokens: Int? = nil, temperature: Float? = nil, topP: Float? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.streamOptions = usage ? LLMStreamOption(includeUsage: true) : nil
        self.tools = tools
        self.seed = seed
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }
    
    init(dict: [String: Any]) throws {
        guard let model = dict["model"] as? String else {
            throw LLMRequestError.invalidModel
        }
        self.model = model
        
        guard let messages = dict["messages"] as? [[String: Any]] else {
            throw LLMRequestError.invalidMessages
        }
        
        var parsedMessages = [LLMMessage]()
        for message in messages {
            parsedMessages.append(try LLMMessage(dict: message))
        }
        self.messages = parsedMessages
        
        self.stream = dict["stream"] as? Bool ?? false
        
        if let streamOptions = dict["stream_options"] as? [String: Any],
           let includeUsage = streamOptions["include_usage"] as? Bool {
            self.streamOptions = LLMStreamOption(includeUsage: includeUsage)
        } else {
            self.streamOptions = nil
        }
        
        if let tools = dict["tools"] as? [[String: Any]] {
            var parsedTools = [LLMTool]()
            for tool in tools {
                parsedTools.append(try LLMTool(dict: tool))
            }
            self.tools = parsedTools
        } else {
            self.tools = nil
        }
        
        self.seed = dict["seed"] as? Int
        self.maxTokens = dict["max_tokens"] as? Int
        self.temperature = dict["temperature"] as? Float
        self.topP = dict["top_p"] as? Float
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["model": model, "stream": stream]
        
        var messagesArray = [Any]()
        for message in messages {
            messagesArray.append(message.toDictionary())
        }
        dict["messages"] = messagesArray
        
        if let streamOptions = streamOptions {
            dict["stream_options"] = streamOptions.toDictionary()
        }
        
        if let tools = tools, !tools.isEmpty {
            var toolsArray = [Any]()
            for tool in tools {
                toolsArray.append(tool.toDictionary())
            }
            dict["tools"] = toolsArray
        }
        
        if let seed = seed {
            dict["seed"] = seed
        }
        
        if let maxTokens = maxTokens {
            dict["max_tokens"] = maxTokens
        }
        
        if let temperature = temperature {
            dict["temperature"] = temperature
        }
        
        if let topP = topP {
            dict["top_p"] = topP
        }
        
        return dict
    }
}

enum LLMRequestError: Error, LocalizedError {
    case invalidModel
    case invalidMessages
    case invalidMessageRole
    case invalidMessageContent
    case invalidToolType
    case invalidToolFunction
    case invalidToolCallId
    case invalidToolCallType
    case invalidToolCallFunction
    case invalidMessageContentType
    
    var errorDescription: String? {
        switch self {
        case .invalidModel:
            return "LLM request model could not be properly parsed."
        case .invalidMessages:
            return "LLM request messages could not be properly parsed."
        case .invalidMessageRole:
            return "LLM message role could not be properly parsed."
        case .invalidMessageContent:
            return "LLM message could not be properly parsed."
        case .invalidToolType:
            return "LLM tool type could not be properly parsed."
        case .invalidToolFunction:
            return "LLM tool function could not be properly parsed."
        case .invalidToolCallId:
            return "LLM message tool call id could not be properly parsed."
        case .invalidToolCallType:
            return "LLM message tool call type could not be properly parsed."
        case .invalidToolCallFunction:
            return "LLM message tool call function could not be properly parsed."
        case .invalidMessageContentType:
            return "LLM message content could not be properly parsed."
        }
    }
}

enum LLMMessageType {
    case content
    case multipleContent
    case toolCall
}

class LLMMessage {
    let role: String
    let name: String?
    var type: LLMMessageType = .content
    var partial: Bool = false
    
    // Content
    let content: String?
    
    // Multiple Content
    let contents: [LLMMessageContent]?
    
    // Tool Calls
    let toolCalls: [LLMMessageToolCall]?

    var tool_call_id: String?
    
    init(role: String, name: String? = nil, content: String? = nil, contents: [LLMMessageContent]? = nil, toolCalls: [LLMMessageToolCall]? = nil, partial: Bool = false) throws {
        self.role = role
        self.name = name
        self.content = content
        self.contents = contents
        self.toolCalls = toolCalls
        self.partial = partial
        
        guard content != nil || contents != nil || toolCalls != nil else {
            throw LLMRequestError.invalidMessageContent
        }
        
        if content != nil {
            self.type = .content
        }
        
        if contents != nil {
            self.type = .multipleContent
        }
        
        if toolCalls != nil {
            self.type = .toolCall
        }
    }
    
    init(role: String, name: String? = nil, content: String) {
        self.role = role
        self.name = name
        self.type = .content
        self.content = content
        self.contents = nil
        self.toolCalls = nil
    }
    
    init(role: String, name: String? = nil, contents: [LLMMessageContent]) {
        self.role = role
        self.name = name
        self.type = .multipleContent
        self.content = nil
        self.contents = contents
        self.toolCalls = nil
    }
    
    init(role: String, name: String? = nil, toolCalls: [LLMMessageToolCall]) {
        self.role = role
        self.name = name
        self.type = .toolCall
        self.content = nil
        self.contents = nil
        self.toolCalls = toolCalls
    }

    init(toolCallId: String, functionName: String, content: String) {
        self.type = .content
        self.role = "tool"
        self.name = functionName
        self.tool_call_id = toolCallId
        self.content = content
        self.contents = nil
        self.toolCalls = nil
    }
    
    init(dict: [String: Any]) throws {
        guard let role = dict["role"] as? String else {
            throw LLMRequestError.invalidMessageRole
        }
        self.role = role
        
        self.name = dict["name"] as? String

        self.tool_call_id = dict["tool_call_id"] as? String
        
        self.partial = dict["partial"] as? Bool ?? false
        
        if let content = dict["content"] as? String {
            self.type = .content
            self.content = content
            self.contents = nil
            self.toolCalls = nil
        } else if let contents = dict["content"] as? [[String: Any]] {
            self.type = .multipleContent
            var parsedContents = [LLMMessageContent]()
            for content in contents {
                parsedContents.append(try LLMMessageContent(dict: content))
            }
            self.contents = parsedContents
            self.content = nil
            self.toolCalls = nil
        } else if let toolCalls = dict["tool_calls"] as? [[String: Any]] { // Fixed typo: tools_calls -> tool_calls
            self.type = .toolCall
            var parsedToolCalls = [LLMMessageToolCall]()
            for toolCall in toolCalls {
                parsedToolCalls.append(try LLMMessageToolCall(dict: toolCall))
            }
            self.toolCalls = parsedToolCalls
            self.content = nil
            self.contents = nil
        } else {
            throw LLMRequestError.invalidMessageContent
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["role": role]
        if let name = name {
            dict["name"] = name
        }
        if let tool_call_id = tool_call_id {
            dict["tool_call_id"] = tool_call_id
        }
        if partial {
            dict["partial"] = true
        }
        switch type {
        case .content:
            if let content = content {
                dict["content"] = content
            }
        case .multipleContent:
            if let contents = contents {
                var contentsArray = [Any]()
                for content in contents {
                    contentsArray.append(content.toDictionary())
                }
                dict["content"] = contentsArray
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

enum LLMMessageContentType {
    case text
    case imageUrl
}

class LLMMessageContent {
    let type: LLMMessageContentType
    let text: String?
    let imageUrl: LLMMessageContentImageUrl?
    
    init(text: String) {
        self.type = .text
        self.text = text
        self.imageUrl = nil
    }
    
    init(imageUrl: String) {
        self.type = .imageUrl
        self.text = nil
        self.imageUrl = LLMMessageContentImageUrl(url: imageUrl)
    }
    
    init(dict: [String: Any]) throws {
        guard let type = dict["type"] as? String else {
            throw LLMRequestError.invalidMessageContentType
        }
        
        if type == "text", let text = dict["text"] as? String {
            self.type = .text
            self.text = text
            self.imageUrl = nil
        } else if type == "image_url",
                  let imageUrl = dict["image_url"] as? [String: Any],
                  let url = imageUrl["url"] as? String {
            self.type = .imageUrl
            self.text = nil
            self.imageUrl = LLMMessageContentImageUrl(url: url)
        } else {
            throw LLMRequestError.invalidMessageContentType
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        switch type {
        case .text:
            dict["type"] = "text"
            if let text = text {
                dict["text"] = text
            }
        case .imageUrl:
            dict["type"] = "image_url"
            if let imageUrl = imageUrl {
                dict["image_url"] = imageUrl.toDictionary()
            }
        }
        return dict
    }
}

class LLMMessageContentImageUrl {
    let url: String
    
    init(url: String) {
        self.url = url
    }
    
    func toDictionary() -> [String: Any] {
        return ["url": url]
    }
}

class LLMMessageToolCall {
    let id: String
    let type: String
    let function: LLMFunction
    
    init(id: String, type: String, function: LLMFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
    
    init(dict: [String: Any]) throws {
        guard let id = dict["id"] as? String else {
            throw LLMRequestError.invalidToolCallId
        }
        self.id = id
        
        guard let type = dict["type"] as? String else {
            throw LLMRequestError.invalidToolCallType
        }
        self.type = type
        
        guard let function = dict["function"] as? [String: Any] else {
            throw LLMRequestError.invalidToolCallFunction
        }
        self.function = LLMFunction(
            name: function["name"] as? String,
            description: function["description"] as? String,
            parameters: function["parameters"] as? String,
            arguments: function["arguments"] as? String
        )
    }
    
    func toDictionary() -> [String: Any] {
        return ["id": id, "type": type, "function": function.toDictionary()]
    }
}

class LLMFunction {
    let name: String?
    let description: String?
    let parameters: String?
    let arguments: String?
    
    init(name: String? = nil, description: String? = nil, parameters: String? = nil, arguments: String? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.arguments = arguments
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [String: Any]()
        if let name = name {
            dict["name"] = name
        }
        if let description = description {
            dict["description"] = description
        }
        if let parameters = parameters {
            dict["parameters"] = parameters
        }
        if let arguments = arguments {
            dict["arguments"] = arguments
        }
        return dict
    }
}

class LLMStreamOption {
    let includeUsage: Bool
    
    init(includeUsage: Bool) {
        self.includeUsage = includeUsage
    }
    
    func toDictionary() -> [String: Any] {
        return ["include_usage": includeUsage]
    }
}

class LLMTool {
    let type: String
    let function: LLMFunction
    
    init(type: String, function: LLMFunction) {
        self.type = type
        self.function = function
    }
    
    init(dict: [String: Any]) throws {
        guard let type = dict["type"] as? String else {
            throw LLMRequestError.invalidToolType
        }
        self.type = type
        
        guard let function = dict["function"] as? [String: Any] else {
            throw LLMRequestError.invalidToolFunction
        }
        
        guard let functionName = function["name"] as? String else {
            throw LLMRequestError.invalidToolFunction
        }
        
        self.function = LLMFunction(
            name: functionName,
            description: function["description"] as? String,
            parameters: function["parameters"] as? String
        )
    }
    
    func toDictionary() -> [String: Any] {
        return ["type": type, "function": function.toDictionary()]
    }
}
