//
//  ChatProxyAgenticBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/7.
//

import Foundation

class ChatProxyAgenticBridge {
    let id: String
    let delegate: ChatProxyBridgeDelegate
    
    private var llmClient: LLMClient?
    private var isConnected = false
    
    var config: LLMConfig?
    
    private var thinkParser: ThinkParser = Configer.chatProxyThinkStyle
    private var thinkState: ThinkState = .notStarted
    
    private var useToolInRequest = Configer.chatProxyToolUseInRequest
    
    init(id: String, delegate: ChatProxyBridgeDelegate) {
        self.id = id
        self.delegate = delegate
    }
    
    func receiveRequest(_ request: LLMAgenticRequest) {
        guard let config = StorageManager.shared.defaultConfig(), let modelProvider = config.getModelProvider() else {
            delegate.bridge(connected: false)
            return
        }
        self.config = config
        
        let newRequest = processRequest(request)
        
        thinkState = .notStarted
        
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        llmClient = LLMClient(modelProvider, delegate: self)
        llmClient?.request(newRequest)
    }
    
    private let createTime = Int(Date.now.timeIntervalSince1970)
    private var _sequenceNumber = 0
    private var sequenceNumber: Int {
        get {
            defer {
                _sequenceNumber += 1
            }
            return _sequenceNumber
        }
    }
    private var itemId = ""
    private var outputs = [LLMAgenticResponseEvent.OutputItem]()
    
    enum OutputType {
        case none
        case reasoning
        case text
        case functionCall
    }
    
    var lastOutputPart = OutputType.none
    var lastContent = ""
    
    private func sendEvents(_ events: [LLMAgenticResponseEvent]) {
        for event in events {
            sendEvent(event)
        }
    }
    
    private func sendEvent(_ event: LLMAgenticResponseEvent?) {
        guard let event else {
            return
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let jsonData = try? encoder.encode(event), let jsonString = String(data: jsonData, encoding: .utf8) {
            delegate.bridge(write: jsonString)
        }
    }
    
}

// MARK: Request
extension ChatProxyAgenticBridge {
    private func processRequest(_ request: LLMAgenticRequest) -> LLMRequest {
        guard let config = config else {
            return LLMRequest(model: "", messages: [], stream: request.stream, usage: true, tools: nil, seed: nil, maxTokens: nil, temperature: nil, topP: nil, enableThinking: nil)
        }
        
        var messages = [LLMMessage]()
        if let instructions = request.instructions {
            messages.append(LLMMessage(role: "system", content: instructions))
        }
        
        if !useToolInRequest, let tools = request.tools, tools.count > 0 {
            var toolPrompt =  PromptTemplate.systemPromptToolTemplate
            let toolsStr: String = {
                var ret = PromptTemplate.systemPromptAvailableToolTemplate
                for tool in tools {
                    ret += tool.toPrompt() + "\n"
                }
                return ret + PromptTemplate.systemPromptAvailableToolTemplateEnd
            }()
            
            toolPrompt = toolPrompt.replacingOccurrences(of: "{{TOOLS}}", with: toolsStr)
            
            messages.append(LLMMessage(role: "system", content: toolPrompt))
        }
        
        if let inputs = request.input {
            for (inputIdx, input) in inputs.enumerated() {
                if input.type == "message", let contents = input.content {
                    let role = {
                        if input.role == "developer" {
                            return "system"
                        }
                        return input.role ?? "user"
                    }()
                    for (contentIdx, content) in contents.enumerated() {
                        if var text = content.text {
                            if role == "assistant" {
                                text = processAssistantMessageContent(text)
                            }
                            if role == "user" {
                                let isLastMessage = (inputIdx == inputs.count - 1 && contentIdx == contents.count - 1)
                                text = processUserMessageContent(text, isLastMessage: isLastMessage)
                            }
                            messages.append(LLMMessage(role: role, content: text))
                        }
                    }
                } else if input.type == "function_call", let name = input.name, let arguments = input.arguments, let callId = input.callId {
                    
                    var toolUse = PromptTemplate.toolUseTemplate
                    toolUse = toolUse.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                    toolUse = toolUse.replacingOccurrences(of: "{{ARGUMENTS}}", with: arguments)
                    
                    messages.append(LLMMessage(role: "assistant", content: toolUse))
                    
                    for input in inputs {
                        if input.type == "function_call_output", let respCallId = input.callId, respCallId == callId {
                            
                            var toolUseResult = PromptTemplate.toolUseResultTemplate
                            toolUseResult = toolUseResult.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                            toolUseResult = toolUseResult.replacingOccurrences(of: "{{RESULT}}", with: input.output ?? "")
                            
                            messages.append(LLMMessage(role: "user", content: toolUseResult))
                        }
                    }
                }
            }
        }
        
        var tools: [LLMTool]? = nil
        
        if useToolInRequest {
            var thisTools = [LLMTool]()
            if let requestTools = request.tools {
                for tool in requestTools {
                    let parameters: String? = {
                        if let data = try? JSONEncoder().encode(tool.parameters), let schema = String(data: data, encoding: .utf8) {
                            return schema
                        }
                        return nil
                    }()
                    thisTools.append(LLMTool(type: "function", function: .init(name: tool.name, description: tool.description, parameters: parameters)))
                }
            }
            tools = thisTools
        }
        
        return LLMRequest(model: config.modelName, messages: messages, stream: request.stream, usage: true, tools: tools, seed: nil, maxTokens: nil, temperature: nil, topP: nil, enableThinking: nil)
    }
}

extension ChatProxyAgenticBridge {
    private func processAssistantMessageContent(_ content: String) -> String {
        var returnContent = content
        
        // Remove think part in assistant message
        // Process simple because think could only be at the start of content
        if returnContent.substring(to: ThinkInContentWithCodeSnippetStartMarkForAgentic.count) == ThinkInContentWithCodeSnippetStartMarkForAgentic {
            let components = returnContent.split(separator: ThinkInContentWithCodeSnippetEndMark, maxSplits: 1)
            if components.count == 2 {
                returnContent = String(components[1])
            }
        } else if returnContent.contains(ThinkInContentWithEOTEndMark) {
            let components = returnContent.components(separatedBy: ThinkInContentWithEOTEndMark)
            if components.count == 2 {
                returnContent = components[1]
            }
        }
        
        return returnContent
    }
    
