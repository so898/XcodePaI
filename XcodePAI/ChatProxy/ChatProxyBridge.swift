//
//  ChatProxyBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/14.
//

import Foundation
import Logger

class ChatProxyBridge: ChatProxyBridgeBase {
    
    private var roleReturned = false
    
    private var mcpTools: [LLMMCPTool]?
    private var mcpToolUses = [LLMMCPToolUse]()
    
    private var currentRequest: LLMRequest?
    private var recordAssistantMessages = [LLMMessage]()
    
    private var responseFixer = ResponseCodeSnippetFixer()
    
    override func receiveRequestData(_ data: Data) {
        guard let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let request = try? LLMRequest(dict: jsonDict) else {
            delegate.bridge(connected: false)
            return
        }
        
        receiveRequest(request)
    }
    
    private func receiveRequest(_ request: LLMRequest) {
        MenuBarManager.shared.startLoading()
        guard let config = StorageManager.shared.getConfig(request.model), let modelProvider = config.getModelProvider() else {
            delegate.bridge(connected: false)
            return
        }
        self.config = config
        currentRequest = request
        
        let newRequest = processRequest(request)
        
        if roleReturned {
            thinkParser = .inContentWithCodeSnippet
        }
        
        createLLMClient(with: config, modelProvider: modelProvider).request(newRequest)
    }
    
    // Process message temp values
    private var lastSearchKeys = [String]()

    private func processRequest(_ request: LLMRequest) -> LLMRequest {
        guard let config = config else {
            return request
        }
        
        mcpTools = config.getTools()
        
        guard let newRequest = try? LLMRequest(dict: request.toDictionary()) else {
            return request
        }

        newRequest.model = config.modelName
        
        let messages = request.messages
        
        var newMessages = [LLMMessage]()
        
        // Find the last user message
        var lastUserMessage: LLMMessage?
        for message in messages {
            if message.role == "user" {
                lastUserMessage = message
            }
        }
        
        for message in messages {
            if let message = processRequestMessage(message, isLastUserMessage: lastUserMessage === message) {
                newMessages.append(message)
            }
        }
        newRequest.messages = newMessages

        if useToolInRequest, let mcpTools = mcpTools {
            var tools = newRequest.tools ?? [LLMTool]()
            for mcpTool in mcpTools {
                tools.append(mcpTool.toRequestTool())
            }
            newRequest.tools = tools
        }
        
        newRequest.streamOptions = LLMStreamOption(includeUsage: true)
        
        return newRequest
    }
    
    // MARK: Request
    private func processRequestMessage(_ message: LLMMessage, isLastUserMessage: Bool = false) -> LLMMessage? {
        
        switch message.role {
        case "developer":
            // Developer Message
            return message
        case "system":
            // System Message
            let content = message.content ?? ""
            return LLMMessage(role: "system", content: processSystemPrompt(content))
        case "assistant":
            // Assistant Message
            if let content = message.content {
                return LLMMessage(role: "assistant", content: processAssistantMessageContent(content))
            } else if let contents = message.contents {
                var newContents = [LLMMessageContent]()
                for content in contents {
                    if content.type == .text, let text = content.text {
                        print("ASSISTANT: \n\(text)")
                        newContents.append(LLMMessageContent(text: processAssistantMessageContent(text)))
                    } else {
                        newContents.append(content)
                    }
                }
                return LLMMessage(role: "assistant", contents: newContents)
            }
            return message
        case "user":
            // User Message
            if let content = message.content {
                return LLMMessage(role: "user", content: processUserMessageContent(content, isLastMessage: isLastUserMessage))
            } else if let contents = message.contents {
                var newContents = [LLMMessageContent]()
                for content in contents {
                    if content.type == .text, let text = content.text {
                        if contents.first === content, !text.contains(PromptTemplate.userPromptToolUseResultDescriptionTemplatePrefix){
                            newContents.append(LLMMessageContent(text: processUserMessageContent(text, isLastMessage: isLastUserMessage)))
                        } else {
                            newContents.append(content)
                        }
                    } else {
                        newContents.append(content)
                    }
                }
                return LLMMessage(role: "user", contents: newContents)
            }
            return message
        default:
            return message
        }
    }
    
