//
//  SuggestionTester.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/9/7.
//

import Foundation
import SuggestionPortal
import SuggestionBasic

class SuggestionTester {
    
    private static let originContent = """
        struct Main {
            /// Compare Integer
            /// parameters:
            /// - first: First Integer
            /// - second: Second Integer
            /// Return: First integer is greater than second integer
            func compare(_ first: Int, _ second: Int) -> Bool {
                var ret = false
                
                return ret
            }
        }
        """
    
    private static let position = CursorPosition(line: 8, character: 8)
    
    private static let prefixContent = """
        struct Main {
            /// Compare Integer
            /// parameters:
            /// - first: First Integer
            /// - second: Second Integer
            /// Return: First integer is greater than second integer
            func compare(_ first: Int, _ second: Int) -> Bool {
                var ret = false
                
        """
    
    private static let suffixContent = """
                return ret
            }
        }
        """
    
    @MainActor
    static func run(_ config: LLMCompletionConfig) async -> (String, String, String)? {
        guard let suggest = config.getSuggestion() else {
            return nil
        }
        
        let result = try? await suggest.requestSuggestion(fileURL: URL(string: "file://test.swift")!, originalContent: originContent, cursorPosition: position, prefixContent: prefixContent, suffixContent: suffixContent)
        
        if let suggetsion = result?.first {
            return (prefixContent.substring(to: prefixContent.count - 9), suggetsion.text.substring(to: suggetsion.text.count - 1), suffixContent)
        }
        
        return nil
    }
}
