//
//  ChatProxyClaudeBridge.swift
//  XcodePAI
//
//  Created by Codex on 2026/2/9.
//

import Foundation

/// A bridge class that handles communication between the Claude LLM API and the internal chat proxy system.
/// This class translates Claude-specific request/response formats to the generic LLM interface used internally.
class ChatProxyClaudeBridge: ChatProxyBridgeBase {
    
    // MARK: - Properties
    
    /// Tracks the current index of content blocks being processed in the response stream.
    /// Used to maintain proper ordering and indexing of content blocks in the Claude response format.
    private var outputIndex = 0
    
    /// Enum representing the different types of content blocks that can be received from the LLM.
    /// Used to manage state transitions during streaming response processing.
    private enum OutputBlockType {
        case none          ///< No active content block
        case thinking      ///< Processing thinking/reasoning content
        case text          ///< Processing regular text content
        case toolUse       ///< Processing tool/function call content
    }
    
    /// Current state tracking what type of content block is being processed.
    private var currentBlockType: OutputBlockType = .none
    
    private var modelName = ""
    
    // MARK: - Request Processing
    
    override func receiveRequestData(_ data: Data) {
        // Try to decode as Claude request
        guard let request = try? JSONDecoder().decode(LLMClaudeRequest.self, from: data) else {
            delegate.bridge(connected: false)
            return
        }
        
        receiveRequest(request)
    }
    
    private func receiveRequest(_ request: LLMClaudeRequest) {
        MenuBarManager.shared.startLoading()
        // Get config
        guard let config = StorageManager.shared.defaultConfig(), let modelProvider = config.getModelProvider() else {
            delegate.bridge(connected: false)
            return
        }
        self.config = config
        
        // Reset state
        outputIndex = 0
        currentBlockType = .none
        thinkState = .notStarted
        hasToolUse = false
        
        modelName = request.model
        
        // Process request
        let newRequest = processRequest(request)
        
        // Send request
        createLLMClient(with: config, modelProvider: modelProvider).request(newRequest)
    }
    
