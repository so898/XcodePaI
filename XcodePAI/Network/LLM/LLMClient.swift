//
//  LLMClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import EventSource
import Combine
import Logger

protocol LLMClientDelegate {
    func clientConnected(_ client: LLMClient)
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage)
    func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage)
    func client(_ client: LLMClient, receiveError error: Error?)
}

class LLMAssistantMessage {
    let reason: String?
    let isReasonComplete: Bool
    
    let content: String?
    
    let tools: [LLMMessageToolCall]?
    
    let finishReason: String?
    
    init(reason: String? = nil, isReasonComplete: Bool = false, content: String? = nil, tools: [LLMMessageToolCall]? = nil, finishReason: String? = nil) {
        self.reason = reason
        self.isReasonComplete = isReasonComplete
        self.content = content
        self.tools = tools
        self.finishReason = finishReason
    }
}

class LLMClient {
    
    private let provider: LLMModelProvider
    private var delegate: LLMClientDelegate?
    
    private var request: LLMRequest?
    private var tokenUsage: LLMResponseUsage?
    
    private var eventSource: EventSource?
    var cancellable: Cancellable?
    
    init(_ provider: LLMModelProvider, delegate: LLMClientDelegate) {
        self.provider = provider
        self.delegate = delegate
    }
    
    private var requestTools = [LLMMessageToolCall]()
    
    func request(_ request: LLMRequest) {
        self.request = request
        
        guard let data = try? JSONSerialization.data(withJSONObject: request.toDictionary()) else {
            return
        }
        
        for message in request.messages {
            if let toolCalls = message.toolCalls {
                requestTools.append(contentsOf: toolCalls)
            }
        }
        
        guard let url = URL(string: provider.chatCompletionsUrl()) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        provider.requestHeaders().forEach { key, value in
            if let value = value as? String {
                request.addValue(value, forHTTPHeaderField: key)
            } else if let value = value as? Int {
                request.addValue(String(value), forHTTPHeaderField: key)
            } else if let value = value as? Double {
                request.addValue(String(value), forHTTPHeaderField: key)
            }
        }
        
        let client = EventSource(request: request)
        
        client.onOpen = { [weak self] in
            guard let `self` = self else { return }
            self.delegate?.clientConnected(self)
        }
        client.onMessage = { [weak self] event in
            guard let `self` = self else { return }
            self.receive(chunk: event.data)
        }
        client.onError = { [weak self] error in
            guard let `self` = self else { return }
            
            if let error {
                Logger.service.error("LLMCLient Reqeust: POST \(url.absoluteString)\nError: \(error.localizedDescription)")
            } else {
                // No error means request completed
                self.sendFullMessage()
            }
            
            self.delegate?.client(self, receiveError: error)
            Task {[weak self] in
                await client.close()
                self?.eventSource = nil
            }
        }
        self.eventSource = client
    }
    
    func stop() {
        delegate = nil
        Task {
            if let client = eventSource {
                await client.close()
            }
            eventSource = nil
        }
    }
    
    private var reason: String?
    private var isReasonComplete: Bool = false
    private var thinkTagComplete: Bool?
    private var content: String?
    
    private let toolCallExtractor = ToolCallExtractor()
    private var toolCallParts: [LLMMessageToolCall]?
    private var toolCalls: [LLMMessageToolCall]?
    
    private func sendFullMessage() {
        delegate?.client(self, receiveMessage: LLMAssistantMessage(reason: reason,
                                                                  isReasonComplete: true,
                                                                  content: content,
                                                                  tools: toolCalls))
        
        
        if let request, let tokenUsage {
            let requestString = {
                if let data = try? JSONSerialization.data(withJSONObject: request.toDictionary()) {
                    return String(data: data, encoding: .utf8) ?? ""
                }
                return ""
            }()
            let toolString = {
                if let toolCalls, let data = try? JSONSerialization.data(withJSONObject: toolCalls.map({$0.toDictionary()})) {
                    return String(data: data, encoding: .utf8) ?? ""
                }
                return ""
            }()
            RecordTracker.shared.recordTokenUsage(modelProvider: provider.name, modelName: request.model, inputTokens: tokenUsage.promptTokens ?? 0, outputTokens: tokenUsage.completionTokens ?? 0, metadata: ["request": requestString, "resp_content": (content ?? ""), "resp_reason": (reason ?? ""), "tool": toolString])
        }
    }
    
