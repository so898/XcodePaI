//
//  PrefixSuffixSuggestion.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/6.
//

import Foundation
import SuggestionBasic
import SuggestionPortal

struct PrefixSuffixSuggestion {
    
    let model: LLMModel
    let provider: LLMModelProvider
    
    let inPrompt: Bool
    let hasSuffix: Bool
    let useChatCompletion: Bool
    
    var headers: [String: String]?
}

extension PrefixSuffixSuggestion: SuggestionPortalProtocol {
    func requestSuggestion(fileURL: URL, originalContent: String, cursorPosition: CursorPosition, prefixContent: String?, suffixContent: String?) async throws -> [CodeSuggestion] {
        MenuBarManager.shared.startLoading()
        defer {
            MenuBarManager.shared.stopLoading()
        }
        
        //        guard let model, let provider else {
        //            return []
        //        }
        
        print("Code suggestion Request for: \(fileURL)")
        
        let (id, completionContent): (Int64?, String?) = try await {
            if useChatCompletion {
                // Do chat completion request
                let language: String = {
                    switch languageIdentifierFromFileURL(fileURL) {
                    case .builtIn(let languageId):
                        if !languageId.rawValue.isEmpty {
                            return languageId.rawValue + " "
                        }
                        break
                    case .plaintext:
                        break
                    case .other(_):
                        break
                    }
                    return ""
                }()
                
                let context: String? = await {
                    if let suggestionContext = await PluginManager.shared.getCodeSuggestionPlugin()?.generateCodeSuggestionsContext(forFile: fileURL, code: originalContent, prefix: prefixContent, suffix: suffixContent), !suggestionContext.isEmpty {
                        return suggestionContext
                    }
                    return nil
                }()
                
                let (id, responseContent) = try await LLMCompletionClient.doPromptChatCompletionRequest(model, provider: provider, context: context, prompt: prefixContent ?? "", suffix: hasSuffix ? suffixContent : nil, system: PromptTemplate.codeSuggestionFIMChatCompletionSystemPrompt.replacingOccurrences(of: "{{LANGUAGE}}", with: language), headers: headers)
                
                if let responseContent = responseContent {
                    let (hasCodeBlock, codes) = Utils.extractMarkdownCodeBlocks(from: responseContent)
                    if hasCodeBlock {
                        if let firstCodeBlock = codes.first {
                            return (id, firstCodeBlock)
                        } else {
                            return (id, nil)
                        }
                    }
                }
                
                return (id, responseContent)
            }
            
            let content: String? = await {
                if let prefixContent {
                    var ret = ""
                    if let suggestionContext = await PluginManager.shared.getCodeSuggestionPlugin()?.generateCodeSuggestionsContext(forFile: fileURL, code: originalContent, prefix: prefixContent, suffix: suffixContent), !suggestionContext.isEmpty {
                        ret += "/**\n\(suggestionContext)\n*/\n\n"
                    }
                    ret += prefixContent
                    return ret
                }
                return nil
            }()
            
            if inPrompt {
                return try await LLMCompletionClient.doPromptSuffixCompletionRequest(model, provider: provider, prompt: content ?? "", suffix: hasSuffix ? suffixContent : nil, headers: headers)
            } else {
                return try await LLMCompletionClient.doPromptCompletionRequest(model, provider: provider, prompt: content ?? "", suffix: hasSuffix ? suffixContent : nil, headers: headers)
            }
        }()
                
        guard let completionContent, !completionContent.isEmpty else {
            return []
        }
        let startPosition = CursorPosition(line: cursorPosition.line,
                                           character: 0)
        let endPosition = CursorPosition(line: cursorPosition.line,
                                         character: cursorPosition.character + completionContent.count)
        let range = CursorRange.init(start: startPosition, end: endPosition)
        print("cursor ：\(cursorPosition)，range: \(range)")
        
        let prefix: String = {
            if let prefixContent {
                return prefixContent.substring(from: prefixContent.count - cursorPosition.character)
            }
            return String(repeating: " ", count: cursorPosition.character)
        }()
        
        let codeSuggestionId: String = {
            if let id {
                return "code_completion_\(id)"
            }
            return UUID().uuidString
        }()
        
        let suggestion = CodeSuggestion(
            id: codeSuggestionId,
            text: prefix + completionContent,
            position: cursorPosition,
            range: range
        )
        return [suggestion]
    }
}