    private func processRequest(_ request: LLMClaudeRequest) -> LLMRequest {
        guard let config = config else {
            return LLMRequest(model: "", messages: []) // Should not happen
        }
        
        var messages = [LLMMessage]()
        
        // Handle system prompt
        if let systems = request.system {
            for system in systems {
                if let text = system.text {
                    messages.append(LLMMessage(role: "system", content: processSystemPrompt(text)))
                }
            }
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
        
        // Convert request.messages to internal LLMMessage
        // Process each Claude message, collecting tool_use and tool_result within same message
        var toolUseIds = Set<String>()
        var toolUseResultIds = Set<String>()
        
        for (index, msg) in request.messages.enumerated() {
            // Collect tool calls within this single Claude message for proper grouping
            var pendingToolCalls = [LLMMessageToolCall]()
            var pendingToolUsePrompts = [String]()
            
            for (contentIdx, content) in msg.content.enumerated() {
                switch content.type {
                case "text":
                    // Flush any pending tool calls before adding text content
                    if useToolInRequest && !pendingToolCalls.isEmpty {
                        messages.append(LLMMessage(role: "assistant", toolCalls: pendingToolCalls))
                        pendingToolCalls.removeAll()
                    } else if !useToolInRequest && !pendingToolUsePrompts.isEmpty {
                        messages.append(LLMMessage(role: "assistant", content: pendingToolUsePrompts.joined(separator: "\n")))
                        pendingToolUsePrompts.removeAll()
                    }
                    
                    if let text = content.text {
                        var processedText = text
                        if msg.role == "user" {
                            processedText = processUserMessageContent(text, isLastMessage: (index == request.messages.count - 1 && contentIdx == msg.content.count - 1))
                        } else if msg.role == "assistant" {
                            processedText = processAssistantMessageContent(text, isLastMessage: false)
                        }
                        if !processedText.isEmpty {
                            messages.append(LLMMessage(role: msg.role, content: processedText))
                        }
                    }
                case "thinking":
                    // Claude Code sends back previous thinking blocks; skip them
                    // as they are internal reasoning and should not be forwarded
                    break
                case "image":
                    if let source = content.source {
                        let dataUri = "data:\(source.mediaType);base64,\(source.data)"
                        messages.append(LLMMessage(role: msg.role, contents: [LLMMessageContent(imageUrl: dataUri)]))
                    }
                case "tool_use":
                    if let id = content.id, let name = content.name, !toolUseIds.contains(id) {
                        toolUseIds.insert(id)
                        let arguments: String
                        if let input = content.input,
                           let data = try? JSONEncoder().encode(input),
                           let str = String(data: data, encoding: .utf8) {
                            arguments = str
                        } else {
                            arguments = "{}"
                        }
                        
                        if useToolInRequest {
                            // Collect tool calls to merge into single assistant message
                            pendingToolCalls.append(LLMMessageToolCall(id: id, type: "function", function: LLMFunction(name: name, arguments: arguments)))
                        } else {
                            var toolUse = PromptTemplate.toolUseTemplate
                            toolUse = toolUse.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                            toolUse = toolUse.replacingOccurrences(of: "{{ARGUMENTS}}", with: arguments)
                            pendingToolUsePrompts.append(toolUse)
                        }
                    }
                case "tool_result":
                    // Flush any pending tool calls before processing tool results
                    if useToolInRequest && !pendingToolCalls.isEmpty {
                        messages.append(LLMMessage(role: "assistant", toolCalls: pendingToolCalls))
                        pendingToolCalls.removeAll()
                    } else if !useToolInRequest && !pendingToolUsePrompts.isEmpty {
                        messages.append(LLMMessage(role: "assistant", content: pendingToolUsePrompts.joined(separator: "\n")))
                        pendingToolUsePrompts.removeAll()
                    }
                    
                    if let toolUseId = content.toolUseId, !toolUseResultIds.contains(toolUseId) {
                        toolUseResultIds.insert(toolUseId)
                        let name: String = {
                            for msg in request.messages {
                                for content in msg.content {
                                    if content.type == "tool_use", let id = content.id, id == toolUseId {
                                        return content.name ?? ""
                                    }
                                }
                            }
                            return ""
                        }()
                        let result: String = {
                            // tool_result content can be a string, an array of content objects, or nil
                            if let contentStr = content.content?.value as? String {
                                return contentStr
                            } else if let contentArr = content.content?.value as? [Any] {
                                // Array of content objects - extract text from each
                                return contentArr.compactMap { item -> String? in
                                    if let dict = item as? [String: Any] {
                                        return dict["text"] as? String
                                    }
                                    return nil
                                }.joined(separator: "\n")
                            } else if let contentText = content.text {
                                return contentText
                            }
                            return ""
                        }()
                        
                        if useToolInRequest {
                            messages.append(LLMMessage(toolCallId: toolUseId, functionName: name, content: result))
                        } else {
                            var toolUseResult = PromptTemplate.toolUseResultTemplate
                            toolUseResult = toolUseResult.replacingOccurrences(of: "{{TOOL_NAME}}", with: name)
                            toolUseResult = toolUseResult.replacingOccurrences(of: "{{RESULT}}", with: result)
                            messages.append(LLMMessage(role: "user", content: toolUseResult))
                        }
                    }
                default:
                    break
                }
            }
            
            // Flush any remaining pending tool calls at end of message
            if useToolInRequest && !pendingToolCalls.isEmpty {
                messages.append(LLMMessage(role: "assistant", toolCalls: pendingToolCalls))
            } else if !useToolInRequest && !pendingToolUsePrompts.isEmpty {
                messages.append(LLMMessage(role: "assistant", content: pendingToolUsePrompts.joined(separator: "\n")))
            }
        }
        
        // Handle tools definition
        var tools: [LLMTool]? = nil
        if useToolInRequest, let requestTools = request.tools {
            tools = requestTools.compactMap { tool in
                let schemaString: String
                if let data = try? JSONEncoder().encode(tool.inputSchema), let str = String(data: data, encoding: .utf8) {
                    schemaString = str
                } else {
                    schemaString = "{}"
                }
                return LLMTool(type: "function", function: LLMFunction(name: tool.name, description: tool.description, parameters: schemaString))
            }
        }
        
        return LLMRequest(
            model: config.modelName,
            messages: messages,
            stream: request.stream ?? true,
            usage: true,
            tools: tools,
            temperature: request.temperature.map { Float($0) },
            topP: request.topP.map { Float($0) },
            enableThinking: Configer.chatProxyEnableThink
        )
    }
    
    // MARK: - Response Handling
    override func client(_ client: LLMClient, receiveError error: (any Error)?) {
        super.client(client, receiveError: error)
        
        // If there's an error, send error event
        if let error = error {
            // Send error event
            sendEvent(.error(.init(error: .init(type: "internal_error", message: error.localizedDescription))))
        }
        
        delegate.bridgeWriteEndChunk()
        
        // Stop and release LLM client
        stopLLMClient()
    }
    
    override func sendFirstChunk() {
        guard !firstChunkSend else {
            return
        }
        super.sendFirstChunk()
        
        let message = LLMClaudeMessageResponse(
            id: "msg_" + UUID().uuidString,
            type: "message",
            role: "assistant",
            content: [],
            model: modelName,
            stopReason: nil,
            stopSequence: nil,
            usage: LLMClaudeUsageResponse(inputTokens: nil, outputTokens: nil)
        )
        sendEvent(.messageStart(MessageStartEvent(message: message)))
    }
    
    override func sendReasonChunk(_ chunk: String?) {
        guard let chunk, !chunk.isEmpty else { return }
        
        // Process thinking content based on thinking parsing method
        if thinkParser == .inReasoningContent {
            if currentBlockType != .thinking {
                if currentBlockType != .none {
                    sendEvent(.contentBlockStop(ContentBlockStopEvent(index: outputIndex)))
                    outputIndex += 1
                }
                
                sendEvent(.contentBlockStart(ContentBlockStartEvent(index: outputIndex, contentBlock: LLMClaudeContentBlockResponse(type: "thinking", text: nil, thinking: "", id: nil, name: nil, input: nil))))
                currentBlockType = .thinking
            }
            sendEvent(.contentBlockDelta(ContentBlockDeltaEvent(index: outputIndex, delta: LLMClaudeDeltaResponse(type: "thinking_delta", text: nil, thinking: chunk, partialJson: nil))))
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
            sendEvent(.contentBlockDelta(ContentBlockDeltaEvent(index: outputIndex, delta: LLMClaudeDeltaResponse(type: "text_delta", text: endThinkMark, thinking: nil, partialJson: nil))))
            
        }
    }
    
    override func sendContentChunk(_ chunk: String?, _ fromReasoning: Bool = false) {
        guard let chunk = chunk, !chunk.isEmpty else { return }
        
        // If not from thinking content, send thinking end marker
        if !fromReasoning {
            sendReasonEndMarkIfNeed()
        }
        
        if currentBlockType != .text {
            if currentBlockType != .none {
                sendEvent(.contentBlockStop(ContentBlockStopEvent(index: outputIndex)))
                outputIndex += 1
            }
            
            sendEvent(.contentBlockStart(ContentBlockStartEvent(index: outputIndex, contentBlock: LLMClaudeContentBlockResponse(type: "text", text: "", thinking: nil, id: nil, name: nil, input: nil))))
            currentBlockType = .text
        }
        
        sendEvent(.contentBlockDelta(ContentBlockDeltaEvent(index: outputIndex, delta: LLMClaudeDeltaResponse(type: "text_delta", text: chunk, thinking: nil, partialJson: nil))))
    }
    
    /// Track if tool was used, for determining stop reason
    private var hasToolUse = false
    
    override func sendFunctionCall(_ toolUse: LLMMessageToolCall) {
        sendReasonEndMarkIfNeed()
        
        guard let name = toolUse.function.name else { return }
        let arguments = toolUse.function.arguments ?? "{}"
        
        if currentBlockType != .none {
            sendEvent(.contentBlockStop(ContentBlockStopEvent(index: outputIndex)))
            outputIndex += 1
        }
        
        currentBlockType = .toolUse
        hasToolUse = true
        let toolId = toolUse.id.isEmpty ? "toolu_" + UUID().uuidString : toolUse.id
        
        // Claude API streaming format for tool_use content_block_start:
        // { "type": "tool_use", "id": "...", "name": "...", "input": {} }
        // NOTE: input field MUST be an empty object {} in content_block_start
        // The actual input is sent incrementally via input_json_delta events
        sendEvent(.contentBlockStart(ContentBlockStartEvent(index: outputIndex, contentBlock: LLMClaudeContentBlockResponse(type: "tool_use", text: nil, thinking: nil, id: toolId, name: name, input: [:]))))
        
        sendEvent(.contentBlockDelta(ContentBlockDeltaEvent(index: outputIndex, delta: LLMClaudeDeltaResponse(type: "input_json_delta", text: nil, thinking: nil, partialJson: arguments))))
        
        sendEvent(.contentBlockStop(ContentBlockStopEvent(index: outputIndex)))
        outputIndex += 1
        currentBlockType = .none
    }
    
    override func sendFinishReason(_ finishReason: String) {
        sendReasonEndMarkIfNeed()
        
        var reason = finishReason
        
        if currentBlockType != .none {
            sendEvent(.contentBlockStop(ContentBlockStopEvent(index: outputIndex)))
            currentBlockType = .none
        }
        
        // Use hasToolUse flag to determine stop reason, since currentBlockType is already reset to .none after tool use
        if hasToolUse {
            reason = "tool_calls"
        }
        
        let mappedReason: String
        switch reason {
        case "stop": mappedReason = "end_turn"
        case "length": mappedReason = "max_tokens"
        case "tool_calls", "function_call": mappedReason = "tool_use"
        default: mappedReason = finishReason
        }
        
        sendEvent(.messageDelta(MessageDeltaEvent(delta: LLMClaudeMessageDeltaResponse(stopReason: mappedReason, stopSequence: nil), usage: LLMClaudeUsageResponse(inputTokens: nil, outputTokens: nil))))
        
        sendEvent(.messageStop(MessageStopEvent()))
    }
    
    // MARK: - Helpers
    
    private func sendEvent(_ event: LLMClaudeResponseEvent) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(event), let str = String(data: data, encoding: .utf8) {
            let eventStr = getEventType(event)
            print("sm.pro: [\(eventStr)] \(str)")
            delegate.bridge(event: eventStr, data: str)
        }
    }
    
    private func getEventType(_ event: LLMClaudeResponseEvent) -> String {
        switch event {
        case .messageStart: return "message_start"
        case .contentBlockStart: return "content_block_start"
        case .contentBlockDelta: return "content_block_delta"
        case .contentBlockStop: return "content_block_stop"
        case .messageDelta: return "message_delta"
        case .messageStop: return "message_stop"
        case .ping: return "ping"
        case .error: return "error"
        }
    }
}
