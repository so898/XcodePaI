//
//  ToolCallExtractor.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/27.
//

import Foundation

class ToolCallExtractor {
    // Stores accumulated content
    private var buffer = ""
    // Stores the length of content that has already been returned
    private var lastReturnedIndex = 0
    // Stores extracted tool call code blocks
    private var extractedToolCalls: [LLMMessageToolCall] = []
    // Flag indicating whether currently inside a tool_use block
    private var insideToolBlock = false
    // Starting position of the current tool code block
    private var currentToolBlockStart = 0
    
    /// Processes streaming content
    /// - Parameter chunk: Newly received content fragment
    /// - Returns: Normal content that should be returned to the user (excluding tool_use code blocks)
    func processChunk(_ chunk: String) -> String {
        // Append new content to buffer
        buffer += chunk
        
        var result = ""
        // Retain some characters to prevent tag truncation (<tool_use> is 11 chars max, keeping 20 chars is safer)
        let lookbackSize = 20
        var searchStartIndex = buffer.index(buffer.startIndex, offsetBy: max(0, lastReturnedIndex - lookbackSize))
        
        while searchStartIndex < buffer.endIndex {
            if !insideToolBlock {
                // Look for the start tag of tool_use block
                if let toolStartRange = buffer.range(of: "<tool_use>", range: searchStartIndex..<buffer.endIndex) {
                    let toolStartOffset = buffer.distance(from: buffer.startIndex, to: toolStartRange.lowerBound)
                    
                    // Return content before the tool block
                    if lastReturnedIndex < toolStartOffset {
                        let startIdx = buffer.index(buffer.startIndex, offsetBy: lastReturnedIndex)
                        let endIdx = buffer.index(buffer.startIndex, offsetBy: toolStartOffset)
                        result += String(buffer[startIdx..<endIdx])
                        lastReturnedIndex = toolStartOffset
                    }
                    
                    // Enter tool block
                    insideToolBlock = true
                    currentToolBlockStart = toolStartOffset
                    searchStartIndex = toolStartRange.upperBound
                } else {
                    // No tool block start tag found, return safe content (keep last 20 chars to prevent tag truncation)
                    let safeEndOffset = max(lastReturnedIndex, buffer.count - lookbackSize)
                    if lastReturnedIndex < safeEndOffset {
                        let startIdx = buffer.index(buffer.startIndex, offsetBy: lastReturnedIndex)
                        let endIdx = buffer.index(buffer.startIndex, offsetBy: safeEndOffset)
                        result += String(buffer[startIdx..<endIdx])
                        lastReturnedIndex = safeEndOffset
                    }
                    break
                }
            } else {
                // Inside tool block, look for end tag
                if let toolEndRange = buffer.range(of: "</tool_use>", range: searchStartIndex..<buffer.endIndex) {
                    let toolEndOffset = buffer.distance(from: buffer.startIndex, to: toolEndRange.upperBound)
                    
                    // Extract complete tool_use code block
                    let startIdx = buffer.index(buffer.startIndex, offsetBy: currentToolBlockStart)
                    let endIdx = buffer.index(buffer.startIndex, offsetBy: toolEndOffset)
                    let toolBlock = String(buffer[startIdx..<endIdx])
                    
                    // Parse tool call
                    if let toolCall = parseToolCall(from: toolBlock) {
                        extractedToolCalls.append(toolCall)
                    }
                    
                    // Update state
                    insideToolBlock = false
                    lastReturnedIndex = toolEndOffset
                    searchStartIndex = endIdx
                } else {
                    // End tag not found yet, wait for more content
                    break
                }
            }
        }
        
        return result
    }
    
    /// Finalizes processing, returns remaining content and all extracted tool calls
    /// - Returns: Tuple (remaining normal content, all tool calls)
    func finalize() -> (remainingContent: String, toolCalls: [LLMMessageToolCall]) {
        var remainingContent = ""
        
        if insideToolBlock {
            // If still inside tool block, content is incomplete, return as normal content
            if lastReturnedIndex < buffer.count {
                let startIdx = buffer.index(buffer.startIndex, offsetBy: lastReturnedIndex)
                remainingContent = String(buffer[startIdx...])
            }
        } else {
            // Return remaining normal content in buffer
            if lastReturnedIndex < buffer.count {
                let startIdx = buffer.index(buffer.startIndex, offsetBy: lastReturnedIndex)
                remainingContent = String(buffer[startIdx...])
            }
        }
        
        return (remainingContent, extractedToolCalls)
    }
    
    /// Resets extractor state
    func reset() {
        buffer = ""
        lastReturnedIndex = 0
        extractedToolCalls = []
        insideToolBlock = false
        currentToolBlockStart = 0
    }
    
    /// Gets current count of extracted tool calls
    var toolCallCount: Int {
        return extractedToolCalls.count
    }
}

