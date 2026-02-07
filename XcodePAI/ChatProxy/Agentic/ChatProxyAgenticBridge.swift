//
//  ChatProxyAgenticBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/7.
//

import Foundation

/// Bridge between chat proxy and Agentic API
/// Responsible for processing Agentic format requests, converting them to LLM requests,
/// handling LLM responses, and converting them back to Agentic format event streams
class ChatProxyAgenticBridge {
    /// Unique identifier for the current request
    let id: String
    /// Delegate object for the bridge, used for external communication
    let delegate: ChatProxyBridgeDelegate
    
    /// LLM client instance for sending requests and receiving responses
    private var llmClient: LLMClient?
    /// Indicates whether connected to LLM service
    private var isConnected = false
    
    /// LLM configuration information
    var config: LLMConfig?
    
    /// Thinking content parsing method (in content, with code snippets, with EOT markers, etc.)
    private var thinkParser: ThinkParser = Configer.chatProxyThinkStyle
    /// Thinking state, used to track whether currently processing thinking content
    private var thinkState: ThinkState = .notStarted
    
    /// Whether to use tools (function calls) in requests
    private var useToolInRequest = Configer.chatProxyToolUseInRequest
    
    /// Initialize the proxy bridge
    /// - Parameters:
    ///   - id: Unique identifier for the request
    ///   - delegate: Delegate object for the proxy bridge
    init(id: String, delegate: ChatProxyBridgeDelegate) {
        self.id = id
        self.delegate = delegate
    }
    
    /// Destructor, ensures LLM client is stopped when deallocated
    deinit {
        llmClient?.stop()
        llmClient = nil
    }
    
    /// Receive and process Agentic format requests
    /// - Parameter request: Agentic format request object
    func receiveRequest(_ request: LLMAgenticRequest) {
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
        
        // If LLM client already exists, stop it first
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        // Create new LLM client and send request
        llmClient = LLMClient(modelProvider, delegate: self)
        llmClient?.request(newRequest)
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
    private var outputs = [LLMAgenticResponseEvent.OutputItem]()
    
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
    private func sendEvents(_ events: [LLMAgenticResponseEvent]) {
        for event in events {
            sendEvent(event)
        }
    }
    
    /// Send single event
    /// - Parameter event: Event object to send
    private func sendEvent(_ event: LLMAgenticResponseEvent?) {
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
    
}

// MARK: Request - Request processing extension
extension ChatProxyAgenticBridge {
    /// Process Agentic request, convert to LLM request format
    /// - Parameter request: Agentic format request
    /// - Returns: Converted LLM request
    private func processRequest(_ request: LLMAgenticRequest) -> LLMRequest {
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
                    
                    var toolUse = PromptTemplate.toolUseTemplate
                    toolUse = toolUse.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                    toolUse = toolUse.replacingOccurrences(of: "{{ARGUMENTS}}", with: arguments)
                    
                    messages.append(LLMMessage(role: "assistant", content: toolUse))
                    
                    // Find corresponding function call output
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
        return LLMRequest(model: config.modelName, messages: messages, stream: request.stream, usage: true, tools: tools, seed: nil, maxTokens: nil, temperature: nil, topP: nil, enableThinking: nil)
    }
}

// MARK: - Message content processing extension
extension ChatProxyAgenticBridge {
    /// Process assistant message content, remove thinking part
    /// - Parameter content: Original assistant message content
    /// - Returns: Processed message content
    private func processAssistantMessageContent(_ content: String) -> String {
        var returnContent = content
        
        // Remove thinking part in assistant message
        // Simple processing because thinking part can only appear at the start of content
        if returnContent.count > ThinkInContentWithCodeSnippetStartMarkForAgentic.count, returnContent.substring(to: ThinkInContentWithCodeSnippetStartMarkForAgentic.count) == ThinkInContentWithCodeSnippetStartMarkForAgentic {
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
    
    /// Process user message content, add language force prompt if needed
    /// - Parameters:
    ///   - content: Original user message content
    ///   - isLastMessage: Whether it's the last message
    /// - Returns: Processed message content
    private func processUserMessageContent(_ content: String, isLastMessage: Bool = false) -> String {
        let returnContent = content
        if isLastMessage {
            // Add language force prompt only for last message
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

// MARK: - LLMClientDelegate - LLM client delegate implementation
extension ChatProxyAgenticBridge: LLMClientDelegate {
    /// LLM client connection successful callback
    /// - Parameter client: Connected LLM client
    func clientConnected(_ client: LLMClient) {
        isConnected = true
        delegate.bridge(connected: true)
        
        // Send response created and response in progress events
        sendEvents([
            LLMAgenticResponseEvent.responseCreated(.init(response: .init(id: id, object: "response", createdAt: createTime, status: "queued", model: "XcodePaI"), sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.responseInProgress(.init(response: .init(id: id, object: "response", createdAt: createTime, status: "in_progress", model: "XcodePaI"), sequenceNumber: sequenceNumber))
        ])
    }
    
    /// Received LLM response part callback
    /// - Parameters:
    ///   - client: LLM client
    ///   - part: Received partial response
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        // Send thinking chunk
        sendReasonChunk(part.reason)
        // Send text chunk
        if let content = part.content {
            sendTextChunk(content)
        }
        // Send function calls
        if let tools = part.tools {
            for tool in tools {
                sendFunctionCall(tool)
            }
        }
        
        // If finish reason received, complete last output
        if part.finishReason != nil {
            completeLastOutput()
            lastOutputPart = .none
        }
    }
    
    /// Received complete LLM message callback (for debugging)
    /// - Parameters:
    ///   - client: LLM client
    ///   - message: Received complete message
    func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage) {
        // Print thinking content and text content for debugging
        if let reason = message.reason {
            print("[R] \(reason)")
        }
        
        if let content = message.content {
            print("[C] \(content)")
        }
    }
    
    /// LLM client error reception callback
    /// - Parameters:
    ///   - client: LLM client
    ///   - error: Error information
    func client(_ client: LLMClient, receiveError error: (any Error)?) {
        // If not connected, stop loading and notify delegate
        if !isConnected {
            MenuBarManager.shared.stopLoading()
            delegate.bridge(connected: false)
            return
        }
        
        // If there's an error, send error event
        if let error = error {
            // Send error event
            let errorEvent = LLMAgenticResponseEvent.error(.init(
                code: "internal_error",
                message: error.localizedDescription,
                param: nil,
                sequenceNumber: sequenceNumber
            ))
            sendEvent(errorEvent)
        }
        
        // Send response completed event
        sendEvent(LLMAgenticResponseEvent.responseCompleted(.init(response: .init(id: id, createdAt: createTime, status: "completed", model: "XcodePaI", output: outputs), sequenceNumber: sequenceNumber)))
        
        // Notify delegate to write end chunk
        delegate.bridgeWriteEndChunk()
        
        // Stop and release LLM client
        llmClient?.stop()
        llmClient = nil
        
        // Stop menu bar loading indicator
        MenuBarManager.shared.stopLoading()
    }
}

// MARK: - Response event sending extension
extension ChatProxyAgenticBridge {
    /// Send thinking content chunk
    /// - Parameter chunk: Thinking content chunk
    private func sendReasonChunk(_ chunk: String?) {
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
                    LLMAgenticResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .reasoning(.init(id: itemId)), sequenceNumber: sequenceNumber)),
                    LLMAgenticResponseEvent.reasoningSummaryPartAdded(.init(itemId: itemId, outputIndex: 0, summaryIndex: 0, part: .init(text: ""), sequenceNumber: sequenceNumber))
                ])
            }
            
            // Send reasoning summary text delta event
            sendEvent(LLMAgenticResponseEvent.reasoningSummaryTextDelta(.init(itemId: itemId, outputIndex: 0, summaryIndex: 0, delta: chunk, sequenceNumber: sequenceNumber)))
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
            sendTextChunk(textContent, true)
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
            sendEvent(LLMAgenticResponseEvent.outputTextDelta(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, delta: endThinkMark, sequenceNumber: sequenceNumber)))
        }
    }
    
