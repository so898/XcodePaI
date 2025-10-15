//
//  ObjcAnalysis.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/14.
//

import Foundation
// MARK: - Objective-C Data Structure Definitions
/// Objective-C source code analysis result
struct ObjCSourceAnalysisResult {
    let interfaces: [ObjCInterfaceInfo]
    let implementations: [ObjCImplementationInfo]
    
    /// Filter by keyword
    func filter(with keyword: String, useRegex: Bool = false) -> ObjCSourceAnalysisResult {
        let filteredInterfaces = interfaces.compactMap { $0.filteredCopy(with: keyword, useRegex: useRegex) }
        let filteredImplementations = implementations.compactMap { $0.filteredCopy(with: keyword, useRegex: useRegex) }
        return ObjCSourceAnalysisResult(interfaces: filteredInterfaces, implementations: filteredImplementations)
    }
    
    func filter(with filterKeys: [FilterKeyword]) -> ObjCSourceAnalysisResult {
        let filteredInterfaces = interfaces.compactMap { $0.filteredCopy(with: filterKeys) }
        let filteredImplementations = implementations.compactMap { $0.filteredCopy(with: filterKeys) }
        return ObjCSourceAnalysisResult(interfaces: filteredInterfaces, implementations: filteredImplementations)
    }
}
/// Objective-C interface information (@interface in .h files)
struct ObjCInterfaceInfo {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let properties: [ObjCPropertyInfo]
    let methods: [ObjCMethodInfo]
    let sourceRange: Range<String.Index>
    
    /// Check if interface name or comments contain the keyword
    func interfaceMatchesKeyword(_ keyword: String, useRegex: Bool) -> Bool {
        return custom_matchesKeyword(keyword, in: name, useRegex: useRegex) ||
        comments.contains { custom_matchesKeyword(keyword, in: $0, useRegex: useRegex) }
    }
    
    /// Create filtered copy
    func filteredCopy(with keyword: String, useRegex: Bool = false) -> ObjCInterfaceInfo? {
        return filteredCopy(with: [.init(keyword: keyword, useRegex: useRegex)])
    }
    
    func filteredCopy(with filterKeys: [FilterKeyword]) -> ObjCInterfaceInfo? {
        var filteredProperties: [ObjCPropertyInfo] = []
        var filteredMethods: [ObjCMethodInfo] = []
        
        for filterKey in filterKeys {
            let keyword = filterKey.keyword
            let useRegex = filterKey.useRegex
            
            // If interface name or comments match, keep all members
            if interfaceMatchesKeyword(keyword, useRegex: useRegex) {
                return ObjCInterfaceInfo(
                    name: name,
                    fullDeclaration: fullDeclaration,
                    comments: comments,
                    properties: properties,
                    methods: methods,
                    sourceRange: sourceRange
                )
            } else {
                // Otherwise only keep matching members
                filteredProperties.append(contentsOf: properties.filter { $0.matchesKeyword(keyword, useRegex: useRegex) })
                filteredMethods.append(contentsOf: methods.filter { $0.matchesKeyword(keyword, useRegex: useRegex) })
                
                
            }
        }
        
        // Keep interface if name/comments match or if any member matches
        guard !filteredProperties.isEmpty || !filteredMethods.isEmpty else {
            return nil
        }
        
        let properties: Set<ObjCPropertyInfo> = Set(filteredProperties)
        let methods: Set<ObjCMethodInfo> = Set(filteredMethods)
        
        return ObjCInterfaceInfo(
            name: name,
            fullDeclaration: fullDeclaration,
            comments: comments,
            properties: Array(properties),
            methods: Array(methods),
            sourceRange: sourceRange
        )
    }
}
/// Objective-C implementation information (@implementation in .m files)
struct ObjCImplementationInfo {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let methods: [ObjCMethodInfo]
    let sourceRange: Range<String.Index>
    
    /// Create filtered copy
    func filteredCopy(with keyword: String, useRegex: Bool = false) -> ObjCImplementationInfo? {
        return filteredCopy(with: [.init(keyword: keyword, useRegex: useRegex)])
    }
    
    func filteredCopy(with filterKeys: [FilterKeyword]) -> ObjCImplementationInfo? {
        
        var filteredMethods = [ObjCMethodInfo]()
        
        for filterKey in filterKeys {
            let keyword = filterKey.keyword
            let useRegex = filterKey.useRegex
            
            // Filter methods
            filteredMethods.append(contentsOf: methods.filter { $0.matchesKeyword(keyword, useRegex: useRegex) })
            
            // Filter out implementation if no methods match
            guard !filteredMethods.isEmpty else {
                continue
            }
        }
        
        guard !filteredMethods.isEmpty else {
            return nil
        }
        
        let methods: Set<ObjCMethodInfo> = Set(filteredMethods)
        
        return ObjCImplementationInfo(
            name: name,
            fullDeclaration: fullDeclaration,
            comments: comments,
            methods: Array(methods),
            sourceRange: sourceRange
        )
    }
}
/// Objective-C property information
struct ObjCPropertyInfo: Hashable {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let sourceRange: Range<String.Index>
    