    override func processSystemPrompt(_ originSystemPrompt: String) -> String {
        if let chatPlugin = PluginManager.shared.getChatPlugin(), let content = chatPlugin.processSystemPrompt(originSystemPrompt) {
            return content
        }
        
        var systemPrompt = PromptTemplate.systemPrompt
        
        if originSystemPrompt.contains(XcodePromptSearchMark) {
            systemPrompt = systemPrompt.replacingOccurrences(of: "{{XCODE_SEARCH_TOOL}}", with: PromptTemplate.systemPromptXcodeSearchTool)
        } else {
            systemPrompt = systemPrompt.replacingOccurrences(of: "{{XCODE_SEARCH_TOOL}}", with: "")
        }
        
        if !useToolInRequest, let mcpTools = mcpTools, mcpTools.count > 0 {
            systemPrompt = systemPrompt.replacingOccurrences(of: "{{USE_TOOLS}}", with: PromptTemplate.systemPromptToolTemplate)
            let toolsStr: String = {
                var ret = PromptTemplate.systemPromptAvailableToolTemplate
                for mcpTool in mcpTools {
                    ret += mcpTool.toPrompt() + "\n"
                }
                return ret + PromptTemplate.systemPromptAvailableToolTemplateEnd
            }()
            
            systemPrompt = systemPrompt.replacingOccurrences(of: "{{TOOLS}}", with: toolsStr)
        } else {
            systemPrompt = systemPrompt.replacingOccurrences(of: "{{USE_TOOLS}}", with: "")
        }
        
        return systemPrompt
    }
    
    override func processAssistantMessageContent(_ content: String, isLastMessage: Bool = false) -> String {
        
        lastSearchKeys.removeAll()
        
        // Get search key in assistant message
        if content.contains(XcodePromptSearchMark) {
            let lines = content.components(separatedBy: "\n")
            
            for var line in lines {
                if line.hasPrefix(XcodePromptSearchMark) {
                    line = line.replacingOccurrences(of: "\(XcodePromptSearchMark) ", with: "")
                    line = line.replacingOccurrences(of: XcodePromptSearchMark, with: "")
                    lastSearchKeys.append(line)
                }
            }
        }
        
        return super.processAssistantMessageContent(content, isLastMessage: isLastMessage)
    }
        
    override func processUserMessageContent(_ content: String, isLastMessage: Bool = false) -> String {
        var returnContent = content
        
        // Cut search result source code
        if Configer.chatProxyCutSourceInSearchRequest,
           lastSearchKeys.count != 0,
           returnContent.contains(XcodePromptSearchResultMark),
           let sourceCodes = findSourceCodeIn(returnContent), !sourceCodes.isEmpty {
            returnContent = cutAndReplaceSourceIn(returnContent, with: sourceCodes)
        }

        return super.processUserMessageContent(returnContent, isLastMessage: isLastMessage)
    }
    
    private func findSourceCodeIn(_ content: String) -> [SourceCodeInContent]? {
        let parts = content.split(separator: XcodePromptSearchResultMark, maxSplits: 1)
        if parts.count > 1 {
            let sourceCodePart = parts[1]
            
            var sourceCodes = [SourceCodeInContent]()
            
            var codeMarkdownStart = false
            var fileType: String?
            var fileName: String?
            var code = ""
            
            let lines = sourceCodePart.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("```") {
                    if !codeMarkdownStart {
                        // Start of the soruce code
                        if line.count > 3 {
                            let content = line.replacingOccurrences(of: "```", with: "")
                            if content.contains(":") {
                                let contents = content.components(separatedBy: ":")
                                if contents.count == 2 {
                                    fileType = contents[0]
                                    fileName = contents[1]
                                }
                            } else {
                                fileType = content
                            }
                        }
                        
                        codeMarkdownStart = true
                    } else {
                        if !code.isEmpty {
                            sourceCodes.append(SourceCodeInContent(fileType: fileType, fileName: fileName, content: code))
                        }
                        fileType = nil
                        fileName = nil
                        code = ""
                        codeMarkdownStart = false
                    }
                } else if codeMarkdownStart {
                    code.append("\n\(line)")
                }
            }
            
            return sourceCodes.isEmpty ? nil : sourceCodes
        }
        
