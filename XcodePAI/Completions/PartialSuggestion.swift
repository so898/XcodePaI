//
//  PartialSuggestion.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/5.
//

import Foundation
import SuggestionBasic
import SuggestionPortal

class PartialSuggestion {
    
    let model: LLMModel
    let provider: LLMModelProvider
    
    init(_ model: LLMModel, _ provider: LLMModelProvider) {
        self.model = model
        self.provider = provider
    }
}

extension PartialSuggestion: SuggestionPortalProtocol {
    func requestSuggestion(fileURL: URL, originalContent: String, cursorPosition: CursorPosition, prefixContent: String?, suffixContent: String?) async throws -> [CodeSuggestion] {
        
//        guard let model, let provider else {
//            return []
//        }
        
        let completionContent = try await LLMCompletionClient.doPartialCompletionRequest(model, provider: provider, prompt: prefixContent ?? "")
        
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
