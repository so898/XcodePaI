//
//  ChatProxyBaseBridge.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/9.
//

import Foundation
import Logger

/// Abstract base class for chat proxy bridges
/// Contains shared functionality for processing messages and handling common operations
/// Subclasses should override specific methods to handle different request/response formats
/// Contains only the most basic shared functionality
class ChatProxyBridgeBase: LLMClientDelegate {
    
    // MARK: - Basic Properties
    
    /// Unique identifier for the bridge instance
    let id: String
    
    /// Delegate for communication with the tunnel
    let delegate: ChatProxyBridgeDelegate
    
    /// LLM configuration
    var config: LLMConfig?
    
    /// LLM client for making requests
    private(set) var llmClient: LLMClient?
    
    /// Connection status
    private(set) var isConnected = false
    
    /// Thinking content parsing method (in content, with code snippets, with EOT markers, etc.)
    var thinkParser: ThinkParser = Configer.chatProxyThinkStyle
    
    /// Thinking state, used to track whether currently processing thinking content
    var thinkState: ThinkState = .notStarted
    
    /// Whether to use tools (function calls) in requests
    var useToolInRequest = Configer.chatProxyToolUseInRequest
    
    // MARK: - Initialization
    
    /// Initialize the bridge base
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - delegate: Bridge delegate
    init(id: String, delegate: ChatProxyBridgeDelegate) {
        self.id = id
        self.delegate = delegate
    }
    
    /// Destructor, ensures LLM client is stopped when deallocated
    deinit {
        llmClient?.stop()
        llmClient = nil
    }
    
    // MARK: - Abstract Methods (to be implemented by subclasses)
    
    /// Receive and process a request
    /// - Parameter request: The request to process
    func receiveRequestData(_ data: Data) {
        fatalError("Subclasses must implement receiveRequestData")
    }
    
    /// Stop the current operation
    func stop() {
        stopLLMClient()
        MenuBarManager.shared.stopLoading()
    }
    
    func stopLLMClient() {
        llmClient?.stop()
        llmClient = nil
    }
    
    // MARK: - Message Processing Methods
    
    /// Process system prompt before sending to LLM
    /// - Parameter originSystemPrompt: Original system prompt
    /// - Returns: Processed system prompt
    open func processSystemPrompt(_ originSystemPrompt: String) -> String {
        return originSystemPrompt
    }
    