    private func processToolWithMessage(_ message: LLMResponseChoiceMessage) -> [LLMMessageToolCall]? {
        if let toolCalls = message.toolCalls {
            return toolCalls
        } else if let toolCallId = message.toolCallId, requestTools.count > 0 {
            for tool in requestTools {
                if tool.id == toolCallId {
                    return [tool]
                }
            }
        }
        return nil
    }
    
    private func processReasonAndContentWithMessage(_ message: LLMResponseChoiceMessage) -> (String?, String?) {
        if let reasoningContent = message.reasoningContent, !reasoningContent.isEmpty {
            isReasonComplete = false
        }
        var chunkReason: String?
        var chunkContent: String?
        
        var processContent = message.content
        if thinkTagComplete == nil, message.reasoningContent == nil {
            // First Message
            if let content = processContent, content.contains("<think>") {
                thinkTagComplete = false
                processContent = processContent?.replacingOccurrences(of: "<think>", with: "")
            } else {
                thinkTagComplete = true
                isReasonComplete = true
            }
        }
        if !isReasonComplete {
            if thinkTagComplete == false {
                if let content = processContent, content.contains("</think>") {
                    thinkTagComplete = true
                    
                    let comps = content.components(separatedBy: "</think>")
                    
                    guard comps.count == 2 else {
                        // Error
                        fatalError("Tag </think> parsering error")
                    }
                    
                    chunkReason = comps[0]
                    processContent = comps[1]
                    isReasonComplete = true
                } else if let content = processContent {
                    chunkReason = content
                    processContent = nil
                }
            } else if let reasoningContent = message.reasoningContent {
                chunkReason = reasoningContent
            } else {
                isReasonComplete = true
            }
        }
        
        if let processContent = processContent {
            chunkContent = processContent
        }
        
        return (chunkReason, chunkContent)
    }
    
    private func processToolCallPart() {
        guard let toolCallParts else {
            return
        }
        var id: String?
        var type: String?
        var functionName: String?
        var arguments: String?
        for toolCallPart in toolCallParts {
            if let name = toolCallPart.function.name, !name.isEmpty {
                if let functionName = functionName {
                    sendToolCall(LLMMessageToolCall(id: id ?? "", type: type ?? "function", function: LLMFunction(name: functionName, arguments: arguments)))
                }
                id = nil
                type = nil
                functionName = name
                arguments = nil
            }
            if !toolCallPart.id.isEmpty {
                if id == nil {
                    id = toolCallPart.id
                } else if id != toolCallPart.id {
                    id?.append(toolCallPart.id)
                }
            }
            if let args = toolCallPart.function.arguments {
                if arguments == nil {
                    arguments = args
                } else {
                    arguments?.append(args)
                }
            }
            if type == nil, !toolCallPart.type.isEmpty {
                type = toolCallPart.type
            }
        }
        
        if let functionName = functionName {
            sendToolCall(LLMMessageToolCall(id: id ?? "", type: type ?? "function", function: LLMFunction(name: functionName, arguments: arguments)))
        }
        
        self.toolCallParts?.removeAll()
    }
}