    private func processUserMessageContent(_ content: String, isLastMessage: Bool = false) -> String {
        let returnContent = content
        if isLastMessage {
            // Force return in language, only for last message
            let forceLanguage = Configer.forceLanguage
            
            let languageContent: String = {
                switch forceLanguage {
                case .english:
                    return PromptTemplate.FLEnglish
                case .chinese:
                    return PromptTemplate.FLChinese
                case .french:
                    return PromptTemplate.FLFrance
                case .russian:
                    return PromptTemplate.FLRussian
                case .japanese:
                    return PromptTemplate.FLJapanese
                case .korean:
                    return PromptTemplate.FLKorean
                }
            }()
            
            if !languageContent.isEmpty {
                return returnContent + "\n" + languageContent
            }
            
            return returnContent
        }
        return returnContent
    }
}

extension ChatProxyAgenticBridge: LLMClientDelegate {
    func clientConnected(_ client: LLMClient) {
        isConnected = true
        delegate.bridge(connected: true)
        
        sendEvents([
            LLMAgenticResponseEvent.responseCreated(.init(response: .init(id: id, object: "response", createdAt: createTime, status: "queued", model: "XcodePaI"), sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.responseInProgress(.init(response: .init(id: id, object: "response", createdAt: createTime, status: "in_progress", model: "XcodePaI"), sequenceNumber: sequenceNumber))
        ])
    }
    
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        sendReasonChunk(part.reason)
        if let content = part.content {
            sendTextChunk(content)
        }
        if let tools = part.tools {
            for tool in tools {
                sendFunctionCall(tool)
            }
        }
        
        if part.finishReason != nil {
            completeLastOutput()
            lastOutputPart = .none
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
    
    func client(_ client: LLMClient, receiveError error: (any Error)?) {
        if !isConnected {
            MenuBarManager.shared.stopLoading()
            delegate.bridge(connected: false)
            return
        }
        
        if let _ = error {
            // Error
            delegate.bridge(write: ["internal_error": "Server error"])
        }
        
        sendEvent(LLMAgenticResponseEvent.responseCompleted(.init(response: .init(id: id, createdAt: createTime, status: "completed", model: "XcodePaI", output: outputs), sequenceNumber: sequenceNumber)))
        
        delegate.bridgeWriteEndChunk()
        
        llmClient?.stop()
        llmClient = nil
        
        MenuBarManager.shared.stopLoading()
    }
}

extension ChatProxyAgenticBridge {
    private func sendReasonChunk(_ chunk: String?) {
        guard let chunk, !chunk.isEmpty else { return }
        
        if thinkParser == .inReasoningContent {
            // Reasoning
            if lastOutputPart != .reasoning {
                completeLastOutput()
                lastOutputPart = .reasoning
                itemId = "rs_\(UUID().uuidString)"
                
                sendEvents([
                    LLMAgenticResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .reasoning(.init(id: itemId)), sequenceNumber: sequenceNumber)),
                    LLMAgenticResponseEvent.reasoningSummaryPartAdded(.init(itemId: itemId, outputIndex: 0, summaryIndex: 0, part: .init(text: ""), sequenceNumber: sequenceNumber))
                ])
            }
            
            sendEvent(LLMAgenticResponseEvent.reasoningSummaryTextDelta(.init(itemId: itemId, outputIndex: 0, summaryIndex: 0, delta: chunk, sequenceNumber: sequenceNumber)))
            lastContent += chunk
        } else {
            var textContent = ""
            switch thinkState {
            case .notStarted:
                thinkState = .inProgress
                let startThinkMark: String = {
                    switch thinkParser {
                    case .inContentWithCodeSnippet:
                        return ThinkInContentWithCodeSnippetStartMarkForAgentic
                    default:
                        return ""
                    }
                }()
                let processedReason = chunk.replacingOccurrences(of: "```", with: "'''")
                textContent = startThinkMark + processedReason
            case .inProgress:
                let processedReason = chunk.replacingOccurrences(of: "```", with: "'''")
                textContent = processedReason
            case .completed:
                // No reason in this state
                break
            }
            
            sendTextChunk(textContent, true)
        }
    }
    
    private func sendReasonEndMarkIfNeed() {
        if thinkParser != .inReasoningContent, thinkState == .inProgress {
            thinkState = .completed
            let endThinkMark: String = {
                switch thinkParser {
                case .inContentWithEOT:
                    return ThinkInContentWithEOTEndMark
                case .inContentWithCodeSnippet:
                    return ThinkInContentWithCodeSnippetEndMark
                default:
                    return ""
                }
            }()
            lastContent += endThinkMark
            sendEvent(LLMAgenticResponseEvent.outputTextDelta(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, delta: endThinkMark, sequenceNumber: sequenceNumber)))
        }
    }
    