        return nil
    }
    
    private func cutAndReplaceSourceIn(_ content: String, with sourceCodes: [SourceCodeInContent]) -> String {
        var returnContent = content
        let filterKeys: [FilterKeyword] = {
            var ret = [FilterKeyword]()
            for key in lastSearchKeys {
                ret.append(FilterKeyword(keyword: key, useRegex: true))
            }
            return ret
        }()
        for sourceCode in sourceCodes {
            if !sourceCode.content.isEmpty, let fileType = sourceCode.fileType, let cuttedSource = SourceCutter.cut(source: sourceCode.content, fileType: fileType, filterKeys: filterKeys), !cuttedSource.isEmpty {
                returnContent = returnContent.replacingOccurrences(of: sourceCode.content, with: cuttedSource)
            }
        }
                
        return returnContent
    }
    
    // MARK: LLMClientDelegate
    
    override func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage) {
        if let reason = message.reason {
            Logger.chatProxy.debug("[R] \(reason)")
        }
        
        if var content = message.content {
            Logger.chatProxy.debug("[C] \(content)")
            
            if mcpToolUses.count > 0 {
                for toolUse in mcpToolUses {
                    if let toolUseContent = toolUse.content {
                        content = content.replacingOccurrences(of: toolUseContent, with: "")
                    }
                }
                recordAssistantMessages.append(LLMMessage(role: "assistant", content: content))
            }
        }
    }
    
    override func client(_ client: LLMClient, receiveError error: Error?) {
        super.client(client, receiveError: error)
        
        if let _ = error {
            // Error
            delegate.bridge(write: ["internal_error": "Server error"])
        } else if mcpToolUses.count > 0 {
            // Tool calling
            callToolUses()
            stopLLMClient()
            return
        }
        
        delegate.bridgeWriteEndChunk()
        stopLLMClient()
    }
    
    
    override func sendReasonChunk(_ chunk: String?) {
        guard let chunk else { return }
        if thinkParser == .inReasoningContent {
            sendReason(chunk)
        } else {
            switch thinkState {
            case .notStarted:
                thinkState = .inProgress
                
                if thinkParser == .inContentWithCodeSnippet {
                    let startThinkMark = Configer.chatProxyCodeSnippetPreviewFix ? ThinkInContentWithCodeSnippetStartMarkWithFix : ThinkInContentWithCodeSnippetStartMark
                    let processedChunk = chunk.replacingOccurrences(of: "```", with: "'''")
                    sendContent(startThinkMark + processedChunk)
                } else {
                    sendContent(chunk)
                }
            case .inProgress:
                if thinkParser == .inContentWithCodeSnippet {
                    let processedChunk = chunk.replacingOccurrences(of: "```", with: "'''")
                    sendContent(processedChunk)
                } else {
                    sendContent(chunk)
                }
            case .completed:
                // No reason in this state
                break
            }
        }
    }
    
    override func sendContentChunk(_ chunk: String?, _ fromReasoning: Bool = false) {
        guard let chunk else { return }
        
        if thinkState == .inProgress {
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
            sendContent(endThinkMark + chunk)
        } else {
            sendContent(Configer.chatProxyCodeSnippetPreviewFix ? responseFixer.processMessage(chunk) : chunk)
        }
    }
    
    override func sendFunctionCall(_ toolUse: LLMMessageToolCall) {
        if let toolName = toolUse.function.name {
            processToolUse(LLMMCPToolUse(toolName: toolName, arguments: toolUse.function.arguments))
        }
    }
    
    override func sendFinishReason(_ finishReason: String) {
        guard finishReason != "tool_calls" else {
            return
        }
        writeResponse(LLMResponse(
            id: id,
            model: Constraint.InternalModelName,
            object: "chat.completion.chunk",
            choices: [
                LLMResponseChoice(
                    index: 0,
                    finishReason: finishReason,
                    isFullMessage: false
                )
            ]
        ))
    }
    
    private func sendReason(_ reason: String) {
        writeResponse(LLMResponse(
            id: id,
            model: Constraint.InternalModelName,
            object: "chat.completion.chunk",
            choices: [
                LLMResponseChoice(
                    index: 0,
                    isFullMessage: false,
                    message: LLMResponseChoiceMessage(
                        role: roleReturned ? nil : "assistant",
                        reasoningContent: reason
                    )
                )
            ]
        ))
    }
    
    private func sendContent(_ content: String) {
        writeResponse(LLMResponse(
            id: id,
            model: Constraint.InternalModelName,
            object: "chat.completion.chunk",
            choices: [
                LLMResponseChoice(
                    index: 0,
                    isFullMessage: false,
                    message: LLMResponseChoiceMessage(
                        role: roleReturned ? nil : "assistant",
                        content: content
                    )
                )
            ]
        ))
    }
}

