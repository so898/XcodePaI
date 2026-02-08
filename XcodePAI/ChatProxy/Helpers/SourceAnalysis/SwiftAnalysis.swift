//
//  SwiftAnalysis.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/14.
//

import Foundation

// MARK: - Data Structure Definitions

/// Source code analysis result
struct SwiftSourceAnalysisResult {
    let classes: [SwiftClassInfo]
    
    /// Filter by keyword
    func filter(with keyword: String, useRegex: Bool = false) -> SwiftSourceAnalysisResult {
        return filter(with: [.init(keyword: keyword, useRegex: useRegex)])
    }
    
    func filter(with keywords: [FilterKeyword]) -> SwiftSourceAnalysisResult {
        let filteredClasses = classes.compactMap { $0.filteredCopy(with: keywords) }
        return SwiftSourceAnalysisResult(classes: filteredClasses)
    }
}

/// Class information
struct SwiftClassInfo {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let properties: [SwiftPropertyInfo]
    let methods: [SwiftMethodInfo]
    let sourceRange: Range<String.Index>
    
    /// Check if class name or comments contain the keyword
    func classMatchesKeyword(_ keyword: String, useRegex: Bool) -> Bool {
        return custom_matchesKeyword(keyword, in: name, useRegex: useRegex) ||
        comments.contains { custom_matchesKeyword(keyword, in: $0, useRegex: useRegex) }
    }
    
    /// Create filtered copy
    func filteredCopy(with keyword: String, useRegex: Bool = false) -> SwiftClassInfo? {
        return filteredCopy(with: [.init(keyword: keyword, useRegex: useRegex)])
    }
    
    /// Create filtered copy
    func filteredCopy(with filterkeys: [FilterKeyword]) -> SwiftClassInfo? {
        var classMatches = false
        var markedProperties = properties
        var markedMethods = methods
        
        for filterkey in filterkeys {
            let keyword = filterkey.keyword
            let useRegex = filterkey.useRegex
            
            // Check if class name or comments match keyword
            if !classMatches {
                classMatches = classMatchesKeyword(keyword, useRegex: useRegex)
            }
            
            // Mark related properties and methods
            markedProperties = markedProperties.map { property in
                if !property.isRelated {
                    return property.markedCopy(matchesKeyword: property.matchesKeyword(keyword, useRegex: useRegex))
                }
                return property
            }
            
            markedMethods = markedMethods.map { method in
                if !method.isRelated {
                    return method.markedCopy(matchesKeyword: method.matchesKeyword(keyword, useRegex: useRegex))
                }
                return method
            }
        }
        
        // Check if any members match the keyword
        let hasMatchingMembers = markedProperties.contains { $0.isRelated } ||
        markedMethods.contains { $0.isRelated }
        
        // Keep this class if class name/comments match or if any members match
        guard classMatches || hasMatchingMembers else {
            return nil // Filter out classes with no matches
        }
        
        return SwiftClassInfo(
            name: name,
            fullDeclaration: fullDeclaration,
            comments: comments,
            properties: markedProperties,
            methods: markedMethods,
            sourceRange: sourceRange,
            shouldDisplayFully: classMatches // New: mark whether to display fully
        )
    }
    
    // New: internal initializer supporting full display flag
    init(name: String, fullDeclaration: String, comments: [String], properties: [SwiftPropertyInfo], methods: [SwiftMethodInfo], sourceRange: Range<String.Index>, shouldDisplayFully: Bool) {
        self.name = name
        self.fullDeclaration = fullDeclaration
        self.comments = comments
        // If should display fully, mark all members as related
        self.properties = shouldDisplayFully ?
        properties.map { $0.markedCopy(matchesKeyword: true) } : properties
        self.methods = shouldDisplayFully ?
        methods.map { $0.markedCopy(matchesKeyword: true) } : methods
        self.sourceRange = sourceRange
    }
}

/// Property information
struct SwiftPropertyInfo {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let sourceRange: Range<String.Index>
    let isRelated: Bool
    
    init(name: String, fullDeclaration: String, comments: [String], sourceRange: Range<String.Index>, isRelated: Bool = false) {
        self.name = name
        self.fullDeclaration = fullDeclaration
        self.comments = comments
        self.sourceRange = sourceRange
        self.isRelated = isRelated
    }
    
    func matchesKeyword(_ keyword: String, useRegex: Bool) -> Bool {
        return custom_matchesKeyword(keyword, in: name, useRegex: useRegex) ||
        comments.contains { custom_matchesKeyword(keyword, in: $0, useRegex: useRegex) } ||
        custom_matchesKeyword(keyword, in: fullDeclaration, useRegex: useRegex)
    }
    
