//
//  ChatProxyCodexBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/7.
//

import Foundation

/// Bridge between chat proxy and Agentic API
/// Responsible for processing Agentic format requests, converting them to LLM requests,
/// handling LLM responses, and converting them back to Agentic format event streams
class ChatProxyCodexBridge: ChatProxyBridgeBase {
    
    override func receiveRequestData(_ data: Data) {
        guard let request = try? JSONDecoder().decode(LLMCodexRequest.self, from: data) else {
            delegate.bridge(connected: false)
            return
        }
        
        receiveRequest(request)
    }
    
    /// Receive and process Agentic format requests
    /// - Parameter request: Agentic format request object
    private func receiveRequest(_ request: LLMCodexRequest) {
        // Get default configuration and model provider from storage manager
        guard let config = StorageManager.shared.defaultConfig(), let modelProvider = config.getModelProvider() else {
            // Configuration incomplete or error, notify delegate of connection failure
            delegate.bridge(connected: false)
            return
        }
        self.config = config
        
        // Process request, convert to LLM request format
        let newRequest = processRequest(request)
        
        // Reset thinking state
        thinkState = .notStarted
        
        // Create new LLM client and send request
        createLLMClient(with: config, modelProvider: modelProvider).request(newRequest)
    }
    
    // MARK: Request - Request processing extension
    
    /// Process Agentic request, convert to LLM request format
    /// - Parameter request: Agentic format request
    /// - Returns: Converted LLM request
    private func processRequest(_ request: LLMCodexRequest) -> LLMRequest {
        // If configuration doesn't exist, return empty LLM request
        guard let config = config else {
            return LLMRequest(model: "", messages: [], stream: request.stream, usage: true, tools: nil, seed: nil, maxTokens: nil, temperature: nil, topP: nil, enableThinking: nil)
        }
        
        // Build message array
        var messages = [LLMMessage]()
        // Add system instructions (if any)
        if let instructions = request.instructions {
            messages.append(LLMMessage(role: "system", content: instructions))
        }
        
        // If not using tools in request, build tool prompt
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
        
        // Process input content
        if let inputs = request.input {
            for (inputIdx, input) in inputs.enumerated() {
                // Process message type input
                if input.type == "message", let contents = input.content {
                    let role = {
                        if input.role == "developer" {
                            return "system"
                        }
                        return input.role ?? "user"
                    }()
                    for (contentIdx, content) in contents.enumerated() {
                        if var text = content.text {
                            // Process assistant message content (remove thinking part)
                            if role == "assistant" {
                                text = processAssistantMessageContent(text)
                                // Remove empty assistant message
                                if text.replacingOccurrences(of: "\n", with: "").isEmpty {
                                    continue
                                }
                            }
                            // Process user message content (add language force prompt)
                            if role == "user" {
                                let isLastMessage = (inputIdx == inputs.count - 1 && contentIdx == contents.count - 1)
                                text = processUserMessageContent(text, isLastMessage: isLastMessage)
                            }
                            messages.append(LLMMessage(role: role, content: text))
                        }
                    }
                } else if input.type == "function_call", let name = input.name, let arguments = input.arguments, let callId = input.callId {
                    // Process function call type input
                    if useToolInRequest {
                        messages.append(LLMMessage(role: "assistant", toolCalls: [LLMMessageToolCall(id: callId, type: "function", function: LLMFunction(name: name, arguments: arguments))]))
                    } else {
                        var toolUse = PromptTemplate.toolUseTemplate
                        toolUse = toolUse.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                        toolUse = toolUse.replacingOccurrences(of: "{{ARGUMENTS}}", with: arguments)
                        messages.append(LLMMessage(role: "assistant", content: toolUse))
                    }
                    
                    // Find corresponding function call output
                    for input in inputs {
                        if input.type == "function_call_output", let respCallId = input.callId, respCallId == callId {
                            if useToolInRequest {
                                messages.append(LLMMessage(toolCallId: respCallId, functionName: name, content: input.output ?? ""))
                            } else {
                                var toolUseResult = PromptTemplate.toolUseResultTemplate
                                toolUseResult = toolUseResult.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                                toolUseResult = toolUseResult.replacingOccurrences(of: "{{RESULT}}", with: input.output ?? "")
                                messages.append(LLMMessage(role: "user", content: toolUseResult))
                            }
                        }
                    }
                }
            }
        }
        
        var tools: [LLMTool]? = nil
        
        // If using tools in request, build tool array
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
        
        // Return complete LLM request
        return LLMRequest(model: config.modelName, messages: messages, stream: request.stream, usage: true, tools: tools, seed: nil, maxTokens: nil, temperature: nil, topP: nil, enableThinking: Configer.chatProxyEnableThink)
    }
    
