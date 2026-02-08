//
//  SourceAnalysisShared.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/14.
//

import Foundation

// MARK: - Data Structure Definition
public struct FilterKeyword {
    let keyword: String
    var useRegex: Bool = false
}

// MARK: - Utility Functions
/// Keyword matching utility function
public func custom_matchesKeyword(_ keyword: String, in text: String, useRegex: Bool) -> Bool {
    if useRegex {
        guard let regex = try? NSRegularExpression(pattern: keyword) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    } else {
        return text.lowercased().contains(keyword.lowercased())
    }
}
