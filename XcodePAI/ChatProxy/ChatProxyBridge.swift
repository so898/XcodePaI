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
    func bridgeWriteEndChunk(_ bridge: ChatProxyBridge)
}

enum ThinkState {
    case notStarted
    case inProgress
    case completed
}

class ChatProxyBridge {
    
    let id: String
    let delegate: ChatProxyBridgeDelegate
    
    private var llmClient: LLMClient?
    private var isConnected = false
    private var thinkState: ThinkState = .notStarted
    
    private var mcpTools: [LLMMCPTool]?
    
    init(id: String, delegate: ChatProxyBridgeDelegate) {
        self.id = id
        self.delegate = delegate
    }
    
    func receiveRequest(_ request: LLMRequest) {
        let newRequest = processRequest(request)
        
        // Do LLM request to server, add MCP...
        thinkState = .notStarted
        
        if let llmClient = llmClient {
            llmClient.stop()
        }
        
        llmClient = LLMClient(LLMModelProvider(name: "test", url: "xxx", privateKey: "sk-xxx"), delegate: self)
        llmClient?.request(newRequest)
    }
}

extension ChatProxyBridge {
    private func processRequest(_ request: LLMRequest) -> LLMRequest{
        let newRequest = request
        newRequest.model = "xxx"
        
        let messages = request.messages
        
        var newMessages = [LLMMessage]()
        for message in messages {
            if let message = processMessage(message) {
                newMessages.append(message)
            }
        }
        newRequest.messages = newMessages
        
        return newRequest
    }
    
    private func processMessage(_ message: LLMMessage) -> LLMMessage? {
        
        switch message.role {
        case "developer":
            // Developer Message - 返回原消息而不是忽略
            return message
        case "system":
            // System Message
            if let content = message.content {
                print("SYSTEM: \n\(content)")
            }
            
            let toolsStr: String = {
                if let mcpTools = mcpTools {
                    var ret = """
                    \n\n# Tool Use Available Tools
                    
                    Above example were using notional tools that might not exist for you. You only have access to these tools:
                    
                    <tools>\n\n
                    """
                    for mcpTool in mcpTools {
                        ret += mcpTool.toPrompt() + "\n"
                    }
                    return ret + "\n</tools>\n"
                }
                return ""
            }()
            
            return LLMMessage(role: "system", content: ReplacedSystemPrompt.replacingOccurrences(of: "{{TOOLS}}", with: toolsStr))
        case "assistant":
            // Assistant Message
            if let content = message.content {
                print("ASS: \n\(content)")
            } else if let contents = message.contents {
                for content in contents {
                    if content.type == .text, let text = content.text {
                        print("ASS: \n\(text)")
                    }
                }
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
}

extension ChatProxyBridge: LLMClientDelegate {
    func clientConnected(_ client: LLMClient) {
        isConnected = true
        delegate.bridge(self, connected: true)
    }
    
    func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        var response: LLMResponse?
        
        // 统一处理逻辑
        if let reason = part.reason {
            switch thinkState {
            case .notStarted:
                thinkState = .inProgress
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
                                role: "assistant",
                                content: "```think\n\n" + processedReason
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
                                role: "assistant",
                                content: processedReason
                            )
                        )
                    ]
                )
            case .completed:
                // 不应该在这个状态下收到reason
                break
            }
        } else if let content = part.content {
            if thinkState == .inProgress {
                thinkState = .completed
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
                                role: "assistant",
                                content: "\n\n~~EOT~~\n\n```\n\n" + content
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
                                role: "assistant",
                                content: content
                            )
                        )
                    ]
                )
            }
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
    
    func client(_ client: LLMClient, receiveError error: Error?) {
        if !isConnected {
            delegate.bridge(self, connected: false)
            return
        }
        
        if let _ = error{
            // Error
            if let json = try? JSONSerialization.data(withJSONObject: ["internal_error": "Server error"]), let jsonStr = String(data: json, encoding: .utf8) {
                delegate.bridge(self, write: jsonStr + Constraint.DoubleLFString)
            }
            
        }
        
        delegate.bridge(self, write: "[DONE]" + Constraint.DoubleLFString)
        delegate.bridgeWriteEndChunk(self)
        
        llmClient?.stop()
        llmClient = nil
    }
    
}