    func matchesKeyword(_ keyword: String, useRegex: Bool) -> Bool {
        return custom_matchesKeyword(keyword, in: name, useRegex: useRegex) ||
        comments.contains { custom_matchesKeyword(keyword, in: $0, useRegex: useRegex) } ||
        custom_matchesKeyword(keyword, in: fullDeclaration, useRegex: useRegex)
    }
}
/// Objective-C method information
struct ObjCMethodInfo: Hashable {
    let name: String
    let fullDeclaration: String
    let comments: [String]
    let body: String?
    let sourceRange: Range<String.Index>
    
    func matchesKeyword(_ keyword: String, useRegex: Bool) -> Bool {
        return custom_matchesKeyword(keyword, in: name, useRegex: useRegex) ||
        comments.contains { custom_matchesKeyword(keyword, in: $0, useRegex: useRegex) } ||
        custom_matchesKeyword(keyword, in: fullDeclaration, useRegex: useRegex) ||
        (body != nil && custom_matchesKeyword(keyword, in: body!, useRegex: useRegex))
    }
}
// MARK: - Objective-C Header Analyzer
class ObjCHeaderAnalyzer {
    
    /// Analyze Objective-C header file
    /// - Parameter filePath: Header file path
    /// - Returns: Analysis result
    func analyzeHeaderFile(at filePath: String) throws -> ObjCSourceAnalysisResult {
        let sourceCode = try String(contentsOfFile: filePath, encoding: .utf8)
        return analyzeHeaderCode(sourceCode)
    }
    
    /// Analyze Objective-C header code
    /// - Parameter sourceCode: Header file content
    /// - Returns: Analysis result
    func analyzeHeaderCode(_ sourceCode: String) -> ObjCSourceAnalysisResult {
        let interfaces = extractAllInterfaces(from: sourceCode)
        // Header files only contain interfaces, no implementations
        return ObjCSourceAnalysisResult(interfaces: interfaces, implementations: [])
    }
    
    // MARK: - Private Methods
    
    private func extractAllInterfaces(from source: String) -> [ObjCInterfaceInfo] {
        var interfaces: [ObjCInterfaceInfo] = []
        var currentIndex = source.startIndex
        
        while currentIndex < source.endIndex {
            if let interfaceInfo = extractNextInterface(from: source, startingAt: &currentIndex) {
                interfaces.append(interfaceInfo)
            } else {
                break
            }
        }
        
        return interfaces
    }
    
    private func extractNextInterface(from source: String, startingAt index: inout String.Index) -> ObjCInterfaceInfo? {
        // Find @interface definition
        guard let interfaceRange = findInterfaceDefinition(in: source, from: index) else {
            return nil
        }
        
        let interfaceContent = String(source[interfaceRange])
        let interfaceStartIndex = interfaceRange.lowerBound
        
        // Extract interface name
        guard let interfaceName = extractInterfaceName(from: interfaceContent) else {
            index = interfaceRange.upperBound
            return nil
        }
        
        // Extract interface declaration
        let interfaceDeclaration = extractInterfaceDeclaration(from: interfaceContent)
        
        // Extract interface comments
        let comments = extractCommentsBefore(source: source, position: interfaceStartIndex)
        
        // Extract properties and methods
        let (properties, methods) = extractInterfaceMembers(from: interfaceContent)
        
        index = interfaceRange.upperBound
        
        return ObjCInterfaceInfo(
            name: interfaceName,
            fullDeclaration: interfaceDeclaration,
            comments: comments,
            properties: properties,
            methods: methods,
            sourceRange: interfaceRange
        )
    }
    
    private func findInterfaceDefinition(in source: String, from index: String.Index) -> Range<String.Index>? {
        let interfaceKeyword = "@interface"
        var searchIndex = index
        
        while searchIndex < source.endIndex {
            if let range = source.range(of: interfaceKeyword, options: [], range: searchIndex..<source.endIndex) {
                // Found @interface start position
                let interfaceStart = range.lowerBound
                
                // Find @interface end position (@end)
                if let interfaceEnd = findInterfaceEnd(in: source, from: interfaceStart) {
                    return interfaceStart..<interfaceEnd
                }
            } else {
                break
            }
            
            searchIndex = source.index(after: searchIndex)
        }
        
        return nil
    }
    