    /// Send text content chunk
    /// - Parameters:
    ///   - chunk: Text content chunk
    ///   - fromReasoning: Whether coming from thinking content
    private func sendTextChunk(_ chunk: String?, _ fromReasoning: Bool = false) {
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
                LLMAgenticResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .message(.init(id: itemId, content: [], status: "in_progress")), sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.contentPartAdded(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, part: .outputText(.init(text: "")), sequenceNumber: sequenceNumber))
            ])
        }
        
        // Send output text delta event
        sendEvent(LLMAgenticResponseEvent.outputTextDelta(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, delta: chunk, sequenceNumber: sequenceNumber)))
        lastContent += chunk
    }
    
    /// Send function call
    /// - Parameter toolUse: Tool call object
    private func sendFunctionCall(_ toolUse: LLMMessageToolCall) {
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
            LLMAgenticResponseEvent.outputItemAdded(.init(outputIndex: outputs.count, item: .functionCall(.init(id: itemId, callId: callId, name: name)), sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.functionCallArgumentsDelta(.init(itemId: itemId, outputIndex: outputs.count, delta: arguments, sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.functionCallArgumentsDone(.init(itemId: itemId, name: name, outputIndex: outputs.count, arguments: arguments, sequenceNumber: sequenceNumber)),
            LLMAgenticResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .functionCall(.init(id: itemId, callId: callId, name: name, arguments: arguments)), sequenceNumber: sequenceNumber))
        ])
        
        // Add function call to output array
        outputs.append(.functionCall(.init(id: itemId, callId: callId, name: name, arguments: arguments)))
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
                LLMAgenticResponseEvent.reasoningSummaryTextDone(.init(itemId: itemId, outputIndex: outputs.count, summaryIndex: 0, text: lastContent, sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.reasoningSummaryPartDone(.init(itemId: itemId, outputIndex: outputs.count, summaryIndex: 0, part: .init(text: lastContent), sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .reasoning(.init(id: itemId, content: [.init(text: lastContent)])), sequenceNumber: sequenceNumber))
            ])
            outputs.append(.reasoning(.init(id: itemId, content: [.init(text: lastContent)])))
            lastContent = ""
            lastOutputPart = .none
        case .text:
            sendEvents([
                LLMAgenticResponseEvent.contentPartDone(.init(itemId: itemId, outputIndex: outputs.count, contentIndex: 0, part: .outputText(.init(text: lastContent)), sequenceNumber: sequenceNumber)),
                LLMAgenticResponseEvent.outputItemDone(.init(outputIndex: outputs.count, item: .message(.init(id: itemId, content: [.outputText(.init(text: lastContent))])), sequenceNumber: sequenceNumber))
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