    /// Response creation time (Unix timestamp)
    private let createTime = Int(Date.now.timeIntervalSince1970)
    /// Internal sequence number counter
    private var _sequenceNumber = 0
    /// Sequence number lock for thread safety
    private let sequenceNumberLock = NSLock()
    /// Sequence number computed property, increments and returns each time accessed
    private var sequenceNumber: Int {
        sequenceNumberLock.lock()
        defer {
            _sequenceNumber += 1
            sequenceNumberLock.unlock()
        }
        return _sequenceNumber
    }
    /// Unique identifier for current output item
    private var itemId = ""
    /// Array storing all output items
    private var outputs = [LLMCodexResponseEvent.OutputItem]()
    
    /// Output type enumeration, used to track current output content type
    enum OutputType {
        case none          // No output
        case reasoning     // Thinking content
        case text         // Text content
        case functionCall  // Function call
    }
    
    /// Type of previous output part
    var lastOutputPart = OutputType.none
    /// Content of previous output part (accumulated)
    var lastContent = ""
    
    /// Send multiple events
    /// - Parameter events: Array of events to send
    private func sendEvents(_ events: [LLMCodexResponseEvent]) {
        for event in events {
            sendEvent(event)
        }
    }
    
    /// Send single event
    /// - Parameter event: Event object to send
    private func sendEvent(_ event: LLMCodexResponseEvent?) {
        guard let event else {
            return
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // Encode event to JSON string and send through delegate
        if let jsonData = try? encoder.encode(event), let jsonString = String(data: jsonData, encoding: .utf8) {
            delegate.bridge(write: jsonString)
        }
    }
    
    // MARK: - LLMClientDelegate - LLM client delegate implementation
    
    /// LLM client connection successful callback
    /// - Parameter client: Connected LLM client
    override func clientConnected(_ client: LLMClient) {
        super.clientConnected(client)
        
        // Send response created and response in progress events
        sendEvents([
            LLMCodexResponseEvent.responseCreated(.init(response: .init(id: id, object: "response", createdAt: createTime, status: "queued", model: "XcodePaI"), sequenceNumber: sequenceNumber)),
            LLMCodexResponseEvent.responseInProgress(.init(response: .init(id: id, object: "response", createdAt: createTime, status: "in_progress", model: "XcodePaI"), sequenceNumber: sequenceNumber))
        ])
    }
    
    /// LLM client error reception callback
    /// - Parameters:
    ///   - client: LLM client
    ///   - error: Error information
    override func client(_ client: LLMClient, receiveError error: (any Error)?) {
        super.client(client, receiveError: error)
        
        // If there's an error, send error event
        if let error = error {
            // Send error event
            let errorEvent = LLMCodexResponseEvent.error(.init(
                code: "internal_error",
                message: error.localizedDescription,
                param: nil,
                sequenceNumber: sequenceNumber
            ))
            sendEvent(errorEvent)
        }
        
        // Send response completed event
        sendEvent(LLMCodexResponseEvent.responseCompleted(.init(response: .init(id: id, createdAt: createTime, status: "completed", model: "XcodePaI", output: outputs), sequenceNumber: sequenceNumber)))
        
        // Notify delegate to write end chunk
        delegate.bridgeWriteEndChunk()
        
        // Stop and release LLM client
        stopLLMClient()
    }
    
    // MARK: - Response event sending
    
    /// Send thinking content chunk
    /// - Parameter chunk: Thinking content chunk
    override func sendReasonChunk(_ chunk: String?) {
        guard let chunk, !chunk.isEmpty else { return }
        
        // Process thinking content based on thinking parsing method
        if thinkParser == .inReasoningContent {
            // Reasoning content mode
            if lastOutputPart != .reasoning {
                completeLastOutput()
                lastOutputPart = .reasoning
                itemId = "rs_\(UUID().uuidString)"
                
                // Send output item added and reasoning summary part added events
                sendEvents([
                    LLMCodexResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .reasoning(.init(id: itemId)), sequenceNumber: sequenceNumber)),
                    LLMCodexResponseEvent.reasoningSummaryPartAdded(.init(itemId: itemId, outputIndex: 0, summaryIndex: 0, part: .init(text: ""), sequenceNumber: sequenceNumber))
                ])
            }
            
            // Send reasoning summary text delta event
            sendEvent(LLMCodexResponseEvent.reasoningSummaryTextDelta(.init(itemId: itemId, outputIndex: 0, summaryIndex: 0, delta: chunk, sequenceNumber: sequenceNumber)))
            lastContent += chunk
        } else {
            // Other thinking parsing modes (thinking embedded in content)
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
                // No thinking content in this state
                break
            }
            
