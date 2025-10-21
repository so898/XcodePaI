//
//  ChatProxyBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/14.
//

import Foundation

protocol ChatProxyBridgeDelegate {
    func bridge(_ bridge: ChatProxyBridge, connected success: Bool)
    func bridge(_ bridge: ChatProxyBridge, write dict: [String: Any])
    func bridgeWriteEndChunk(_ bridge: ChatProxyBridge)
}

// Think
enum ThinkState {
    case notStarted
    case inProgress
    case completed
}

enum ThinkParser: Int {
    case inContentWithCodeSnippet = 0
    case inContentWithEOT = 1
    case inReasoningContent = 2
}

let ThinkInContentWithCodeSnippetStartMark = "```think\n\n"
let ThinkInContentWithEOTEndMark = "\n\n~~EOT~~\n\n"
let ThinkInContentWithCodeSnippetEndMark = "\n\n~~EOT~~\n\n```\n\n"

// Tools
enum ToolRequestCheckProcess {
    case none
    case mightFound
    case found
}

let ToolUseStartMark = "<tool_use>"
let ToolUseEndMark = "</tool_use>"

let ToolUseR1StarkMark = "<｜tool▁calls▁begin｜>"
let ToolUseR1EndMark = "<｜tool▁calls▁end｜>"

let ToolUseInContentStartMark = "\n\n```tool_use\n\n"
let ToolUseInContentEndMark = "\n\n~~EOTU~~\n\n```\n\n"

// Xcode Search
let XcodePromptSearchMark = "##SEARCH:"
let XcodePromptSearchResultMark = "Your search results are provided below:"

struct SourceCodeInContent {
    let fileType: String?
    let fileName: String?
    let content: String
}

class ChatProxyBridge {
    
    let id: String
    let delegate: ChatProxyBridgeDelegate
    
    var config: LLMConfig?
    
    private var llmClient: LLMClient?
    private var isConnected = false
    
    private var roleReturned = false
    
    private var thinkParser: ThinkParser = Configer.chatProxyThinkStyle
    private var thinkState: ThinkState = .notStarted
    
    private var mcpTools: [LLMMCPTool]?
    private var useToolInRequest = Configer.chatProxyToolUseInRequest
    private var toolProcesser = ResponseToolProcesser()
    private var mcpToolUses = [LLMMCPToolUse]()
    
    private var currentRequest: LLMRequest?
    private var recordAssistantMessages = [LLMMessage]()
    
    init(id: String, delegate: ChatProxyBridgeDelegate) {
        self.id = id
        self.delegate = delegate

        toolProcesser.getMCPToolUseCall = {[weak self] toolUse in
            guard let `self` = self else { return }
            self.processToolUse(toolUse)
        }
    }
    
    func receiveRequest(_ request: LLMRequest) {
        MenuBarManager.shared.startLoading()
        guard let config = StorageManager.shared.getConfig(request.model), let modelProvider = config.getModelProvider() else {
            delegate.bridge(self, connected: false)
            return
        }
        self.config = config
        
        currentRequest = request
        
        let newRequest = processRequest(request)
        
        // Do LLM request to server, add MCP...
        if roleReturned {
            thinkParser = .inContentWithCodeSnippet
        }
        thinkState = .notStarted
        
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        llmClient = LLMClient(modelProvider, delegate: self)
        llmClient?.request(newRequest)
    }
    
    // Process message temp values
    private var lastSearchKeys = [String]()
}

