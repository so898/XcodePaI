//
//  ChatProxyBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/14.
//

import Foundation

protocol ChatProxyBridgeDelegate {
    func bridge(_ bridge: ChatProxyBridge, connected success: Bool)
    func bridge(_ bridge: ChatProxyBridge, write chunk: String)
    func bridgeWirteEndChunk(_ bridge: ChatProxyBridge)
}

class ChatProxyBridge {
    
    let id: String
    let delegate: ChatProxyBridgeDelegate
    
    private var llmClient: LLMClient?
    private var hasThink: Bool?
    
    init(id: String, delegate: ChatProxyBridgeDelegate) {
        self.id = id
        self.delegate = delegate
    }
    
    func receiveRequest(_ request: LLMRequest) {
        let newRequest = request
        newRequest.model = "xxx"
        
        // Do LLM request to server, add MCP...
        hasThink = nil
        
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        llmClient = LLMClient(LLMModelProvider(name: "test", url: "xxx", privateKey: "sk-xxx"), delegate: self)
        llmClient?.request(newRequest)
    }
}

extension ChatProxyBridge: LLMClientDelegate {
    func client(_ client: LLMClient, connected success: Bool) {
        delegate.bridge(self, connected: success)
    }
    
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        var response: LLMResponse?
        if hasThink == nil, let reason = part.reason {
            hasThink = true
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: "```think\n\n" + reason.replacingOccurrences(of: "```", with: "'''")))])
        } else if hasThink == true, let reason = part.reason {
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: reason.replacingOccurrences(of: "```", with: "'''")))])
        } else if hasThink == true, part.reason == nil, let content = part.content {
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: "\n\n~~EOT~~\n\n```\n\n" + content,))])
            hasThink = false
        } else if let content = part.content{
            response = LLMResponse(id: id, model: "XcodePaI", object: "chat.completion.chunk", choices: [LLMResponseChoice(index: 0, finishReason: part.finishReason, isFullMessage: false, message: LLMResponseChoiceMessage(role: "assistant", content: content))])
        }
        
        if let response = response, let json = try? JSONSerialization.data(withJSONObject: response.toDictionary()), let jsonStr = String(data: json, encoding: .utf8) {
            delegate.bridge(self, write: jsonStr + Constraint.DoubleLFString)
        }
    }
    
    func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage) {
        if let reason = message.reason {
            print("[R] \(reason)")
        }
        
        if let content = message.content {
            print("[C] \(content)")
        }
    }
    
    func client(_ client: LLMClient, receiveError errorInfo: [String : Any]) {
        // Send Error
        if let json = try? JSONSerialization.data(withJSONObject: errorInfo), let jsonStr = String(data: json, encoding: .utf8) {
            delegate.bridge(self, write: jsonStr + Constraint.DoubleLFString)
        }
        delegate.bridge(self, write: "[DONE]" + Constraint.DoubleLFString)
        delegate.bridgeWirteEndChunk(self)
    }
    
    func client(_ client: LLMClient, closeWithComplete complete: Bool) {
        delegate.bridge(self, write: "[DONE]" + Constraint.DoubleLFString)
        delegate.bridgeWirteEndChunk(self)
    }
    
    
}