// MARK: Tool use
extension ChatProxyBridge {
    private func processToolUse(_ toolUse: LLMMCPToolUse) {
        guard let mcpTools = mcpTools else {
            return
        }
        
        for mcpTool in mcpTools {
            if toolUse.toolName == mcpTool.toolName {
                toolUse.tool = mcpTool
                mcpToolUses.append(toolUse)
            }
        }
    }
    
    private func callToolUses() {
        Task {[weak self] in
            guard let `self` = self else {
                return
            }
            
            for toolUse in mcpToolUses {
                // Do MCP tool call
                if let tool = toolUse.tool {
                    do {
                        let content = try await MCPRunner.shared.run(mcpName: tool.mcp, toolName: tool.name, arguments: toolUse.arguments)
                        self.sendCallToolResult(toolUse: toolUse, content: content, isError: false)
                    } catch _ {
                        self.sendCallToolResult(toolUse: toolUse, content: nil, isError: true)
                    }
                }
            }
            completeToolUseCalls()
        }
    }
    
    private func sendCallToolResult(toolUse: LLMMCPToolUse, content: String?, isError: Bool = false) {
        guard let tool = toolUse.tool else {
            return
        }
        let respContent = """
                    \(ToolUseInContentStartMark)
                    MCP: \(tool.mcp)
                    Tool: \(tool.name)
                    ARGS: \(toolUse.arguments ?? "NULL")
                    SUCCESS: \(isError ? "False" : "True")
                    RET: \(content ?? "NULL")
                    \(ToolUseInContentEndMark)
                    """
        
        sendContentChunk(respContent)
                
        let recordMessageDescriptionTitle: String = {
            var ret = PromptTemplate.toolUseResultTemplate.replacingOccurrences(of: "{{TOOL_NAME}}", with: tool.toolName)
            if let content, !content.isEmpty {
                ret = ret.replacingOccurrences(of: "{{RESULT}}",
                                             with: content)
            } else {
                ret = ret.replacingOccurrences(of: "{{RESULT}}", with: "")
            }
            return ret
        }()
        
        if useToolInRequest {
            // Follow OpenAI api
            // Ref: https://community.openai.com/t/formatting-assistant-messages-after-tool-function-calls-in-gpt-conversations/535360/3
            recordAssistantMessages.append(contentsOf: [
                LLMMessage(role: "assistant", toolCalls: [toolUse.messageToolCall()]),
                LLMMessage(toolCallId: toolUse.tid ?? "", functionName: toolUse.toolName, content: content ?? ""),
            ])
        } else {
            // Use Cherry Studio format
            recordAssistantMessages.append(contentsOf: [
                LLMMessage(role: "user", contents: [
                    LLMMessageContent(text: recordMessageDescriptionTitle),
                ])
            ])
        }
        
        currentRequest?.messages.append(contentsOf: recordAssistantMessages)
    }
    
    private func completeToolUseCalls() {
        if let request = currentRequest {
            DispatchQueue.main.async {[weak self] in
                guard let `self` = self else {
                    return
                }
                mcpToolUses.removeAll()
                recordAssistantMessages.removeAll()
                receiveRequest(request)
            }
        }
    }
}

// MARK: Response
extension ChatProxyBridge {
    private func writeResponse(_ response: LLMResponse?) {
        if let response = response {
            delegate.bridge(write: response.toDictionary())
            roleReturned = true
        }
    }
}