// MARK:  Event Source Functions
extension LLMClient {
    private func receive(chunk: String) {
        guard let data = chunk.data(using: .utf8), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let response = try? LLMResponse(dict: dict) else {
            return
        }
        
        var chunkReason: String?
        var chunkContent: String?
        var chunkTools: [LLMMessageToolCall]?
        var chunkFinishReason: String?
        
        for choice in response.choices {
            chunkFinishReason = choice.finishReason
            chunkTools = processToolWithMessage(choice.message)
            if choice.isFullMessage {
                let chunkRet = processReasonAndContentWithMessage(choice.message)
                reason = chunkRet.0
                content = chunkRet.1
                isReasonComplete = true
                
                if let reason {
                    sendReason(reason)
                }
                
                var toolCallsInsideContent = [LLMMessageToolCall]()
                if let content {
                    for contentAndToolCall in toolCallExtractor.processChunk(content) {
                        if let content = contentAndToolCall.before {
                            sendContent(content)
                        }
                        if let toolUse = contentAndToolCall.toolUse {
                            toolCallsInsideContent.append(toolUse)
                            sendToolCall(toolUse)
                        }
                    }
                    
                    if let finalizeContent = toolCallExtractor.resetBuffer(), !finalizeContent.isEmpty {
                        sendContent(finalizeContent)
                    }
                }
                
                if let chunkTools {
                    toolCallsInsideContent.append(contentsOf: chunkTools)
                    for toolCall in chunkTools {
                        sendToolCall(toolCall)
                    }
                }
                toolCalls = toolCallsInsideContent
                
                // Close client when full message received
                self.stop()
                return
            } else {
                let chunkRet = processReasonAndContentWithMessage(choice.message)
                
                if let reason = chunkRet.0 {
                    if let currentReason = chunkReason {
                        chunkReason = currentReason + reason
                    } else {
                        chunkReason = reason
                    }
                }
                
                if let content = chunkRet.1 {
                    if let currentContent = chunkContent {
                        chunkContent = currentContent + content
                    } else {
                        chunkContent = content
                    }
                }
            }
        }
        
        if let chunkReason = chunkReason, !chunkReason.isEmpty {
            if let reason = reason {
                self.reason = reason + chunkReason
            } else {
                reason = chunkReason
            }
            
            processToolCallPart()
            
            sendReason(chunkReason)
        }
        
        if let thisChunkContent = chunkContent, !thisChunkContent.isEmpty {
            if let content = content {
                self.content = content + thisChunkContent
            } else {
                content = thisChunkContent
            }
            
            processToolCallPart()
            
            for contentAndToolCall in toolCallExtractor.processChunk(thisChunkContent) {
                if let content = contentAndToolCall.before {
                    sendContent(content)
                }
                if let toolUse = contentAndToolCall.toolUse {
                    sendToolCall(toolUse)
                }
            }
        }
        
        if let chunkTools = chunkTools {
            if var tools = toolCallParts {
                tools.append(contentsOf: chunkTools)
                self.toolCallParts = tools
            } else {
                toolCallParts = chunkTools
            }
        }
        
        if var chunkFinishReason {
            processToolCallPart()
            
            if let finalizeContent = toolCallExtractor.resetBuffer(), !finalizeContent.isEmpty {
                sendContent(finalizeContent)
            }
            
            if let toolCalls, !toolCalls.isEmpty {
                chunkFinishReason = "tool_calls"
            }
            
            sendFinishReason(chunkFinishReason)
        }
        
        if let tokenUsage = response.usage {
            self.tokenUsage = tokenUsage
        }
    }
    
    private func sendReason(_ reason: String) {
        delegate?.client(self, receivePart: LLMAssistantMessage(reason: reason))
    }
    
    private func sendContent(_ content: String) {
        delegate?.client(self, receivePart: LLMAssistantMessage(content: content))
    }
    
    private func sendToolCall(_ toolCall: LLMMessageToolCall) {
        delegate?.client(self, receivePart: LLMAssistantMessage(tools: [toolCall]))
    }
    
    private func sendFinishReason(_ finishReason: String) {
        delegate?.client(self, receivePart: LLMAssistantMessage(finishReason: finishReason))
    }
}