    private func findInterfaceEnd(in source: String, from startIndex: String.Index) -> String.Index? {
        let endKeyword = "@end"
        var currentIndex = startIndex
        
        while currentIndex < source.endIndex {
            if let range = source.range(of: endKeyword, options: [], range: currentIndex..<source.endIndex) {
                return source.index(range.upperBound, offsetBy: 0)
            }
            currentIndex = source.index(after: currentIndex)
        }
        
        return nil
    }
    
    private func extractInterfaceName(from interfaceContent: String) -> String? {
        // Extract interface name, supporting categories and extensions
        let pattern = #"@interface\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*\([^)]*\))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: interfaceContent, range: NSRange(interfaceContent.startIndex..., in: interfaceContent)),
              let nameRange = Range(match.range(at: 1), in: interfaceContent) else {
            return nil
        }
        
        return String(interfaceContent[nameRange])
    }
    
    private func extractInterfaceDeclaration(from interfaceContent: String) -> String {
        // Extract interface declaration part (until first property or method)
        if let firstMemberRange = interfaceContent.range(of: "\n", options: [], range: nil) {
            return String(interfaceContent[..<firstMemberRange.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return interfaceContent
    }
    
    private func extractInterfaceMembers(from interfaceContent: String) -> ([ObjCPropertyInfo], [ObjCMethodInfo]) {
        var properties: [ObjCPropertyInfo] = []
        var methods: [ObjCMethodInfo] = []
        
        let lines = interfaceContent.components(separatedBy: "\n")
        var currentLineIndex = 1 // Skip first line (@interface declaration)
        
        while currentLineIndex < lines.count {
            let line = lines[currentLineIndex].trimmingCharacters(in: .whitespaces)
            
            if line.hasPrefix("@property") {
                // Extract property
                if let property = extractProperty(from: lines, startingAt: currentLineIndex) {
                    properties.append(property)
                    currentLineIndex += 1
                    continue
                }
            } else if line.hasPrefix("-") || line.hasPrefix("+") {
                // Extract method declaration
                if let method = extractMethodDeclaration(from: lines, startingAt: currentLineIndex) {
                    methods.append(method)
                    currentLineIndex += method.fullDeclaration.components(separatedBy: "\n").count
                    continue
                }
            } else if line == "@end" {
                break
            }
            
            currentLineIndex += 1
        }
        
        return (properties, methods)
    }
    
    private func extractProperty(from lines: [String], startingAt index: Int) -> ObjCPropertyInfo? {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        
        // Extract property name
        guard let propertyName = extractPropertyName(from: line) else {
            return nil
        }
        
        // Extract comments
        let comments = extractCommentsBefore(from: lines, at: index)
        
        return ObjCPropertyInfo(
            name: propertyName,
            fullDeclaration: line,
            comments: comments,
            sourceRange: line.startIndex..<line.endIndex
        )
    }
    
    private func extractPropertyName(from line: String) -> String? {
        // Match identifier after @property (property name)
        let pattern = #"@property\s*\([^)]*\)\s*(?:\w+\s*\*?\s*)?([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        
        return String(line[nameRange])
    }
    
    private func extractMethodDeclaration(from lines: [String], startingAt index: Int) -> ObjCMethodInfo? {
        var methodLines: [String] = []
        var currentIndex = index
        
        // Collect method-related lines until semicolon
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            methodLines.append(lines[currentIndex]) // Keep original format
            
            if line.hasSuffix(";") {
                break
            }
            
            currentIndex += 1
        }
        
        let fullDeclaration = methodLines.joined(separator: "\n")
        
        // Extract method name
        guard let methodName = extractMethodName(from: fullDeclaration) else {
            return nil
        }
        
        // Extract comments
        let comments = extractCommentsBefore(from: lines, at: index)
        
        return ObjCMethodInfo(
            name: methodName,
            fullDeclaration: fullDeclaration,
            comments: comments,
            body: nil, // No method body in header files
            sourceRange: fullDeclaration.startIndex..<fullDeclaration.endIndex
        )
    }
    
    private func extractMethodName(from declaration: String) -> String? {
        // Match method name (after - or +, before first colon)
        let pattern = #"^[+-]\s*\([^)]*\)\s*([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: declaration, range: NSRange(declaration.startIndex..., in: declaration)),
              let nameRange = Range(match.range(at: 1), in: declaration) else {
            return nil
        }
        
        return String(declaration[nameRange])
    }
    
    private func extractCommentsBefore(source: String, position: String.Index) -> [String] {
        var comments: [String] = []
        var currentIndex = position
        
        // Look backwards for comments
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
// MARK: - Objective-C Implementation Analyzer
class ObjCImplementationAnalyzer {
    
    /// Analyze Objective-C implementation file
    /// - Parameter filePath: Implementation file path
    /// - Returns: Analysis result
    func analyzeImplementationFile(at filePath: String) throws -> ObjCSourceAnalysisResult {
        let sourceCode = try String(contentsOfFile: filePath, encoding: .utf8)
        return analyzeImplementationCode(sourceCode)
    }
    
    /// Analyze Objective-C implementation code
    /// - Parameter sourceCode: Implementation file content
    /// - Returns: Analysis result
    func analyzeImplementationCode(_ sourceCode: String) -> ObjCSourceAnalysisResult {
        let implementations = extractAllImplementations(from: sourceCode)
        // Implementation files only contain implementations, no interfaces
        return ObjCSourceAnalysisResult(interfaces: [], implementations: implementations)
    }
    
    // MARK: - Private Methods
    
    private func extractAllImplementations(from source: String) -> [ObjCImplementationInfo] {
        var implementations: [ObjCImplementationInfo] = []
        var currentIndex = source.startIndex
        
        while currentIndex < source.endIndex {
            if let implementationInfo = extractNextImplementation(from: source, startingAt: &currentIndex) {
                implementations.append(implementationInfo)
            } else {
                break
            }
        }
        
        return implementations
    }
    
    private func extractNextImplementation(from source: String, startingAt index: inout String.Index) -> ObjCImplementationInfo? {
        // Find @implementation definition
        guard let implementationRange = findImplementationDefinition(in: source, from: index) else {
            return nil
        }
        
        let implementationContent = String(source[implementationRange])
        let implementationStartIndex = implementationRange.lowerBound
        
        // Extract implementation name
        guard let implementationName = extractImplementationName(from: implementationContent) else {
            index = implementationRange.upperBound
            return nil
        }
        
        // Extract implementation declaration
        let implementationDeclaration = extractImplementationDeclaration(from: implementationContent)
        
        // Extract implementation comments
        let comments = extractCommentsBefore(source: source, position: implementationStartIndex)
        
        // Extract methods
        let methods = extractImplementationMethods(from: implementationContent)
        
        index = implementationRange.upperBound
        
        return ObjCImplementationInfo(
            name: implementationName,
            fullDeclaration: implementationDeclaration,
            comments: comments,
            methods: methods,
            sourceRange: implementationRange
        )
    }
    
    private func findImplementationDefinition(in source: String, from index: String.Index) -> Range<String.Index>? {
        let implementationKeyword = "@implementation"
        var searchIndex = index
        
        while searchIndex < source.endIndex {
            if let range = source.range(of: implementationKeyword, options: [], range: searchIndex..<source.endIndex) {
                // Found @implementation start position
                let implementationStart = range.lowerBound
                
                // Find @implementation end position (@end)
                if let implementationEnd = findImplementationEnd(in: source, from: implementationStart) {
                    return implementationStart..<implementationEnd
                }
            } else {
                break
            }
            
            searchIndex = source.index(after: searchIndex)
        }
        
        return nil
    }
    
    private func findImplementationEnd(in source: String, from startIndex: String.Index) -> String.Index? {
        let endKeyword = "@end"
        var currentIndex = startIndex
        
        while currentIndex < source.endIndex {
            if let range = source.range(of: endKeyword, options: [], range: currentIndex..<source.endIndex) {
                return source.index(range.upperBound, offsetBy: 0)
            }
            currentIndex = source.index(after: currentIndex)
        }
        
        return nil
    }
    
    private func extractImplementationName(from implementationContent: String) -> String? {
        // Extract implementation name
        let pattern = #"@implementation\s+([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: implementationContent, range: NSRange(implementationContent.startIndex..., in: implementationContent)),
              let nameRange = Range(match.range(at: 1), in: implementationContent) else {
            return nil
        }
        
        return String(implementationContent[nameRange])
    }
    
    private func extractImplementationDeclaration(from implementationContent: String) -> String {
        // Extract implementation declaration part (first line)
        if let firstNewline = implementationContent.range(of: "\n") {
            return String(implementationContent[..<firstNewline.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return implementationContent
    }
    
    private func extractImplementationMethods(from implementationContent: String) -> [ObjCMethodInfo] {
        var methods: [ObjCMethodInfo] = []
        
        let lines = implementationContent.components(separatedBy: "\n")
        var currentLineIndex = 1 // Skip first line (@implementation declaration)
        
        while currentLineIndex < lines.count {
            let line = lines[currentLineIndex].trimmingCharacters(in: .whitespaces)
            
            if (line.hasPrefix("-") || line.hasPrefix("+")) && line.contains("{") {
                // Extract method implementation
                if let method = extractMethodImplementation(from: lines, startingAt: currentLineIndex) {
                    methods.append(method)
                    currentLineIndex += method.fullDeclaration.components(separatedBy: "\n").count +
                    (method.body?.components(separatedBy: "\n").count ?? 0)
                    continue
                }
            } else if line == "@end" {
                break
            }
            
            currentLineIndex += 1
        }
        
        return methods
    }
    
    private func extractMethodImplementation(from lines: [String], startingAt index: Int) -> ObjCMethodInfo? {
        var methodLines: [String] = []
        var currentIndex = index
        var braceCount = 0
        var foundBodyStart = false
        
        // Collect method declaration and body
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            methodLines.append(lines[currentIndex]) // Keep original format
            
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
        
        // Extract method name
        guard let methodName = extractMethodName(from: declaration) else {
            return nil
        }
        
        // Extract comments
        let comments = extractCommentsBefore(from: lines, at: index)
        
        return ObjCMethodInfo(
            name: methodName,
            fullDeclaration: declaration,
            comments: comments,
            body: body,
            sourceRange: fullContent.startIndex..<fullContent.endIndex
        )
    }
    
    private func extractMethodName(from declaration: String) -> String? {
        // Match method name (after - or +, before first colon)
        let pattern = #"^[+-]\s*\([^)]*\)\s*([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: declaration, range: NSRange(declaration.startIndex..., in: declaration)),
              let nameRange = Range(match.range(at: 1), in: declaration) else {
            return nil
        }
        
        return String(declaration[nameRange])
    }
    
    private func extractCommentsBefore(source: String, position: String.Index) -> [String] {
        var comments: [String] = []
        var currentIndex = position
        
        // Look backwards for comments
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
// MARK: - Objective-C Code Generator
class ObjCCodeGenerator {
    
    /// Regenerate Objective-C code from analysis result
    /// - Parameter result: Analysis result
    /// - Returns: Regenerated code
    func generateCode(from result: ObjCSourceAnalysisResult) -> String {
        var generatedCode = ""
        
        // Generate interface part
        for interface in result.interfaces {
            generatedCode += generateInterfaceCode(from: interface) + "\n\n"
        }
        
        // Generate implementation part
        for implementation in result.implementations {
            generatedCode += generateImplementationCode(from: implementation) + "\n\n"
        }
        
        return generatedCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateInterfaceCode(from interface: ObjCInterfaceInfo) -> String {
        var code = ""
        
        // Add interface comments
        for comment in interface.comments {
            code += comment + "\n"
        }
        
        // Add interface declaration
        code += interface.fullDeclaration + "\n"
        
        // Add properties
        for property in interface.properties {
            code += generatePropertyCode(from: property) + "\n"
        }
        
        // Add method declarations
        for method in interface.methods {
            code += generateMethodDeclarationCode(from: method) + "\n"
        }
        
        code += "@end"
        
        return code
    }
    
    private func generateImplementationCode(from implementation: ObjCImplementationInfo) -> String {
        var code = ""
        
        // Add implementation comments
        for comment in implementation.comments {
            code += comment + "\n"
        }
        
        // Add implementation declaration
        code += implementation.fullDeclaration + "\n"
        
        // Add method implementations
        for method in implementation.methods {
            code += generateMethodImplementationCode(from: method) + "\n"
        }
        
        code += "@end"
        
        return code
    }
    
    private func generatePropertyCode(from property: ObjCPropertyInfo) -> String {
        var code = ""
        
        // Add property comments
        for comment in property.comments {
            code += "    " + comment + "\n"
        }
        
        // Add property declaration
        code += "    " + property.fullDeclaration
        
        return code
    }
    
    private func generateMethodDeclarationCode(from method: ObjCMethodInfo) -> String {
        var code = ""
        
        // Add method comments
        for comment in method.comments {
            code += "    " + comment + "\n"
        }
        
        // Add method declaration
        code += "    " + method.fullDeclaration
        
        return code
    }
    
    private func generateMethodImplementationCode(from method: ObjCMethodInfo) -> String {
        var code = ""
        
        // Add method comments
        for comment in method.comments {
            code += "    " + comment + "\n"
        }
        
        // Add method implementation
        code += "    " + method.fullDeclaration
        
        if let body = method.body {
            code += " " + body
        }
        
        return code
    }
}