// MARK: Request
extension ChatProxyBridge {
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
                tools.append(mcpTool.toReqeustTool())
            }
            newRequest.tools = tools
        }
        
        newRequest.streamOptions = LLMStreamOption(includeUsage: true)
        
        return newRequest
    }
    
    private func processRequestMessage(_ message: LLMMessage, isLastUserMessage: Bool = false) -> LLMMessage? {
        
        switch message.role {
        case "developer":
            // Developer Message
            return message
        case "system":
            // System Message
            let content = message.content ?? ""
            
            print("SYSTEM: \n\(content)")
//            
//            print("COVT: \n\(processSystemPrompt(content))")
            
            return LLMMessage(role: "system", content: processSystemPrompt(content))
        case "assistant":
            // Assistant Message
            if let content = message.content {
                print("ASSISTANT: \n\(content)")
                
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
                print("USER: \n\(content)")
                return LLMMessage(role: "user", content: processUserMessageContent(content, isLastUserMessage: isLastUserMessage))
            } else if let contents = message.contents {
                var newContents = [LLMMessageContent]()
                for content in contents {
                    if content.type == .text, let text = content.text {
                        print("USER: \n\(text)")
                        if contents.first === content, !text.contains(PromptTemplate.userPromptToolUseResultDescriptionTemplatePrefix){
                            newContents.append(LLMMessageContent(text: processUserMessageContent(text, isLastUserMessage: isLastUserMessage)))
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
    
    private func processSystemPrompt(_ originSystemPrompt: String) -> String {
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
    
    private func processAssistantMessageContent(_ content: String, isLastUserMessage: Bool = false) -> String {
        var returnContent = content
        
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
        
        if let chatPlugin = PluginManager.shared.getChatPlugin(), let content = chatPlugin.processAssistantPrompt(returnContent, isLast: isLastUserMessage) {
            returnContent = content
        }
        
        // Remove think part in assistant message
        // Process simple because think could only be at the start of content
        if returnContent.substring(to: ThinkInContentWithCodeSnippetStartMark.count) == ThinkInContentWithCodeSnippetStartMark {
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

        // Remove all think parts using code snippet in assistant message
        while returnContent.contains(ThinkInContentWithCodeSnippetStartMark) {
            let firstComponents = returnContent.split(separator: ThinkInContentWithCodeSnippetStartMark, maxSplits: 1)
            if firstComponents.count == 2 {
                let secondComponents = String(firstComponents[1]).split(separator: ThinkInContentWithCodeSnippetEndMark, maxSplits: 1)
                if secondComponents.count == 2 {
                    returnContent = String(firstComponents[0]) + "\n" + String(secondComponents[1])
                }
            }
        }
        
        // Remove all tool use parts in assistant message
        while returnContent.contains(ToolUseInContentStartMark) {
            let firstComponents = returnContent.split(separator: ToolUseInContentStartMark, maxSplits: 1)
            if firstComponents.count == 2 {
                let secondComponents = String(firstComponents[1]).split(separator: ToolUseInContentEndMark, maxSplits: 1)
                if secondComponents.count == 2 {
                    returnContent = String(firstComponents[0]) + "\n\n" + String(secondComponents[1])
                }
            }
        }
        
        return returnContent
    }
        
    private func processUserMessageContent(_ content: String, isLastUserMessage: Bool = false) -> String {
        var returnContent = content
        
        // Plugin
        if let chatPlugin = PluginManager.shared.getChatPlugin(), let content = chatPlugin.processUserPrompt(returnContent, isLast: isLastUserMessage) {
            returnContent = content
        }
        
        // Cut search result source code
        if Configer.chatProxyCutSourceInSearchRequest,
           lastSearchKeys.count != 0,
           returnContent.contains(XcodePromptSearchResultMark),
           let sourceCodes = findSourceCodeIn(returnContent), !sourceCodes.isEmpty {
            returnContent = cutAndReplaceSourceIn(returnContent, with: sourceCodes)
        }
        
        // Force return in language, only for last message
        let forceLanguage = Configer.forceLanguage
        if isLastUserMessage, forceLanguage != .english {
            // Language
            let languageContent: String = {
                switch forceLanguage {
                case .english:
                    return ""
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
}

// MARK: tool use
extension ChatProxyBridge {
    private func processToolUse(_ toolUse: LLMMCPToolUse) {
//        print("Tool Use: \(content)")
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
                        
//                        print("Tool Result[S]: \(content)")
                    } catch _ {
                        self.sendCallToolResult(toolUse: toolUse, content: nil, isError: true)
                        
//                        print("Tool Result[E]: \(error)")
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
        let response = LLMResponse(
            id: id,
            model: "XcodePaI",
            object: "chat.completion.chunk",
            choices: [
                LLMResponseChoice(
                    index: 0,
                    isFullMessage: false,
                    message: LLMResponseChoiceMessage(
                        role: roleReturned ? nil : "assistant",
                        content: respContent
                    )
                )
            ]
        )
        
        writeResponse(response)
        
        let recordMessageDescriptionTitle: String = {
            var ret = PromptTemplate.userPromptToolUseResultDescriptionTemplate.replacingOccurrences(of: "{{TOOL_NAME}}", with: tool.toolName)
            if let arguments = toolUse.arguments, !arguments.isEmpty {
                ret = ret.replacingOccurrences(of: "{{ARGUMENTS}}",
                                             with: PromptTemplate.userPromptToolUseResultDescriptionArgumentsTemplate.replacingOccurrences(of: "{{ARGS_STR}}", with: arguments))
            } else {
                ret = ret.replacingOccurrences(of: "{{ARGUMENTS}}", with: "")
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
                    LLMMessageContent(text: content ?? "")
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
                toolProcesser.reset()
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
            delegate.bridge(self, write: response.toDictionary())
            
            roleReturned = true
        }
    }
}

// MARK: LLMClientDelegate
extension ChatProxyBridge: LLMClientDelegate {
    func clientConnected(_ client: LLMClient) {
        isConnected = true
        delegate.bridge(self, connected: true)
    }
    
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        if toolProcesser.processMessage(part) {
            return
        }

        var response: LLMResponse?
        
        if thinkParser == .inReasoningContent {
            response = LLMResponse(
                id: id,
                model: "XcodePaI",
                object: "chat.completion.chunk",
                choices: [
                    LLMResponseChoice(
                        index: 0,
                        finishReason: part.finishReason,
                        isFullMessage: false,
                        message: LLMResponseChoiceMessage(
                            role: roleReturned ? nil : "assistant",
                            content: toolProcesser.processContent(part.content ?? ""),
                            reasoningContent: part.reason
                        )
                    )
                ]
            )
        } else {
            if let reason = part.reason {
                switch thinkState {
                case .notStarted:
                    thinkState = .inProgress
                    let startThinkMark: String = {
                        switch thinkParser {
                        case .inContentWithCodeSnippet:
                            return ThinkInContentWithCodeSnippetStartMark
                        default:
                            return ""
                        }
                    }()
                    let processedReason = reason.replacingOccurrences(of: "```", with: "'''")
                    response = LLMResponse(
                        id: id,
                        model: "XcodePaI",
                        object: "chat.completion.chunk",
                        choices: [
                            LLMResponseChoice(
                                index: 0,
                                finishReason: part.finishReason,
                                isFullMessage: false,
                                message: LLMResponseChoiceMessage(
                                    role: roleReturned ? nil : "assistant",
                                    content: startThinkMark + processedReason
                                )
                            )
                        ]
                    )
                case .inProgress:
                    let processedReason = reason.replacingOccurrences(of: "```", with: "'''")
                    response = LLMResponse(
                        id: id,
                        model: "XcodePaI",
                        object: "chat.completion.chunk",
                        choices: [
                            LLMResponseChoice(
                                index: 0,
                                finishReason: part.finishReason,
                                isFullMessage: false,
                                message: LLMResponseChoiceMessage(
                                    role: roleReturned ? nil : "assistant",
                                    content: processedReason
                                )
                            )
                        ]
                    )
                case .completed:
                    // No reason in this state
                    break
                }
            } else if var content = part.content {
                content = toolProcesser.processContent(content)
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
                    response = LLMResponse(
                        id: id,
                        model: "XcodePaI",
                        object: "chat.completion.chunk",
                        choices: [
                            LLMResponseChoice(
                                index: 0,
                                finishReason: part.finishReason,
                                isFullMessage: false,
                                message: LLMResponseChoiceMessage(
                                    role: roleReturned ? nil : "assistant",
                                    content: endThinkMark + content
                                )
                            )
                        ]
                    )
                } else {
                    response = LLMResponse(
                        id: id,
                        model: "XcodePaI",
                        object: "chat.completion.chunk",
                        choices: [
                            LLMResponseChoice(
                                index: 0,
                                finishReason: part.finishReason,
                                isFullMessage: false,
                                message: LLMResponseChoiceMessage(
                                    role: roleReturned ? nil : "assistant",
                                    content: content
                                )
                            )
                        ]
                    )
                }
            }
        }
        
        if part.finishReason != nil, mcpToolUses.count > 0 {
            // Wait for MCP tool call complete
            print("Wait for MCP tool call complete")
            return
        }

        writeResponse(response)
    }
    
    func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage) {
        if let reason = message.reason {
            print("[R] \(reason)")
        }
        
        if var content = message.content {
            print("[C] \(content)")
            
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
    
    func client(_ client: LLMClient, receiveError error: Error?) {
        if !isConnected {
            MenuBarManager.shared.stopLoading()
            delegate.bridge(self, connected: false)
            return
        }
        
        if let _ = error {
            // Error
            delegate.bridge(self, write: ["internal_error": "Server error"])
        } else if mcpToolUses.count > 0 {
            // Tool calling
            callToolUses()
            
            llmClient?.stop()
            llmClient = nil
            
            MenuBarManager.shared.stopLoading()
            return
        }
        
        delegate.bridgeWriteEndChunk(self)
        
        llmClient?.stop()
        llmClient = nil
        
        MenuBarManager.shared.stopLoading()
    }
    
}

class ResponseToolProcesser {
    
    private var toolRequestCheck: ToolRequestCheckProcess = .none
    private var maybeToolCallInContent: String = ""
    
    enum StartMarkType {
        case custom
        case r1
    }
    private var startMarkType: StartMarkType = .custom
    
    private var messageToolCalls = [LLMMessageToolCall]()
    
    var getMCPToolUseCall: ((LLMMCPToolUse) -> Void)?
    
    func processMessage(_ message: LLMAssistantMessage) -> Bool {
        if let finishReason = message.finishReason, finishReason == "tool_calls" {
            processToolCalls()
            return true
        }
        if let tools = message.tools, tools.count > 0 {
            messageToolCalls.append(contentsOf: tools)
            return true
        }
        
        return false
    }
    
    private func processToolCalls() {
        var id: String?
        var type: String?
        var functionName: String?
        var arguments: String?
        for toolUse in messageToolCalls {
            if let name = toolUse.function.name {
                if let functionName = functionName {
                    getMCPToolUseCall?(LLMMCPToolUse(toolName: functionName, arguments: arguments, tid: id, type: type))
                }
                id = nil
                type = nil
                functionName = name
                arguments = nil
            }
            if !toolUse.id.isEmpty {
                if id == nil {
                    id = toolUse.id
                } else {
                    id?.append(toolUse.id)
                }
            }
            if let args = toolUse.function.arguments {
                if arguments == nil {
                    arguments = args
                } else {
                    arguments?.append(args)
                }
            }
            if type == nil, !toolUse.type.isEmpty {
                type = toolUse.type
            }
        }
        
        if let functionName = functionName {
            getMCPToolUseCall?(LLMMCPToolUse(toolName: functionName, arguments: arguments, tid: id, type: type))
        }
    }
        
        
    func processContent(_ originalContent: String) -> String {
        var content = originalContent

        switch toolRequestCheck {
        case .none:
            if content.contains("<") {
                toolRequestCheck = .mightFound
                if content.count > 1 {
                    let components = content.split(separator: "<", maxSplits: 1)
                    if components.count == 2 {
                        content = String(components[0])
                        maybeToolCallInContent = "<" + components[1]
                    }
                } else {
                    content = ""
                    maybeToolCallInContent = "<"
                }
            }
            break
        case .mightFound: fallthrough
        case .found:
            maybeToolCallInContent += content
            content = ""
            break
        }
        
        if maybeToolCallInContent.count > 0 {
            if toolRequestCheck == .mightFound {
                if maybeToolCallInContent.contains(">") {
                    var mark = ""
                    let components = maybeToolCallInContent.split(separator: ">", maxSplits: 1)
                    if components.count == 1 {
                        mark = String(components[0]) + ">"
                        maybeToolCallInContent = ""
                    } else if components.count == 2 {
                        mark = String(components[0]) + ">"
                        maybeToolCallInContent = String(components[1])
                    }
                    
                    if !mark.isEmpty {
                        // Found tool use start mark
                        if mark == ToolUseStartMark{
                            startMarkType = .custom
                            toolRequestCheck = .found
                        } else if mark == ToolUseR1StarkMark {
                            startMarkType = .r1
                            toolRequestCheck = .found
                        }
                    }
                    
                    if toolRequestCheck != .found {
                        // Not found start mark means not tool use action
                        content = maybeToolCallInContent + content
                        maybeToolCallInContent = ""
                        toolRequestCheck = .none
                    }
                }
            }
            if toolRequestCheck == .found {
                if startMarkType == .custom, maybeToolCallInContent.contains(ToolUseEndMark) {
                    // Found tool use end mark means tool use action complete
                    let components = maybeToolCallInContent.components(separatedBy: ToolUseEndMark)
                    
                    if let toolUse = try? LLMMCPToolUse(content: components[0]) {
                        getMCPToolUseCall?(toolUse)
                    }
                    
                    content = components[1]
                    maybeToolCallInContent = ""
                    toolRequestCheck = .none
                } else if startMarkType == .r1, maybeToolCallInContent.contains(ToolUseR1EndMark) {
                    let components = maybeToolCallInContent.components(separatedBy: ToolUseR1EndMark)
                    let calls = components[0].components(separatedBy: "<｜tool▁call▁begin｜>")
                    for var callContent in calls {
                        guard !callContent.isEmpty, callContent.contains("<｜tool▁call▁end｜>") else { continue }
                        
                        callContent = callContent.replacingOccurrences(of: "<｜tool▁call▁end｜>", with: "")
                        let lines = callContent.components(separatedBy: "\n")
                        var functionName: String?
                        var arguments: String?
                        for idx in 0..<lines.count {
                            let line = lines[idx]
                            if line.contains("function<｜tool▁sep｜>") {
                                functionName = line.replacingOccurrences(of: "function<｜tool▁sep｜>", with: "")
                            }
                            if line.substring(to: 3) == "```" {
                                continue
                            }
                            if arguments != nil {
                                arguments?.append("\n" + line)
                            } else {
                                var lineContent = line
                                if lineContent.contains("<|") {
                                    let components = lineContent.components(separatedBy: "<|")
                                    lineContent = components[0]
                                }
                                arguments = lineContent
                            }
                        }
                        
                        if let functionName = functionName {
                            getMCPToolUseCall?(LLMMCPToolUse(toolName: functionName, arguments: arguments))
                        }
                    }
                    content = components[1]
                    maybeToolCallInContent = ""
                    toolRequestCheck = .none
                }
            }
        }
        return content
    }
    
    func reset() {
        toolRequestCheck = .none
        maybeToolCallInContent = ""
        messageToolCalls.removeAll()
    }
}