            // Send thinking content as text chunk
            sendContentChunk(textContent, true)
        }
    }
    
    /// Send thinking end marker if needed
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
            sendEvent(LLMCodexResponseEvent.outputTextDelta(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, delta: endThinkMark, sequenceNumber: sequenceNumber)))
        }
    }
    
    /// Send text content chunk
    /// - Parameters:
    ///   - chunk: Text content chunk
    ///   - fromReasoning: Whether coming from thinking content
    override func sendContentChunk(_ chunk: String?, _ fromReasoning: Bool = false) {
        guard let chunk, !chunk.isEmpty else { return }
        
        // If not from thinking content, send thinking end marker
        if !fromReasoning {
            sendReasonEndMarkIfNeed()
        }
        
        // If current output type is not text, complete previous output and start new text output
        if lastOutputPart != .text {
            completeLastOutput()
            lastOutputPart = .text
            itemId = "msg_\(UUID().uuidString)"
            
            // Send output item added and content part added events
            sendEvents([
                LLMCodexResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .message(.init(id: itemId, content: [], status: "in_progress")), sequenceNumber: sequenceNumber)),
                LLMCodexResponseEvent.contentPartAdded(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, part: .outputText(.init(text: "")), sequenceNumber: sequenceNumber))
            ])
        }
        
        // Send output text delta event
        sendEvent(LLMCodexResponseEvent.outputTextDelta(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, delta: chunk, sequenceNumber: sequenceNumber)))
        lastContent += chunk
    }
    
    /// Send function call
    /// - Parameter toolUse: Tool call object
    override func sendFunctionCall(_ toolUse: LLMMessageToolCall) {
        sendReasonEndMarkIfNeed()
        
        guard let name = toolUse.function.name else {
            return
        }
        let arguments = toolUse.function.arguments ?? ""
        
        // If current output type is not function call, complete previous output
        if lastOutputPart != .functionCall {
            completeLastOutput()
            lastOutputPart = .functionCall
        }
        
        // Function call
        itemId = "msg_\(UUID().uuidString)"
        let callId = "call_\(UUID().uuidString)"
        
        // Send function call related events
        sendEvents([
            LLMCodexResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .functionCall(.init(id: itemId, callId: callId, name: name)), sequenceNumber: sequenceNumber)),
            LLMCodexResponseEvent.functionCallArgumentsDelta(.init(itemId: itemId, outputIndex: outputs.count, delta: arguments, sequenceNumber: sequenceNumber)),
            LLMCodexResponseEvent.functionCallArgumentsDone(.init(itemId: itemId, name: name, outputIndex: outputs.count, arguments: arguments, sequenceNumber: sequenceNumber)),
            LLMCodexResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .functionCall(.init(id: itemId, callId: callId, name: name, arguments: arguments, status: "completed")), sequenceNumber: sequenceNumber))
        ])
        
        // Add function call to output array
        outputs.append(.functionCall(.init(id: itemId, callId: callId, name: name, arguments: arguments)))
    }
    
    override func sendFinishReason(_ finishReason: String) {
        sendReasonEndMarkIfNeed()
        
        completeLastOutput()
        lastOutputPart = .none
    }
    
    /// Complete previous output, send corresponding completion events
    private func completeLastOutput() {
        if lastOutputPart == .none {
            return
        }
        
        // Send different completion events based on output type
        switch lastOutputPart {
        case .none:
            return
        case .reasoning:
            sendEvents([
                LLMCodexResponseEvent.reasoningSummaryTextDone(.init(itemId: itemId, outputIndex: outputs.count, summaryIndex: 0, text: lastContent, sequenceNumber: sequenceNumber)),
                LLMCodexResponseEvent.reasoningSummaryPartDone(.init(itemId: itemId, outputIndex: outputs.count, summaryIndex: 0, part: .init(text: lastContent), sequenceNumber: sequenceNumber)),
                LLMCodexResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .reasoning(.init(id: itemId, content: [.init(text: lastContent)], status: "completed")), sequenceNumber: sequenceNumber))
            ])
            outputs.append(.reasoning(.init(id: itemId, content: [.init(text: lastContent)])))
            lastContent = ""
            lastOutputPart = .none
        case .text:
            sendEvents([
                LLMCodexResponseEvent.contentPartDone(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, part: .outputText(.init(text: lastContent)), sequenceNumber: sequenceNumber)),
                LLMCodexResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .message(.init(id: itemId, content: [.outputText(.init(text: lastContent))], status: "completed")), sequenceNumber: sequenceNumber))
            ])
            outputs.append(.message(.init(id: itemId, content: [.outputText(.init(text: lastContent))])))
            lastContent = ""
            lastOutputPart = .none
        case .functionCall:
            // Function call already completed when called, no additional processing needed
            return
        }
    }
}

