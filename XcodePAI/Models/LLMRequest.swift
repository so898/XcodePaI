//
//  LLMRequest.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

class LLMRequest {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
    let streamOptions: LLMStreamOption?
    let tools: [LLMTool]?
    
    // LLM Parameters
    let seed: Int?
    let maxTokens: Int?
    let temperature: Float?
    let topP: Float?
    
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
    
    init(dict: [String: Any]) {
        if let model = dict["model"] as? String {
            self.model = model
        } else {
            fatalError("LLM request model could not be properly parsered.")
        }
        
        if let messages = dict["messages"] as? [[String: Any]] {
            var parseredMessages = [LLMMessage]()
            for message in messages {
                parseredMessages.append(LLMMessage(dict: message))
            }
            self.messages = parseredMessages
        } else {
            fatalError("LLM request messages could not be properly parsered.")
        }
        
        if let stream = dict["stream"] as? Bool {
            self.stream = stream
        } else {
            self.stream = false
        }
        
        if let streamOptions = dict["stream_options"] as? [String: Any],
           let includeUsage = streamOptions["include_usage"] as? Bool {
            self.streamOptions = LLMStreamOption(includeUsage: includeUsage)
        } else {
            self.streamOptions = nil
        }
        
        if let tools = dict["tools"] as? [[String: Any]] {
            var parseredTools = [LLMTool]()
            for tool in tools {
                parseredTools.append(LLMTool(dict: tool))
            }
            self.tools = parseredTools
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
        
        if let tools = tools, tools.count > 0 {
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

enum LLMMessageType {
    case content
    case mutipleContent
    case toolCall
}

class LLMMessage {
    let role: String
    let name: String?
    var type: LLMMessageType = .content
    
    // Content
    let content: String?
    
    // Mutiple Content
    let contents: [LLMMessageContent]?
    
    // Tool Calls
    let toolCalls: [LLMMessageToolCall]?
    
    init(role: String, name: String? = nil, content: String? = nil, contents: [LLMMessageContent]? = nil, toolCalls: [LLMMessageToolCall]? = nil) {
        self.role = role
        self.name = name
        self.content = content
        self.contents = contents
        self.toolCalls = toolCalls
        
        guard content != nil || contents != nil || toolCalls != nil else {
            fatalError("LLM message could not be properly parsered.")
        }
        
        if content != nil {
            self.type = .content
        }
        
        if contents != nil {
            self.type = .mutipleContent
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
        self.type = .mutipleContent
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
    
    init(dict: [String: Any]) {
        if let role = dict["role"] as? String {
            self.role = role
        } else {
            fatalError("LLM message role could not be properly parsered.")
        }
        
        self.name = dict["name"] as? String
        
        if let content = dict["content"] as? String {
            self.type = .content
            self.content = content
            self.contents = nil
            self.toolCalls = nil
        } else if let contents = dict["content"] as? [[String: Any]] {
            self.type = .mutipleContent
            var parseredContents = [LLMMessageContent]()
            for content in contents {
                parseredContents.append(LLMMessageContent(dict: content))
            }
            self.contents = parseredContents
            self.content = nil
            self.toolCalls = nil
        } else if let toolCalls = dict["tools_calls"] as? [[String: Any]] {
            self.type = .toolCall
            var parseredToolCalls = [LLMMessageToolCall]()
            for toolCall in toolCalls {
                parseredToolCalls.append(LLMMessageToolCall(dict: toolCall))
            }
            self.toolCalls = parseredToolCalls
            self.content = nil
            self.contents = nil
        } else {
            fatalError("LLM message could not be properly parsered.")
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["role": role]
        if let name = name {
            dict["name"] = name
        }
        switch type {
        case .content:
            if let content = content {
                dict["content"] = content
            }
        case .mutipleContent:
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

enum LLMMessageContentType{
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
    
    init(dict: [String: Any]) {
        if let type = dict["type"] as? String {
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
                fatalError("LLM message content type could not be properly parsered.")
            }
        } else {
            fatalError("LLM message content could not be properly parsered.")
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
    
    init(dict: [String: Any]) {
        if let id = dict["id"] as? String {
            self.id = id
        } else {
            fatalError("LLM message tool call id could not be properly parsered.")
        }
        
        if let type = dict["type"] as? String {
            self.type = type
        } else {
            fatalError("LLM message tool call type could not be properly parsered.")
        }
        
        if let function = dict["function"] as? [String: Any], let functionName = function["name"] as? String {
            self.function = LLMFunction(name: functionName, description: function["description"] as? String, parameters: function["parameters"] as? String)
        } else {
            fatalError("LLM message tool call function could not be properly parsered.")
        }
    }
    
    func toDictionary() -> [String: Any] {
        return ["id": id, "type": type, "function": function.toDictionary()]
    }
}

class LLMFunction {
    let name: String
    let description: String?
    let parameters: String?
    
    init(name: String, description: String? = nil, parameters: String? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
    
    func toDictionary() -> [String: Any] {
        var dict = ["name": name]
        if let description = description {
            dict["description"] = description
        }
        if let parameters = parameters {
            dict["parameters"] = parameters
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
    
    init(dict: [String: Any]) {
        if let type = dict["type"] as? String {
            self.type = type
        } else {
            fatalError("LLM tool type could not be properly parsered.")
        }
        
        if let function = dict["function"] as? [String: Any], let functionName = function["name"] as? String {
            self.function = LLMFunction(name: functionName, description: function["description"] as? String, parameters: function["parameters"] as? String)
        } else {
            fatalError("LLM tool function could not be properly parsered.")
        }
    }
    
    func toDictionary() -> [String: Any] {
        return ["type": type, "function": function.toDictionary()]
    }
}