    func markedCopy(matchesKeyword: Bool) -> SwiftPropertyInfo {
        return SwiftPropertyInfo(
            name: name,
            fullDeclaration: fullDeclaration,
            comments: comments,
            sourceRange: sourceRange,
            isRelated: matchesKeyword
        )
    }
}

/// Method information
struct SwiftMethodInfo {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let body: String
    let sourceRange: Range<String.Index>
    let isRelated: Bool
    
    init(name: String, fullDeclaration: String, comments: [String], body: String, sourceRange: Range<String.Index>, isRelated: Bool = false) {
        self.name = name
        self.fullDeclaration = fullDeclaration
        self.comments = comments
        self.body = body
        self.sourceRange = sourceRange
        self.isRelated = isRelated
    }
    
    func matchesKeyword(_ keyword: String, useRegex: Bool) -> Bool {
        return custom_matchesKeyword(keyword, in: name, useRegex: useRegex) ||
        comments.contains { custom_matchesKeyword(keyword, in: $0, useRegex: useRegex) } ||
        custom_matchesKeyword(keyword, in: body, useRegex: useRegex) ||
        custom_matchesKeyword(keyword, in: fullDeclaration, useRegex: useRegex)
    }
    
    func markedCopy(matchesKeyword: Bool) -> SwiftMethodInfo {
        return SwiftMethodInfo(
            name: name,
            fullDeclaration: fullDeclaration,
            comments: comments,
            body: body,
            sourceRange: sourceRange,
            isRelated: matchesKeyword
        )
    }
}

// MARK: - Source Code Analyzer (Remains Unchanged)

class SwiftSourceAnalyzer {
    
    /// Analyze Swift source code file
    /// - Parameter filePath: Source file path
    /// - Returns: Analysis result
    func analyzeSourceFile(at filePath: String) throws -> SwiftSourceAnalysisResult {
        let sourceCode = try String(contentsOfFile: filePath, encoding: .utf8)
        return analyzeSourceCode(sourceCode)
    }
    
    /// Analyze Swift source code string
    /// - Parameter sourceCode: Source code content
    /// - Returns: Analysis result
    func analyzeSourceCode(_ sourceCode: String) -> SwiftSourceAnalysisResult {
        var classes: [SwiftClassInfo] = []
        var currentIndex = sourceCode.startIndex
        
        while currentIndex < sourceCode.endIndex {
            if let classInfo = extractNextClass(from: sourceCode, startingAt: &currentIndex) {
                classes.append(classInfo)
            } else {
                break
            }
        }
        
        return SwiftSourceAnalysisResult(classes: classes)
    }
    
    // MARK: - Private Methods
    
    private func extractNextClass(from source: String, startingAt index: inout String.Index) -> SwiftClassInfo? {
        // Find class definition
        guard let classRange = findClassDefinition(in: source, from: index) else {
            return nil
        }
        
        let classContent = String(source[classRange])
        let classStartIndex = classRange.lowerBound
        
        // Extract class name
        guard let className = extractClassName(from: classContent) else {
            index = classRange.upperBound
            return nil
        }
        
        // Extract class declaration
        let classDeclaration = extractClassDeclaration(from: classContent)
        
        // Extract class comments
        let comments = extractCommentsBefore(source: source, position: classStartIndex)
        
        // Extract properties and methods
        let (properties, methods) = extractMembers(from: classContent)
        
        index = classRange.upperBound
        
        return SwiftClassInfo(
            name: className,
            fullDeclaration: classDeclaration,
            comments: comments,
            properties: properties,
            methods: methods,
            sourceRange: classRange,
            shouldDisplayFully: false
        )
    }
    
    private func findClassDefinition(in source: String, from index: String.Index) -> Range<String.Index>? {
        let classKeywords = ["class ", "struct ", "enum "]
        var searchIndex = index
        
        while searchIndex < source.endIndex {
            // Find keywords
            for keyword in classKeywords {
                if let range = source.range(of: keyword, options: [], range: searchIndex..<source.endIndex) {
                    // Check if there are other characters before (avoid matching keywords in comments)
                    if range.lowerBound > source.startIndex {
                        let previousChar = source[source.index(before: range.lowerBound)]
                        if previousChar.isLetter || previousChar.isNumber || previousChar == "_" {
                            searchIndex = range.upperBound
                            continue
                        }
                    }
                    
                    // Found matching class definition start position
                    let classStart = range.lowerBound
                    
                    // Find class definition end position (matching braces)
                    if let classEnd = findMatchingBraceEnd(in: source, from: classStart) {
                        return classStart..<classEnd
                    }
                }
            }
            
            // Move to next character
            searchIndex = source.index(after: searchIndex)
        }
        
        return nil
    }
    
