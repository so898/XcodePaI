//
//  SuggestionPortal.swift
//  Shared
//
//  Created by Bill Cheng on 2025/9/5.
//

import Foundation
import SuggestionBasic

public protocol SuggestionPortalProtocol {
    func requestSuggestion(fileURL: URL,
                           originalContent: String,
                           cursorPosition: CursorPosition,
                           prefixContent: String?,
                           suffixContent: String?)
    async throws -> [CodeSuggestion]
}

public enum SuggestionPortalError: Error, LocalizedError {
    case noPortal
    
    public var errorDescription: String? {
        switch self {
        case .noPortal:
            return "No portal"
        }
    }
}

public class SuggestionPortal {
    
    @MainActor public static let shared = SuggestionPortal()
    
    public var current: SuggestionPortalProtocol?
    
    public func requestSuggestion(fileURL: URL,
                           originalContent: String,
                           cursorPosition: CursorPosition)
    async throws -> [CodeSuggestion]
    {
        guard let current else {
            throw SuggestionPortalError.noPortal
        }
        
        try Task.checkCancellation()
        
        let result = self.getContentAroundCursor(in: originalContent,
                                                 line: cursorPosition.line,
                                                 character: cursorPosition.character)
        
        try Task.checkCancellation()
        
        return try await current.requestSuggestion(fileURL: fileURL, originalContent: originalContent, cursorPosition: cursorPosition, prefixContent: result?.prefixContent, suffixContent: result?.suffixContent)
    }
    
    func getContentAroundCursor(in string: String, line: Int, character: Int) -> (prefixContent: String, suffixContent: String)? {
        let lines = string.components(separatedBy: "\n")
        
        guard line >= 0, line < lines.count else {
            print("Invalid line index")
            return nil
        }
        
        let currentLine = lines[line]
        
        guard character >= 0, character <= currentLine.count else {
            print("Invalid character index")
            return nil
        }
        
        let prefixContentInCurrentLine = String(currentLine.prefix(character))
        let prefixLines = lines[0..<line].joined(separator: "\n")
        let prefixContent = prefixLines.isEmpty ? prefixContentInCurrentLine : "\(prefixLines)\n\(prefixContentInCurrentLine)"
        
        let suffixContentInCurrentLine = String(currentLine.suffix(currentLine.count - character))
        let suffixLines = lines[(line + 1)...].joined(separator: "\n")
        let suffixContent = suffixContentInCurrentLine.isEmpty ? suffixLines : "\(suffixContentInCurrentLine)\n\(suffixLines)"
        
        return (prefixContent, suffixContent)
    }
}