    /// Process assistant message content to remove thinking parts
    /// - Parameters:
    ///   - content: Original assistant message content
    ///   - isLastMessage: Whether this is the last message in conversation
    /// - Returns: Processed content with thinking parts removed
    open func processAssistantMessageContent(_ content: String, isLastMessage: Bool = false) -> String {
        var returnContent = content
        
        if let chatPlugin = PluginManager.shared.getChatPlugin(), let content = chatPlugin.processAssistantPrompt(returnContent, isLast: isLastMessage) {
            returnContent = content
        }
        
        // Remove think part in assistant message
        // Process simple because think could only be at the start of content
        if returnContent.count > ThinkInContentWithCodeSnippetStartMark.count,
            returnContent.substring(to: ThinkInContentWithCodeSnippetStartMark.count) == ThinkInContentWithCodeSnippetStartMark {
            let components = returnContent.split(separator: ThinkInContentWithCodeSnippetEndMark, maxSplits: 1)
            if components.count == 2 {
                returnContent = String(components[1])
            }
        } else if returnContent.count > ThinkInContentWithCodeSnippetStartMarkWithFix.count,
                    returnContent.substring(to: ThinkInContentWithCodeSnippetStartMarkWithFix.count) == ThinkInContentWithCodeSnippetStartMarkWithFix {
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
        
        // Remove all think parts using code snippet in assistant message with fix
        while returnContent.contains(ThinkInContentWithCodeSnippetStartMarkWithFix) {
            let firstComponents = returnContent.split(separator: ThinkInContentWithCodeSnippetStartMarkWithFix, maxSplits: 1)
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
        
        // Remove all tool use parts in assistant message with fix
        while returnContent.contains(ToolUseInContentStartMarkWithFix) {
            let firstComponents = returnContent.split(separator: ToolUseInContentStartMarkWithFix, maxSplits: 1)
            if firstComponents.count == 2 {
                let secondComponents = String(firstComponents[1]).split(separator: ToolUseInContentEndMark, maxSplits: 1)
                if secondComponents.count == 2 {
                    returnContent = String(firstComponents[0]) + "\n\n" + String(secondComponents[1])
                }
            }
        }
        
        return returnContent
    }
    
    /// Process user message content, including plugin processing and language forcing
    /// - Parameters:
    ///   - content: Original user message content
    ///   - isLastMessage: Whether this is the last user message in the conversation
    /// - Returns: Processed user message content
    open func processUserMessageContent(_ content: String, isLastMessage: Bool = false) -> String {
        var returnContent = content
        
        // Plugin processing
        if let chatPlugin = PluginManager.shared.getChatPlugin(),
            let processedContent = chatPlugin.processUserPrompt(returnContent, isLast: isLastMessage) {
            returnContent = processedContent
        }
        
        // Force language for last message
        if isLastMessage {
            let forceLanguage = Configer.forceLanguage
            let languageContent: String = {
                switch forceLanguage {
                case .english: return PromptTemplate.FLEnglish
                case .chinese: return PromptTemplate.FLChinese
                case .french: return PromptTemplate.FLFrance
                case .russian: return PromptTemplate.FLRussian
                case .japanese: return PromptTemplate.FLJapanese
                case .korean: return PromptTemplate.FLKorean
                }
            }()
            
            if !languageContent.isEmpty {
                return returnContent + "\n" + languageContent
            }
        }
        
        return returnContent
    }
    
    // MARK: - Common Helper Methods
    
    /// Create and configure LLM client
    /// - Parameters:
    ///   - modelProvider: The model provider to use
    ///   - requestHandler: The delegate to handle responses
    func createLLMClient(with config: LLMConfig, modelProvider: LLMModelProvider) -> LLMClient {
        thinkState = .notStarted
        
        if let existingClient = llmClient {
            existingClient.stop()
        }
        
        let newClient = LLMClient(modelProvider, delegate: self)
        llmClient = newClient
        return newClient
    }

    // MARK: - LLMClientDelegate - LLM client delegate implementation
    
    /// LLM client connection successful callback
    /// - Parameter client: Connected LLM client
    public func clientConnected(_ client: LLMClient) {
        isConnected = true
        delegate.bridge(connected: true)
    }
    
    /// Received LLM response part callback
    /// - Parameters:
    ///   - client: LLM client
    ///   - part: Received partial response
    public func client(_ client: LLMClient, receivePart part: LLMAssistantMessage) {
        // Send thinking chunk
        sendReasonChunk(part.reason)
        // Send text chunk
        sendContentChunk(part.content)
        // Send function calls
        if let tools = part.tools {
            for tool in tools {
                sendFunctionCall(tool)
            }
        }
        // If finish reason received
        if let finishReason = part.finishReason {
            // Write finish reason
            sendFinishReason(finishReason)
        }
    }
    
    /// Received complete LLM message callback (for debugging)
    /// - Parameters:
    ///   - client: LLM client
    ///   - message: Received complete message
    public func client(_ client: LLMClient, receiveMessage message: LLMAssistantMessage) {
        if let reason = message.reason {
            Logger.chatProxy.debug("[R] \(reason)")
        }
        
        if let content = message.content {
            Logger.chatProxy.debug("[C] \(content)")
        }
    }
    
    
    public func client(_ client: LLMClient, receiveError error: Error?) {
        MenuBarManager.shared.stopLoading()
        
        // If not connected, stop loading and notify delegate
        if !isConnected {
            delegate.bridge(connected: false)
            return
        }
        
        // .. other action by subclasses
    }
    
    // MARK: Response

    /// Send thinking content chunk
    /// - Parameter chunk: Thinking content chunk
    func sendReasonChunk(_ chunk: String?) {
        fatalError("sendReasonChunk(_:) not implemented.")
    }
    
    /// Send text content chunk
    /// - Parameters:
    ///   - chunk: Text content chunk
    ///   - fromReasoning: Whether coming from thinking content
    func sendContentChunk(_ chunk: String?, _ fromReasoning: Bool = false) {
        fatalError("sendContentChunk(_:_:) not implemented.")
    }
    
    /// Send function call
    /// - Parameter toolUse: Tool call object
    func sendFunctionCall(_ toolUse: LLMMessageToolCall) {
        fatalError("sendFunctionCall(_:) not implemented.")
    }
    
    /// Send finish reason
    /// - Parameter finishReason: Finish reason string
    func sendFinishReason(_ finishReason: String) {
        fatalError("sendFinishReason(_:) not implemented.")
    }
}
