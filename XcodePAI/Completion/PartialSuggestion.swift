//
//  PartialSuggestion.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/5.
//

import Foundation
import SuggestionBasic
import SuggestionPortal

struct PartialSuggestion {
    let model: LLMModel
    let provider: LLMModelProvider
    
    var maxTokens: Int?
    
    var headers: [String: String]?
}

extension PartialSuggestion: SuggestionPortalProtocol {
    func requestSuggestion(fileURL: URL, originalContent: String, cursorPosition: CursorPosition, prefixContent: String?, suffixContent: String?) async throws -> [CodeSuggestion] {
        MenuBarManager.shared.startLoading()
        defer {
            MenuBarManager.shared.stopLoading()
        }
//        guard let model, let provider else {
//            return []
//        }
        
        print("Code suggestion Request for: \(fileURL)")
        
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
        
        let instruction: String? = await {
            var ret = ""
            if let suggestionContext = await PluginManager.shared.getCodeSuggestionPlugin()?.generateCodeSuggestionsContext(forFile: fileURL, code: originalContent, prefix: prefixContent, suffix: suffixContent), !suggestionContext.isEmpty {
                ret += "\(PromptTemplate.codeSuggestionPartialChatCompletionContextMark)\n\(suggestionContext)"
            }
            if let suffixContent {
                ret += "\(PromptTemplate.codeSuggestionPartialChatCompletionCodeMark)\n\(suffixContent)"
            }
            return ret.isEmpty ? nil : ret
        }()
        
        let completionContent = try await LLMCompletionClient.doPartialCompletionRequest(model, provider: provider, prompt: prefixContent ?? "", system: PromptTemplate.codeSuggestionPartialChatCompletionSystemPrompt.replacingOccurrences(of: "{{LANGUAGE}}", with: language), instruction: instruction, maxTokens: maxTokens, headers: headers)
        
        guard var completionContent, !completionContent.isEmpty else {
            return []
        }
        
        if completionContent.hasSuffix("```") {
            completionContent = completionContent.substring(to: completionContent.count - 3)
        }
        
        completionContent += "\n"
        
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
        
        let suggestion = CodeSuggestion(
            id: UUID().uuidString,
            text: prefix + completionContent,
            position: cursorPosition,
            range: range
        )
        return [suggestion]
    }
}
