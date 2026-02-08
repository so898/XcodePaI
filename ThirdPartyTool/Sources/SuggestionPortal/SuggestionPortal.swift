//
//  SuggestionPortal.swift
//  Shared
//
//  Created by Bill Cheng on 2025/9/5.
//

import Foundation
import SuggestionBasic
import Preferences
import Logger

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
    case breakLineFail
    case noSuggestionInMiddle
    
    public var errorDescription: String? {
        switch self {
        case .noPortal:
            return "No portal"
        case .breakLineFail:
            return "Break line fail"
        case .noSuggestionInMiddle:
            return "Suggestion in middle disabled"
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
        
        guard let result else {
            throw SuggestionPortalError.breakLineFail
        }
        
        if !result.endOfLine, !UserDefaults.shared.value(for: \.isSuggestionTypeInTheMiddleEnabled) {
            throw SuggestionPortalError.breakLineFail
        }
        
        try Task.checkCancellation()
        
        return try await current.requestSuggestion(fileURL: fileURL, originalContent: originalContent, cursorPosition: cursorPosition, prefixContent: result.prefixContent, suffixContent: result.suffixContent)
    }
    
    func getContentAroundCursor(in string: String, line: Int, character: Int) -> (prefixContent: String, suffixContent: String, endOfLine: Bool)? {
        let lines = string.components(separatedBy: "\n")
        
        guard line >= 0, line < lines.count else {
            Logger.completion.debug("Invalid line index")
            return nil
        }
        
        let currentLine = lines[line]
        
        guard character >= 0, character <= currentLine.count else {
            Logger.completion.debug("Invalid character index")
            return nil
        }
        
        let prefixContentInCurrentLine = String(currentLine.prefix(character))
        let prefixLines = lines[0..<line].joined(separator: "\n")
        let prefixContent = prefixLines.isEmpty ? prefixContentInCurrentLine : "\(prefixLines)\n\(prefixContentInCurrentLine)"
        
        let suffixContentInCurrentLine = String(currentLine.suffix(currentLine.count - character))
        let suffixLines = lines[(line + 1)...].joined(separator: "\n")
        let suffixContent = suffixContentInCurrentLine.isEmpty ? suffixLines : "\(suffixContentInCurrentLine)\n\(suffixLines)"
        
        return (prefixContent, suffixContent, suffixContentInCurrentLine.isEmpty)
    }
}
