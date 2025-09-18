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
        
        
        let completionContent: String? = try await {
            if inPrompt {
                try await LLMCompletionClient.doPromptSuffixCompletionRequest(model, provider: provider, prompt: content ?? "", suffix: hasSuffix ? suffixContent : nil, headers: headers)
            } else {
                try await LLMCompletionClient.doPromptCompletionRequest(model, provider: provider, prompt: content ?? "", suffix: hasSuffix ? suffixContent : nil, headers: headers)
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
        
        let suggestion = CodeSuggestion(
            id: UUID().uuidString,
            text: prefix + completionContent,
            position: cursorPosition,
            range: range
        )
        return [suggestion]
    }
}
