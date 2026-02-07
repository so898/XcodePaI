//
//  ToolCallExtractor.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/27.
//

import Foundation

/// A streaming parser that extracts tool call XML blocks from LLM response chunks.
///
/// This class processes text chunks incrementally, identifying `<tool_use>` XML blocks
/// and separating them from regular content. It maintains an internal buffer to handle
/// cases where XML tags span across multiple chunks.
class ToolCallExtractor {
    /// Internal buffer to store incomplete XML data between chunks.
    /// Used when XML tags are split across multiple processChunk calls.
    private var buffer = ""
    
    /// Represents a segment of content and an optional associated tool call.
    ///
    /// This struct pairs regular text content (that appears before a tool call)
    /// with the parsed tool call data, if present.
    struct ContentAndToolUse {
        /// The text content that appeared before the tool call, if any.
        /// Nil if the segment starts with a tool call.
        let before: String?
        
        /// The parsed tool call extracted from the XML block, if found.
        /// Nil for segments containing only regular text.
        let toolUse: LLMMessageToolCall?
    }
    
    /// Processes a new chunk of text from the LLM response stream.
    ///
    /// This method appends the new chunk to any buffered data from previous calls,
    /// scans for complete `<tool_use>` XML blocks, and returns an array of content
    /// segments paired with any tool calls found.
    ///
    /// - Parameter chunk: A string chunk from the LLM response stream.
    /// - Returns: An array of `ContentAndToolUse` objects representing parsed segments.
    ///            Each element contains either regular text, a tool call, or both.
    func processChunk(_ chunk: String) -> [ContentAndToolUse] {
        var processingBuffer = buffer
        processingBuffer += chunk
        
        var ret = [ContentAndToolUse]()
        
        var before = ""
        var foundLeftBlock = false
        var foundToolUse = false
        var blockContent = ""
        for char in processingBuffer {
            if char == "<" {
                foundLeftBlock = true
            }
            
            if foundToolUse {
                blockContent += String(char)
                
                if blockContent.suffix(11) == "</tool_use>" {
                    let toolUse = parseToolCall(from: blockContent)
                    blockContent = ""
                    
                    ret.append(ContentAndToolUse(before: before, toolUse: toolUse))
                    before = ""
                }
            } else {
                if !foundLeftBlock {
                    before += String(char)
                } else {
                    blockContent += String(char)
                    
                    if blockContent.last == ">" {
                        if blockContent.lowercased() == "<tool_use>" {
                            foundToolUse = true
                        } else {
                            foundLeftBlock = false
                            before += blockContent
                            blockContent = ""
                        }
                    }
                }
            }
        }
        
        if !before.isEmpty {
            ret.append(ContentAndToolUse(before: before, toolUse: nil))
        }
        
        if !blockContent.isEmpty {
            buffer = blockContent
        } else {
            buffer = ""
        }
        
        return ret
    }
    
    /// Resets the internal buffer and returns its current contents.
    ///
    /// Call this method when the stream ends or when switching to a new context
    /// to ensure any remaining buffered data is captured and the parser state is cleared.
    ///
    /// - Returns: The remaining content in the buffer before clearing.
    func resetBuffer() -> String? {
        defer {
            buffer = ""
        }
        return buffer.isEmpty ? nil : buffer
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