extension ToolCallExtractor {
    /// Parses tool_use XML block
    private func parseToolCall(from xml: String) -> LLMMessageToolCall? {
        // Preprocessing: fix common XML format errors
        let correctedXML = correctCommonXMLErrors(xml)
        
        // Extract tool name
        guard let name = extractToolName(from: correctedXML) else {
            return nil
        }
        
        // Extract arguments
        let arguments = extractArguments(from: correctedXML)
        
        // Generate standardized XML
        let standardXML = generateStandardXML(name: name, arguments: arguments)
        
        return LLMMessageToolCall(name: name, arguments: arguments, raw: standardXML)
    }
    
    /// Fixes common XML format errors (conservative strategy)
    private func correctCommonXMLErrors(_ xml: String) -> String {
        var corrected = xml
        
        // 1. Fix <name=xxx> format -> <name>xxx
        corrected = corrected.replacingOccurrences(
            of: #"<(name|tool_name|function)\s*=\s*([^<>]+?)>"#,
            with: "<$1>$2</$1>",
            options: .regularExpression
        )
        
        // 2. Fix <name=xxx</name> format -> <name>xxx</name>
        corrected = corrected.replacingOccurrences(
            of: #"<(name|tool_name|function)\s*=\s*([^<>]+?)</\1>"#,
            with: "<$1>$2</$1>",
            options: .regularExpression
        )
        
        // 3. Fix missing opening < in closing tags (e.g.: /arguments> -> </arguments>)
        corrected = corrected.replacingOccurrences(
            of: #"(?<!\<)/(arguments|args|parameters|params|name|tool_name|function)>"#,
            with: "</$1>",
            options: .regularExpression
        )
        
        // 4. Fix missing closing > in closing tags (e.g.: </arguments -> </arguments>)
        corrected = corrected.replacingOccurrences(
            of: #"</(arguments|args|parameters|params|name|tool_name|function)(?!>)"#,
            with: "</$1>",
            options: .regularExpression
        )
        
        return corrected
    }
    
    /// Extracts tool name (supports multiple formats)
    private func extractToolName(from xml: String) -> String? {
        // Try standard format: <name>tool name</name>
        if let nameRange = xml.range(of: #"<name[^>]*>"#, options: .regularExpression),
           let nameEndRange = xml.range(of: "</name>", range: nameRange.upperBound..<xml.endIndex) {
            let name = String(xml[nameRange.upperBound..<nameEndRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }
        
        // Try <name=tool name> or <name=tool name</name> format
        if let match = xml.range(of: #"<name\s*=\s*([^>]+?)(?:>|</name>)"#, options: .regularExpression) {
            let matchedText = String(xml[match])
            if let equalsIndex = matchedText.firstIndex(of: "=") {
                let afterEquals = matchedText[matchedText.index(after: equalsIndex)...]
                let name = String(afterEquals)
                    .replacingOccurrences(of: ">", with: "")
                    .replacingOccurrences(of: "</name>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !name.isEmpty {
                    return name
                }
            }
        }
        
        // Try variants like <tool_name> or <function>
        let nameVariants = ["tool_name", "function", "func", "method", "tool"]
        for variant in nameVariants {
            if let range = xml.range(of: "<\(variant)[^>]*>", options: .regularExpression),
               let endRange = xml.range(of: "</\(variant)>", range: range.upperBound..<xml.endIndex) {
                let name = String(xml[range.upperBound..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    return name
                }
            }
        }
        
        return nil
    }
    
    /// Extracts arguments (supports multiple formats)
    private func extractArguments(from xml: String) -> String {
        // Try standard <arguments> tag
        let argumentVariants = ["arguments", "args", "parameters", "params", "input", "inputs"]
        
        for variant in argumentVariants {
            // Try standard closing tag
            if let argsRange = xml.range(of: "<\(variant)[^>]*>", options: .regularExpression),
               let argsEndRange = xml.range(of: "</\(variant)>", range: argsRange.upperBound..<xml.endIndex) {
                let args = String(xml[argsRange.upperBound..<argsEndRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return args
            }
            
            // Try self-closing or missing closing tags
            if let argsRange = xml.range(of: "<\(variant)[^>]*>", options: .regularExpression) {
                let afterTag = xml[argsRange.upperBound...]
                // Find next tag or string end
                if let nextTagRange = afterTag.range(of: "</?\\w+[^>]*>", options: .regularExpression) {
                    let args = String(afterTag[..<nextTagRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return args
                } else {
                    // No next tag found, take to the end
                    let args = String(afterTag)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return args
                }
            }
        }
        
        // If none of the above found, try extracting JSON object
        if let jsonRange = xml.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            return String(xml[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return ""
    }
    
    /// Generates standardized XML
    private func generateStandardXML(name: String, arguments: String) -> String {
        var xml = "<tool_call>\n"
        xml += "  <name>\(name)</name>\n"
        if !arguments.isEmpty {
            xml += "  <arguments>\(arguments)</arguments>\n"
        }
        xml += "</tool_call>"
        return xml
    }
}