    private func sendTextChunk(_ chunk: String?, _ fromReasoing: Bool = false) {
        guard let chunk, !chunk.isEmpty else { return }
        
        if !fromReasoing {
            sendReasonEndMarkIfNeed()
        }
        
        if lastOutputPart != .text {
            completeLastOutput()
            lastOutputPart = .text
            itemId = "msg_\(UUID().uuidString)"
            
            sendEvents([
                LLMAgenticResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .message(.init(id: itemId, content: [], status: "in_progress")), sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.contentPartAdded(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, part: .outputText(.init(text: "")), sequenceNumber: sequenceNumber))
            ])
        }
        
        sendEvent(LLMAgenticResponseEvent.outputTextDelta(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, delta: chunk, sequenceNumber: sequenceNumber)))
        lastContent += chunk
    }
    
    private func sendFunctionCall(_ toolUse: LLMMessageToolCall) {
        sendReasonEndMarkIfNeed()
        
        guard let name = toolUse.function.name else {
            return
        }
        let arguments = toolUse.function.arguments ?? ""
        
        if lastOutputPart != .functionCall {
            completeLastOutput()
            lastOutputPart = .functionCall
        }
        
        // Function Call
        itemId = "msg_\(UUID().uuidString)"
        let callId = "call_\(UUID().uuidString)"
        
        sendEvents([
            LLMAgenticResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .functionCall(.init(id: itemId, callId: callId, name: name)), sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.functionCallArgumentsDelta(.init(itemId: itemId, outputIndex: outputs.count, delta: arguments, sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.functionCallArgumentsDone(.init(itemId: itemId, name: name, outputIndex: outputs.count, arguments: arguments, sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .functionCall(.init(id: itemId, callId: callId, name: name, arguments: arguments)), sequenceNumber: sequenceNumber))
        ])
        
        outputs.append(.functionCall(.init(id: itemId, callId: callId, name: name, arguments: arguments)))
    }
    
    private func completeLastOutput() {
        if lastOutputPart == .none {
            return
        }
        
        switch lastOutputPart {
        case .none:
            return
        case .reasoning:
            sendEvents([
                LLMAgenticResponseEvent.reasoningSummaryTextDone(.init(itemId: itemId, outputIndex: outputs.count, summaryIndex: 0, text: lastContent, sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.reasoningSummaryPartDone(.init(itemId: itemId, outputIndex: outputs.count, summaryIndex: 0, part: .init(text: lastContent), sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .reasoning(.init(id: itemId, content: [.init(text: lastContent)])), sequenceNumber: sequenceNumber))
            ])
            outputs.append(.reasoning(.init(id: itemId, content: [.init(text: lastContent)])))
            lastContent = ""
            lastOutputPart = .none
        case .text:
            sendEvents([
                LLMAgenticResponseEvent.contentPartDone(.init(itemId: itemId, outputIndex: 0, contentIndex: 0, part: .outputText(.init(text: lastContent)), sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.outputItemDone(.init(outputIndex: 0, item: .message(.init(id: itemId, content: [.outputText(.init(text: lastContent))])), sequenceNumber: sequenceNumber))
            ])
            outputs.append(.message(.init(id: itemId, content: [.outputText(.init(text: lastContent))])))
            lastContent = ""
            lastOutputPart = .none
        case .functionCall:
            // No Need
            return
        }
    }
}