    private func findMatchingBraceEnd(in source: String, from startIndex: String.Index) -> String.Index? {
        var braceCount = 0
        var inString = false
        var inComment = false
        var currentIndex = startIndex
        
        while currentIndex < source.endIndex {
            let char = source[currentIndex]
            
            // Handle string literals
            if char == "\"" && !inComment {
                inString.toggle()
            }
            
            // Handle comments
            if !inString {
                if char == "/" && currentIndex < source.index(before: source.endIndex) {
                    let nextChar = source[source.index(after: currentIndex)]
                    if nextChar == "/" {
                        inComment = true
                    } else if nextChar == "*" {
                        inComment = true
                    }
                }
                
                if inComment && char == "\n" {
                    inComment = false
                }
                
                if char == "*" && currentIndex < source.index(before: source.endIndex) {
                    let nextChar = source[source.index(after: currentIndex)]
                    if nextChar == "/" {
                        inComment = false
                        currentIndex = source.index(after: currentIndex)
                    }
                }
            }
            
            if !inString && !inComment {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        return source.index(after: currentIndex)
                    }
                }
            }
            
            currentIndex = source.index(after: currentIndex)
        }
        
        return nil
    }
    
    private func extractClassName(from classContent: String) -> String? {
        // Improved class name extraction logic, supports modifiers
        let pattern = #"(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)*(?:class|struct|enum)\s+([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: classContent, range: NSRange(classContent.startIndex..., in: classContent)),
              let nameRange = Range(match.range(at: 1), in: classContent) else {
            return nil
        }
        
        return String(classContent[nameRange])
    }
    
    private func extractClassDeclaration(from classContent: String) -> String {
        // Extract class declaration part (until first {)
        if let braceRange = classContent.range(of: "{"),
           let firstNewline = classContent.range(of: "\n", range: classContent.startIndex..<braceRange.lowerBound) {
            return String(classContent[classContent.startIndex..<firstNewline.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return classContent.components(separatedBy: "\n").first ?? classContent
    }
    
    private func extractCommentsBefore(source: String, position: String.Index) -> [String] {
        var comments: [String] = []
        var currentIndex = position
        
        // Search backwards for comments
        while currentIndex > source.startIndex {
            currentIndex = source.index(before: currentIndex)
            let char = source[currentIndex]
            
            if char == "\n" {
                // Check if previous line is a comment
                let lineStart = findLineStart(in: source, from: currentIndex)
                let lineEnd = currentIndex
                let line = String(source[lineStart..<lineEnd]).trimmingCharacters(in: .whitespaces)
                
                if line.hasPrefix("//") {
                    comments.insert(line, at: 0)
                } else if line.hasPrefix("/*") {
                    // Handle multi-line comments
                    if let comment = extractMultiLineComment(in: source, endingAt: lineEnd) {
                        comments.insert(comment, at: 0)
                    }
                } else if !line.isEmpty {
                    // Encountered non-empty non-comment line, stop searching
                    break
                }
            }
        }
        
        return comments
    }
    
    private func findLineStart(in source: String, from index: String.Index) -> String.Index {
        var lineStart = index
        while lineStart > source.startIndex {
            let prevIndex = source.index(before: lineStart)
            if source[prevIndex] == "\n" {
                break
            }
            lineStart = prevIndex
        }
        return lineStart
    }
    
    private func extractMultiLineComment(in source: String, endingAt endIndex: String.Index) -> String? {
        var commentEnd = endIndex
        var commentStart = commentEnd
        
        // Search backwards for comment start
        while commentStart > source.startIndex {
            commentStart = source.index(before: commentStart)
            let substring = String(source[commentStart...commentEnd])
            if substring.hasPrefix("/*") {
                return substring
            }
        }
        
        return nil
    }
    
    private func extractMembers(from classContent: String) -> ([SwiftPropertyInfo], [SwiftMethodInfo]) {
        var properties: [SwiftPropertyInfo] = []
        var methods: [SwiftMethodInfo] = []
        
        let lines = classContent.components(separatedBy: "\n")
        var currentLineIndex = 0
        
        while currentLineIndex < lines.count {
            let line = lines[currentLineIndex].trimmingCharacters(in: .whitespaces)
            
            if isPropertyLine(line) {
                // Extract property
                if let property = extractProperty(from: lines, startingAt: currentLineIndex) {
                    properties.append(property)
                    currentLineIndex += property.fullDeclaration.components(separatedBy: "\n").count
                    continue
                }
            } else if isMethodLine(line) {
                // Extract method
                if let method = extractMethod(from: lines, startingAt: currentLineIndex) {
                    methods.append(method)
                    currentLineIndex += method.fullDeclaration.components(separatedBy: "\n").count +
                    method.body.components(separatedBy: "\n").count
                    continue
                }
            }
            
            currentLineIndex += 1
        }
        
        return (properties, methods)
    }
    
    // Check if line is property line (supports modifiers)
    private func isPropertyLine(_ line: String) -> Bool {
        // Match var or let, possibly with modifiers
        let propertyPattern = #"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+|static\s+|class\s+|final\s+|override\s+|lazy\s+|weak\s+|unowned\s+|@IBOutlet\s+|@IBAction\s+)*(?:var|let)\s+"#
        guard let regex = try? NSRegularExpression(pattern: propertyPattern) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
    
    // Check if line is method line (supports modifiers)
    private func isMethodLine(_ line: String) -> Bool {
        // Match func, init or deinit, possibly with modifiers
        let methodPattern = #"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+|static\s+|class\s+|final\s+|override\s+|@objc\s+|@IBAction\s+)*(?:func|init|deinit)\s+"#
        guard let regex = try? NSRegularExpression(pattern: methodPattern) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
    
    private func extractProperty(from lines: [String], startingAt index: Int) -> SwiftPropertyInfo? {
        var propertyLines: [String] = []
        var currentIndex = index
        
        // Collect property-related lines
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            propertyLines.append(lines[currentIndex]) // Keep original formatting
            
            // Check if ended (semicolon, empty line, or new member starts)
            if line.hasSuffix(";") || line.isEmpty ||
                (currentIndex + 1 < lines.count &&
                 (isPropertyLine(lines[currentIndex + 1]) ||
                  isMethodLine(lines[currentIndex + 1]))) {
                break
            }
            
            // For computed properties, find matching closing brace
            if line.contains("{") {
                var braceCount = 1
                var searchIndex = currentIndex + 1
                
                while searchIndex < lines.count && braceCount > 0 {
                    let searchLine = lines[searchIndex]
                    for char in searchLine {
                        if char == "{" { braceCount += 1 }
                        if char == "}" { braceCount -= 1 }
                    }
                    propertyLines.append(searchLine)
                    if braceCount == 0 { break }
                    searchIndex += 1
                }
                currentIndex = searchIndex
                break
            }
            
            currentIndex += 1
        }
        
        let fullDeclaration = propertyLines.joined(separator: "\n")
        
        // Extract property name - improved version, supports modifiers
        guard let propertyName = extractPropertyName(from: propertyLines.first ?? "") else {
            return nil
        }
        
        // Extract comments
        let comments = extractCommentsBefore(from: lines, at: index)
        
        return SwiftPropertyInfo(
            name: propertyName,
            fullDeclaration: fullDeclaration,
            comments: comments,
            sourceRange: fullDeclaration.startIndex..<fullDeclaration.endIndex,
            isRelated: false // Initialize as false, mark later during filtering
        )
    }
    
    // Improved property name extraction, supports modifiers
    private func extractPropertyName(from line: String) -> String? {
        // Match first identifier (property name) after var or let
        let pattern = #"(?:var|let)\s+(?:[A-Za-z_][A-Za-z0-9_]*\s+)*([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        
        return String(line[nameRange])
    }
    
    private func extractMethod(from lines: [String], startingAt index: Int) -> SwiftMethodInfo? {
        var methodLines: [String] = []
        var currentIndex = index
        var braceCount = 0
        var foundBodyStart = false
        
        // Collect method declaration and body
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            methodLines.append(lines[currentIndex]) // Keep original formatting
            
            // Count braces
            for char in line {
                if char == "{" {
                    braceCount += 1
                    foundBodyStart = true
                } else if char == "}" {
                    braceCount -= 1
                }
            }
            
            // If method body found and braces are balanced
            if foundBodyStart && braceCount == 0 {
                break
            }
            
            currentIndex += 1
        }
        
        let fullContent = methodLines.joined(separator: "\n")
        
        // Separate declaration and body
        guard let bodyStartIndex = fullContent.range(of: "{") else {
            return nil
        }
        
        let declaration = String(fullContent[..<bodyStartIndex.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = String(fullContent[bodyStartIndex.lowerBound...])
        
        // Extract method name - improved version, supports modifiers
        guard let methodName = extractMethodName(from: declaration) else {
            return nil
        }
        
        // Extract comments
        let comments = extractCommentsBefore(from: lines, at: index)
        
        return SwiftMethodInfo(
            name: methodName,
            fullDeclaration: declaration,
            comments: comments,
            body: body,
            sourceRange: fullContent.startIndex..<fullContent.endIndex,
            isRelated: false // Initialize as false, mark later during filtering
        )
    }
    
    // Improved method name extraction, supports modifiers
    private func extractMethodName(from declaration: String) -> String? {
        if declaration.hasPrefix("init") {
            return "init"
        } else if declaration.hasPrefix("deinit") {
            return "deinit"
        } else {
            // Match first identifier (method name) after func
            let pattern = #"func\s+(?:[A-Za-z_][A-Za-z0-9_]*\s+)*([A-Za-z_][A-Za-z0-9_]*)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: declaration, range: NSRange(declaration.startIndex..., in: declaration)),
                  let nameRange = Range(match.range(at: 1), in: declaration) else {
                return nil
            }
            
            return String(declaration[nameRange])
        }
    }
    
    private func extractCommentsBefore(from lines: [String], at index: Int) -> [String] {
        var comments: [String] = []
        var currentIndex = index - 1
        
        while currentIndex >= 0 {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") {
                comments.insert(line, at: 0)
            } else if !line.isEmpty {
                break
            }
            currentIndex -= 1
        }
        
        return comments
    }
}

// MARK: - Code Generator (Remains Unchanged)

class SwiftCodeGenerator {
    
    /// Regenerate source code from analysis result
    /// - Parameter result: Analysis result
    /// - Returns: Regenerated source code
    func generateCode(from result: SwiftSourceAnalysisResult) -> String {
        var generatedCode = ""
        
        for classInfo in result.classes {
            generatedCode += generateClassCode(from: classInfo) + "\n\n"
        }
        
        return generatedCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateClassCode(from classInfo: SwiftClassInfo) -> String {
        var code = ""
        
        // Add class comments
        for comment in classInfo.comments {
            code += comment + "\n"
        }
        
        // Add class declaration
        code += classInfo.fullDeclaration + " {\n"
        
        // Add properties
        for property in classInfo.properties {
            code += generatePropertyCode(from: property) + "\n\n"
        }
        
        // Add methods
        for method in classInfo.methods {
            code += generateMethodCode(from: method) + "\n\n"
        }
        
        code += "}"
        
        return code
    }
    
    private func generatePropertyCode(from property: SwiftPropertyInfo) -> String {
        var code = ""
        
        // Add property comments
        for comment in property.comments {
            code += "    " + comment + "\n"
        }
        
        if property.isRelated {
            // Related property: keep complete
            let declarationLines = property.fullDeclaration.components(separatedBy: "\n")
            for line in declarationLines {
                code += "    " + line + "\n"
            }
        } else {
            // Unrelated property: keep only declaration, replace implementation with ...
            let simplifiedDeclaration = simplifyPropertyDeclaration(property.fullDeclaration)
            code += "    " + simplifiedDeclaration + " { ... }"
        }
        
        return code
    }
    
    private func generateMethodCode(from method: SwiftMethodInfo) -> String {
        var code = ""
        
        // Add method comments
        for comment in method.comments {
            code += "    " + comment + "\n"
        }
        
        if method.isRelated {
            // Related method: keep complete declaration and body
            code += "    " + method.fullDeclaration + " " + method.body
        } else {
            // Unrelated method: keep only declaration, replace body with ...
            code += "    " + method.fullDeclaration + " {\n        ...\n    }"
        }
        
        return code
    }
    
    /// Simplify property declaration, remove initialization values and other implementation details
    private func simplifyPropertyDeclaration(_ declaration: String) -> String {
        var simplified = declaration
        
        // Remove initialization assignment
        if let equalRange = simplified.range(of: " = ") {
            simplified = String(simplified[..<equalRange.lowerBound])
        }
        
        // Remove getter/setter implementation
        if let braceRange = simplified.range(of: " {") {
            simplified = String(simplified[..<braceRange.lowerBound])
        }
        
        // Remove trailing semicolon
        simplified = simplified.trimmingCharacters(in: .whitespaces)
        if simplified.hasSuffix(";") {
            simplified = String(simplified.dropLast())
        }
        
        return simplified.trimmingCharacters(in: .whitespaces)
    }
}
