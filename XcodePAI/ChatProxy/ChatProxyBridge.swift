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

enum ThinkState {
    case notStarted
    case inProgress
    case completed
}

enum ThinkParser {
    case inReasoningContent
    case inContentWithEOT
    case inContentWithCodeSnippet
}

let ThinkInContentWithCodeSnippetStartMark = "```think\n\n"
let ThinkInContentWithEOTEndMark = "\n\n~~EOT~~\n\n"
let ThinkInContentWithCodeSnippetEndMark = "\n\n~~EOT~~\n\n```\n\n"

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

class ChatProxyBridge {
    
    let id: String
    let delegate: ChatProxyBridgeDelegate
    
    private var llmClient: LLMClient?
    private var isConnected = false
    
    private var roleReturned = false
    
    private var thinkParser: ThinkParser = .inReasoningContent
    private var thinkState: ThinkState = .notStarted
    
    private var mcpTools: [LLMMCPTool]?
    private var useToolInRequest = false
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
        currentRequest = request
        
        let newRequest = processRequest(request)
        
        // Do LLM request to server, add MCP...
        if !roleReturned {
            thinkParser = .inContentWithCodeSnippet
        }
        thinkState = .notStarted
        
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        llmClient = LLMClient(LLMModelProvider(name: "test", url: "xxx", privateKey: "sk-xxx"), delegate: self)
        llmClient?.request(newRequest)
    }
}

// MARK: Request
extension ChatProxyBridge {
    private func processRequest(_ request: LLMRequest) -> LLMRequest {
        let newRequest = request
        newRequest.model = "xxx"
        
        let messages = request.messages
        
        var newMessages = [LLMMessage]()
        for message in messages {
            if let message = processRequestMessage(message) {
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
        
        return newRequest
    }
    
    private func processRequestMessage(_ message: LLMMessage) -> LLMMessage? {
        
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
            } else if let contents = message.contents {
                for content in contents {
                    if content.type == .text, let text = content.text {
                        print("USER: \n\(text)")
                    }
                }
            }
            return message
        default:
            return message
        }
    }
    
    private func processSystemPrompt(_ originSystemPrompt: String) -> String {
        var systemPrompt = PromptTemplate.systemPrompt
        
        if originSystemPrompt.contains("##SEARCH:") {
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
    
    private func processAssistantMessageContent(_ content: String) -> String {
        var returnContent = content
        
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
        
        recordAssistantMessages.append(contentsOf: [
            LLMMessage(role: "user", contents: [
                LLMMessageContent(text: recordMessageDescriptionTitle),
                LLMMessageContent(text: content ?? "")
            ])
        ])
        
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
            
            return
        }
        
        delegate.bridgeWriteEndChunk(self)
        
        llmClient?.stop()
        llmClient = nil
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
        var functionName: String?
        var arguments: String?
        for toolUse in messageToolCalls {
            if let name = toolUse.function.name {
                if let functionName = functionName {
                    getMCPToolUseCall?(LLMMCPToolUse(toolName: functionName, arguments: arguments))
                }
                functionName = name
                arguments = nil
            }
            if let args = toolUse.function.arguments {
                if arguments == nil {
                    arguments = args
                } else {
                    arguments?.append(args)
                }
            }
        }
        
        if let functionName = functionName {
            getMCPToolUseCall?(LLMMCPToolUse(toolName: functionName, arguments: arguments))
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
                    
                    let toolUse = LLMMCPToolUse(content: components[0])
                    getMCPToolUseCall?(toolUse)
                    
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
    }
}
