//
//  LLMClient.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

protocol LLMClientDelegate {
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage)
    func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage)
    func client(_ client: LLMClient, receiveError errorInfo: [String: Any])
    func client(_ client: LLMClient, closeWithComplete complete: Bool)
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
    
    private var client: HTTPSSEClient?
    
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
        
        client = HTTPSSEClient(url: provider.chatCompletionsUrl(), headers: provider.requestHeaders(), body: data, delegate: self)
        client?.start()
    }

    func stop() {
        client?.cancel()
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
                    thinkTagComplete = false
                    
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

extension LLMClient: HTTPSSEClientDelegate {
    func client(_ client: HTTPSSEClient, receive chunk: String) {
        if chunk == "[DONE]" {
            // close client when receive `DONE`
            client.cancel()
            return
        }
        guard let data = chunk.data(using: .utf8), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        guard let _ = dict["id"] else {
            // Error
            delegate.client(self, receiveError: dict)
            client.cancel()
            return
        }
        
        let response = LLMResponse(dict: dict)
        
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
                client.cancel()
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
    
    func client(_ client: HTTPSSEClient, complete: Result<Void, any Error>) {
        sendFullMessage()
        switch complete {
        case .success(_):
            delegate.client(self, closeWithComplete: true)
        case .failure(_):
            delegate.client(self, closeWithComplete: false)
        }
    }
}
