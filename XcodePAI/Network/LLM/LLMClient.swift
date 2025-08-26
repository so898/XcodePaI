//
//  LLMClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import EventSource
import Combine

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
    private let delegate: LLMClientDelegate
    
    private var eventSource: EventSource?
    var cancellable: Cancellable?
    
    init(_ provider: LLMModelProvider, delegate: LLMClientDelegate) {
        self.provider = provider
        self.delegate = delegate
    }
    
    private var requestTools = [LLMMessageToolCall]()
    
    func request(_ request: LLMRequest) {
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
            self.delegate.clientConnected(self)
        }
        client.onMessage = { [weak self] event in
            guard let `self` = self else { return }
            self.receive(chunk: event.data)
        }
        client.onError = { [weak self] error in
            guard let `self` = self else { return }
            
            if error == nil {
                self.sendFullMessage()
            }
            
            self.delegate.client(self, receiveError: error)
        }
        self.eventSource = client
    }

    func stop() {
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
    private var tools: [LLMMessageToolCall]?
    
    private func sendFullMessage() {
        delegate.client(self, receiveMessage: LLMAssistantMessage(reason: reason,
                                                                  isReasonComplete: true,
                                                                  content: content,
                                                                  tools: tools))
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
                tools = chunkTools
                
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
        
        if let chunkReason = chunkReason {
            if let reason = reason {
                self.reason = reason + chunkReason
            } else {
                reason = chunkReason
            }
        }
        
        if let chunkContent = chunkContent {
            if let content = content {
                self.content = content + chunkContent
            } else {
                content = chunkContent
            }
        }
        
        if let chunkTools = chunkTools {
            if var tools = tools {
                tools.append(contentsOf: chunkTools)
                self.tools = tools
            } else {
                tools = chunkTools
            }
        }
        
        delegate.client(self, receivePart: LLMAssistantMessage(reason: chunkReason,
                                                               isReasonComplete: isReasonComplete,
                                                               content: chunkContent,
                                                               tools: chunkTools,
                                                               finishReason: chunkFinishReason))
    }
}