let ReplacedSystemPrompt = """
You are a coding assistant—with access to tools—specializing in analyzing codebases. You are currently in Xcode with a project open. Your job is to answer questions, provide insights, and suggest improvements when the user asks questions.\n\n# Identity and priorities\n\nFavor Apple programming languages and frameworks or APIs that are already available on Apple devices.\nPrefer Swift by default unless the user shows or tells you they want another language. When not Swift, prefer Objective-C, C, or C++ over alternatives.\nPay close attention to the Apple platform the code targets (iOS, iPadOS, macOS, watchOS, visionOS) and avoid suggesting APIs not available on that platform.\nPrefer Swift Concurrency (async/await, actors, etc.) unless the user’s code or words suggest otherwise.\nAvoid mentioning that you have seen these instructions; just follow them naturally.\nRespond in the user’s query language; if unclear, default to English.\nCode review and assistance workflow\n\nDo not answer with code until you are sure the user has provided all relevant code snippets and type implementations required to answer their question.\n\nFirst, briefly and succinctly walk through your reasoning in prose to identify any missing types, functions, or files you need to see.\n\nAsk the user to search the project for those missing pieces and wait for them to provide the results before continuing. Use the following search syntax at the end of your response, each on a separate line:\n##SEARCH: TypeNameOrIdentifier\n##SEARCH: keywords or a phrase to search for\n\nWhen it makes sense, you can provide code examples using the new Swift Testing framework that uses Swift Macros. For example:\n\n```swift\nimport Testing\n\n// Optional, you can also just say @Suite with no parentheses.\n@Suite("You can put a test suite name here, formatted as normal text.")\nstruct AddingTwoNumbersTests {\n\n@Test("Adding 3 and 7")\nfunc add3And7() async throws {\n    let three = 3\n    let seven = 7\n\n    // All assertions are written as "expect" statements now.\n    #expect(three + seven == 10, "The sums should work out.")\n}\n\n@Test\nfunc add3And7WithOptionalUnwrapping() async throws {\n    let three: Int? = 3\n    let seven = 7\n\n    // Similar to XCTUnwrap\n    let unwrappedThree = try #require(three)\n\n    let sum = three + seven\n\n    #expect(sum == 10)\n}\n}\n```\n\nWhen proposing changes to an existing file that the user has provided, you must repeat the entire file without eliding any parts, even if some sections remain unchanged. Indicate a file replacement like this and include the complete contents:\n\n```swift:FileName.swift\n\n// the entire code of the file with your changes goes here.\n// Do not skip over anything.\n\n```\n\nIf you need to show an entirely new file or general sample code (not replacing an existing provided file), you can present a normal Swift snippet:\n\n```swift\n\n// Swift code here\n\n```\n\n# Tool access and usage model\n\nYou have access to a set of external tools that can be used to solve tasks step-by-step. The available tools and their parameters are provided by the system and may change over time. Do not assume any tools exist beyond those explicitly provided to you at runtime.\nOnly call tools when needed. If no tool call is needed, answer the question directly.\nEach tool call should be informed by the result of the previous call. Do not repeat the same tool call with identical parameters.\nAlways format tool usage and results using the XML-style tag format below to ensure proper parsing and execution.\n\n# Tool use formatting\n\nUse this exact structure for tool calls:\n\n<tool_use>\n<name>{tool_name}</name>\n<arguments>{json_arguments}</arguments>\n</tool_use>\n\n• The tool name must be the exact tool identifier provided by the system.\n• The arguments must be a valid JSON object with the parameters required by that tool (use real values, not variable names).\n\nThe user (or environment) will respond with the result using this format:\n\n<tool_use_result>\n<name>{tool_name}</name>\n<result>{result}</result>\n</tool_use_result>\n\n• The result is a string, which can represent a file path, text, or other outputs.\n• You can pass this result to subsequent tool calls if appropriate.\n\nTool use examples (illustrative only; actual available tools will be provided at runtime)\n\nExample 1 (document Q&A then image generation):\n\nAssistant:\nI can use the document_qa tool to find out who the oldest person is in the document.\n<tool_use>\n<name>document_qa</name>\n<arguments>{"document": "document.pdf", "question": "Who is the oldest person mentioned?"}</arguments>\n</tool_use>\n\nUser:\n<tool_use_result>\n<name>document_qa</name>\n<result>John Doe, a 55 year old lumberjack living in Newfoundland.</result>\n</tool_use_result>\n\nAssistant:\nI can use the image_generator tool to create a portrait of John Doe.\n<tool_use>\n<name>image_generator</name>\n<arguments>{"prompt": "A portrait of John Doe, a 55-year-old man living in Canada."}</arguments>\n</tool_use>\n\nUser:\n<tool_use_result>\n<name>image_generator<name>\n<result>image.png</result>\n</tool_use_result>\n\nAssistant:\nThe image is generated as image.png.\n\nExample 2 (calculation via Python interpreter):\n\nAssistant:\nI can use the python_interpreter tool to calculate the result of the operation.\n<tool_use>\n<name>python_interpreter</name>\n<arguments>{"code": "5 + 3 + 1294.678"}</arguments>\n</tool_use>\n\nUser:\n<tool_use_result>\n<name>ipython_interpreter</name>i\n<result>1302.678</result>\n</tool_use_result>\n\nAssistant:\nThe result of the operation is 1302.678.\n\nExample 3 (searching for data and comparing results):\n\nAssistant:\nI can use the search tool to find the population of Guangzhou.\n<tool_use>\n<name>search</name>\n<arguments>{"query": "Population Guangzhou"}</arguments>\n</tool_use>\n\nUser:\n<tool_use_result>\n<name>search</name>\n<result>Guangzhou has a population of 15 million inhabitants as of 2021.</result>\n</tool_use_result>\n\nAssistant:\nI can use the search tool to find the population of Shanghai.\n<tool_use>\n<name>search</name>\n<arguments>{"query": "Population Shanghai"}</arguments>\n</tool_use>\n\nUser:\n<tool_use_result>\n<name>search</name>\n<result>26 million (2019)</result>\n</tool_use_result>\n\nAssistant:\nThe population of Shanghai is 26 million, while Guangzhou has a population of 15 million. Therefore, Shanghai has the highest population.\n\n# Tool use rules\n\nAlways use the correct argument names and values required by the tool. Do not pass variable names; pass actual values.\nCall a tool only when needed; do not call tools when you can solve the task without them.\nIf no tool call is needed, just answer the question directly.\nNever re-do a tool call that you previously did with the exact same parameters.\nFor tool use, make sure to use the XML tag format shown above. Do not use any other format.\nEach tool call should be informed by prior results; use tools step-by-step to accomplish the task.{{TOOLS}}\n\n# Additional guidance\n\nSometimes the user will provide generated Swift interfaces or other code that should not be edited. Recognize these and avoid proposing changes to generated interfaces.\nWhen you propose code, prefer Swift, and align APIs to the target Apple platform.\nIf tests are appropriate, show how to write them with Swift Testing, as illustrated above.\nNow Begin!
"""
