//
//  TOML.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/6.
//

import Foundation

// MARK: - TOML Value Types

/// TOML value type enumeration
public enum TOMLValue: Equatable, CustomStringConvertible {
    case string(String)
    case integer(Int64)
    case float(Double)
    case boolean(Bool)
    case datetime(Date)
    case array([TOMLValue])
    case table([String: TOMLValue])
    
    public var description: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .integer(let i): return String(i)
        case .float(let f): return String(f)
        case .boolean(let b): return b ? "true" : "false"
        case .datetime(let d):
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: d)
        case .array(let arr): return "[\(arr.map { $0.description }.joined(separator: ", "))]"
        case .table(let dict): return dict.description
        }
    }
    
    // Convenience accessors
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    
    public var intValue: Int64? {
        if case .integer(let i) = self { return i }
        return nil
    }
    
    public var floatValue: Double? {
        if case .float(let f) = self { return f }
        return nil
    }
    
    public var boolValue: Bool? {
        if case .boolean(let b) = self { return b }
        return nil
    }
    
    public var arrayValue: [TOMLValue]? {
        if case .array(let arr) = self { return arr }
        return nil
    }
    
    public var tableValue: [String: TOMLValue]? {
        if case .table(let dict) = self { return dict }
        return nil
    }
}

// MARK: - TOML Parser Error

public enum TOMLError: Error, LocalizedError {
    case invalidSyntax(line: Int, message: String)
    case unexpectedEndOfInput
    case invalidValue(String)
    case invalidKey(String)
    case duplicateKey(String)
    case invalidEscapeSequence(String)
    case unterminatedString(line: Int)
    case fileNotFound(String)
    case encodingError
    
    public var errorDescription: String? {
        switch self {
        case .invalidSyntax(let line, let message):
            return "Syntax error at line \(line): \(message)"
        case .unexpectedEndOfInput:
            return "Unexpected end of input"
        case .invalidValue(let value):
            return "Invalid value: \(value)"
        case .invalidKey(let key):
            return "Invalid key: \(key)"
        case .duplicateKey(let key):
            return "Duplicate key: \(key)"
        case .invalidEscapeSequence(let seq):
            return "Invalid escape sequence: \(seq)"
        case .unterminatedString(let line):
            return "Unterminated string at line \(line)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .encodingError:
            return "File encoding error"
        }
    }
}

// MARK: - TOML Parser

public class TOMLParser {
    private var content: String
    private var index: String.Index
    private var lineNumber: Int = 1
    private var root: [String: TOMLValue] = [:]
    private var currentTable: [String] = []
    
    public init(content: String) {
        self.content = content
        self.index = content.startIndex
    }
    
    public convenience init(fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TOMLError.fileNotFound(fileURL.path)
        }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw TOMLError.encodingError
        }
        self.init(content: content)
    }
    
    // MARK: - Main Parse Method
    
    public func parse() throws -> [String: TOMLValue] {
        root = [:]
        currentTable = []
        index = content.startIndex
        lineNumber = 1
        
        while !isAtEnd {
            skipWhitespaceAndComments()
            
            if isAtEnd { break }
            
            let char = currentChar
            
            if char == "[" {
                try parseTableHeader()
            } else if char == "\n" || char == "\r" {
                advanceLine()
            } else if !char.isWhitespace {
                try parseKeyValue()
            } else {
                advance()
            }
        }
        
        return root
    }
    
    // MARK: - Character Navigation
    
    private var isAtEnd: Bool {
        return index >= content.endIndex
    }
    
    private var currentChar: Character {
        return content[index]
    }
    
    private func peek(_ offset: Int = 1) -> Character? {
        let peekIndex = content.index(index, offsetBy: offset, limitedBy: content.endIndex)
        guard let idx = peekIndex, idx < content.endIndex else { return nil }
        return content[idx]
    }
    
    private func advance() {
        if !isAtEnd {
            index = content.index(after: index)
        }
    }
    
    private func advanceLine() {
        if !isAtEnd && (currentChar == "\n" || currentChar == "\r") {
            if currentChar == "\r" && peek() == "\n" {
                advance()
            }
            advance()
            lineNumber += 1
        }
    }
    
    private func skipWhitespace() {
        while !isAtEnd && currentChar.isWhitespace && currentChar != "\n" && currentChar != "\r" {
            advance()
        }
    }
    
    private func skipWhitespaceAndNewlines() {
        while !isAtEnd && currentChar.isWhitespace {
            if currentChar == "\n" || currentChar == "\r" {
                advanceLine()
            } else {
                advance()
            }
        }
    }
    
    private func skipWhitespaceAndComments() {
        while !isAtEnd {
            skipWhitespace()
            if !isAtEnd && currentChar == "#" {
                skipToEndOfLine()
            } else if !isAtEnd && (currentChar == "\n" || currentChar == "\r") {
                advanceLine()
            } else {
                break
            }
        }
    }
    
    private func skipToEndOfLine() {
        while !isAtEnd && currentChar != "\n" && currentChar != "\r" {
            advance()
        }
    }
    
    // MARK: - Table Header Parsing
    
    private func parseTableHeader() throws {
        advance() // skip first '['
        
        let isArrayOfTables = !isAtEnd && currentChar == "["
        if isArrayOfTables {
            advance() // skip second '['
        }
        
        skipWhitespace()
        
        var keys: [String] = []
        
        while !isAtEnd && currentChar != "]" {
            let key = try parseKey()
            keys.append(key)
            
            skipWhitespace()
            
            if !isAtEnd && currentChar == "." {
                advance()
                skipWhitespace()
            }
        }
        
        guard !isAtEnd && currentChar == "]" else {
            throw TOMLError.invalidSyntax(line: lineNumber, message: "Expected ']'")
        }
        advance()
        
        if isArrayOfTables {
            guard !isAtEnd && currentChar == "]" else {
                throw TOMLError.invalidSyntax(line: lineNumber, message: "Expected ']]'")
            }
            advance()
        }
        
        currentTable = keys
        
        if isArrayOfTables {
            try ensureArrayOfTablesPath(keys)
        } else {
            try ensureTablePath(keys)
        }
        
        skipWhitespace()
        if !isAtEnd && currentChar == "#" {
            skipToEndOfLine()
        }
    }
    
    private func ensureTablePath(_ keys: [String]) throws {
        var current = root
        var path: [String] = []
        
        for (i, key) in keys.enumerated() {
            path.append(key)
            
            if i == keys.count - 1 {
                if current[key] == nil {
                    setValueAtPath(path, value: .table([:]))
                }
            } else {
                if let existing = current[key] {
                    if case .table(let t) = existing {
                        current = t
                    } else if case .array(let arr) = existing, let last = arr.last, case .table(let t) = last {
                        current = t
                    } else {
                        throw TOMLError.invalidSyntax(line: lineNumber, message: "Key '\(key)' is not a table")
                    }
                } else {
                    setValueAtPath(path, value: .table([:]))
                    current = [:]
                }
            }
        }
    }
    
    private func ensureArrayOfTablesPath(_ keys: [String]) throws {
        var path: [String] = []
        
        for (i, key) in keys.enumerated() {
            path.append(key)
            
            if i == keys.count - 1 {
                let existingValue = getValueAtPath(path)
                if existingValue == nil {
                    setValueAtPath(path, value: .array([.table([:])]))
                } else if case .array(var arr) = existingValue {
                    arr.append(.table([:]))
                    setValueAtPath(path, value: .array(arr))
                } else {
                    throw TOMLError.invalidSyntax(line: lineNumber, message: "Key '\(key)' is not an array of tables")
                }
            } else {
                let existingValue = getValueAtPath(path)
                if existingValue == nil {
                    setValueAtPath(path, value: .table([:]))
                }
            }
        }
    }
    
    // MARK: - Key-Value Parsing
    
    private func parseKeyValue() throws {
        var keys: [String] = []
        
        // Parse dotted key
        while true {
            let key = try parseKey()
            keys.append(key)
            
            skipWhitespace()
            
            if !isAtEnd && currentChar == "." {
                advance()
                skipWhitespace()
            } else {
                break
            }
        }
        
        skipWhitespace()
        
        guard !isAtEnd && currentChar == "=" else {
            throw TOMLError.invalidSyntax(line: lineNumber, message: "Expected '=' after key")
        }
        advance()
        
        skipWhitespace()
        
        let value = try parseValue()
        
        let fullPath = currentTable + keys
        setValueAtPath(fullPath, value: value)
        
        skipWhitespace()
        if !isAtEnd && currentChar == "#" {
            skipToEndOfLine()
        }
    }
    
    private func parseKey() throws -> String {
        if !isAtEnd && (currentChar == "\"" || currentChar == "'") {
            return try parseQuotedKey()
        } else {
            return try parseBareKey()
        }
    }
    
    private func parseBareKey() throws -> String {
        var key = ""
        
        while !isAtEnd {
            let char = currentChar
            if char.isLetter || char.isNumber || char == "_" || char == "-" {
                key.append(char)
                advance()
            } else {
                break
            }
        }
        
        guard !key.isEmpty else {
            throw TOMLError.invalidKey("Empty key")
        }
        
        return key
    }
    
    private func parseQuotedKey() throws -> String {
        let quote = currentChar
        advance()
        
        var key = ""
        
        while !isAtEnd && currentChar != quote {
            if currentChar == "\\" && quote == "\"" {
                advance()
                if isAtEnd {
                    throw TOMLError.invalidEscapeSequence("\\")
                }
                key.append(try parseEscapeSequence())
            } else {
                key.append(currentChar)
                advance()
            }
        }
        
        guard !isAtEnd && currentChar == quote else {
            throw TOMLError.unterminatedString(line: lineNumber)
        }
        advance()
        
        return key
    }
    
    // MARK: - Value Parsing
    
    private func parseValue() throws -> TOMLValue {
        guard !isAtEnd else {
            throw TOMLError.unexpectedEndOfInput
        }
        
        let char = currentChar
        
        // Multi-line basic string """
        if char == "\"" && peek(1) == "\"" && peek(2) == "\"" {
            return try parseMultiLineBasicString()
        }
        
        // Multi-line literal string '''
        if char == "'" && peek(1) == "'" && peek(2) == "'" {
            return try parseMultiLineLiteralString()
        }
        
        // Basic string "
        if char == "\"" {
            return try parseBasicString()
        }
        
        // Literal string '
        if char == "'" {
            return try parseLiteralString()
        }
        
        // Array
        if char == "[" {
            return try parseArray()
        }
        
        // Inline table
        if char == "{" {
            return try parseInlineTable()
        }
        
        // Boolean, number, or datetime
        return try parseScalar()
    }
    
    // MARK: - String Parsing
    
    private func parseBasicString() throws -> TOMLValue {
        advance() // skip opening "
        
        var result = ""
        
        while !isAtEnd && currentChar != "\"" {
            if currentChar == "\\" {
                advance()
                if isAtEnd {
                    throw TOMLError.invalidEscapeSequence("\\")
                }
                result.append(try parseEscapeSequence())
            } else if currentChar == "\n" || currentChar == "\r" {
                throw TOMLError.unterminatedString(line: lineNumber)
            } else {
                result.append(currentChar)
                advance()
            }
        }
        
        guard !isAtEnd && currentChar == "\"" else {
            throw TOMLError.unterminatedString(line: lineNumber)
        }
        advance()
        
        return .string(result)
    }
    
    private func parseLiteralString() throws -> TOMLValue {
        advance() // skip opening '
        
        var result = ""
        
        while !isAtEnd && currentChar != "'" {
            if currentChar == "\n" || currentChar == "\r" {
                throw TOMLError.unterminatedString(line: lineNumber)
            }
            result.append(currentChar)
            advance()
        }
        
        guard !isAtEnd && currentChar == "'" else {
            throw TOMLError.unterminatedString(line: lineNumber)
        }
        advance()
        
        return .string(result)
    }
    
    private func parseMultiLineBasicString() throws -> TOMLValue {
        // Skip opening """
        advance()
        advance()
        advance()
        
        // Skip immediate newline after opening """
        if !isAtEnd && currentChar == "\n" {
            advance()
            lineNumber += 1
        } else if !isAtEnd && currentChar == "\r" {
            advance()
            if !isAtEnd && currentChar == "\n" {
                advance()
            }
            lineNumber += 1
        }
        
        var result = ""
        
        while !isAtEnd {
            // Check for closing """
            if currentChar == "\"" && peek(1) == "\"" && peek(2) == "\"" {
                advance()
                advance()
                advance()
                return .string(result)
            }
            
            if currentChar == "\\" {
                advance()
                if isAtEnd {
                    throw TOMLError.invalidEscapeSequence("\\")
                }
                
                // Line ending backslash (trim whitespace)
                if currentChar == "\n" || currentChar == "\r" || currentChar.isWhitespace {
                    // Skip whitespace and newlines
                    while !isAtEnd && (currentChar.isWhitespace || currentChar == "\n" || currentChar == "\r") {
                        if currentChar == "\n" || currentChar == "\r" {
                            advanceLine()
                        } else {
                            advance()
                        }
                    }
                } else {
                    result.append(try parseEscapeSequence())
                }
            } else if currentChar == "\n" || currentChar == "\r" {
                result.append("\n")
                advanceLine()
            } else {
                result.append(currentChar)
                advance()
            }
        }
        
        throw TOMLError.unterminatedString(line: lineNumber)
    }
    
    private func parseMultiLineLiteralString() throws -> TOMLValue {
        // Skip opening '''
        advance()
        advance()
        advance()
        
        // Skip immediate newline after opening '''
        if !isAtEnd && currentChar == "\n" {
            advance()
            lineNumber += 1
        } else if !isAtEnd && currentChar == "\r" {
            advance()
            if !isAtEnd && currentChar == "\n" {
                advance()
            }
            lineNumber += 1
        }
        
        var result = ""
        
        while !isAtEnd {
            // Check for closing '''
            if currentChar == "'" && peek(1) == "'" && peek(2) == "'" {
                advance()
                advance()
                advance()
                return .string(result)
            }
            
            if currentChar == "\n" || currentChar == "\r" {
                result.append("\n")
                advanceLine()
            } else {
                result.append(currentChar)
                advance()
            }
        }
        
        throw TOMLError.unterminatedString(line: lineNumber)
    }
    
    private func parseEscapeSequence() throws -> Character {
        let char = currentChar
        advance()
        
        switch char {
        case "b": return "\u{0008}"
        case "t": return "\t"
        case "n": return "\n"
        case "f": return "\u{000C}"
        case "r": return "\r"
        case "\"": return "\""
        case "\\": return "\\"
        case "u":
            return try parseUnicodeEscape(length: 4)
        case "U":
            return try parseUnicodeEscape(length: 8)
        default:
            throw TOMLError.invalidEscapeSequence("\\\(char)")
        }
    }
    
    private func parseUnicodeEscape(length: Int) throws -> Character {
        var hex = ""
        for _ in 0..<length {
            guard !isAtEnd else {
                throw TOMLError.invalidEscapeSequence("\\u incomplete")
            }
            hex.append(currentChar)
            advance()
        }
        
        guard let codePoint = UInt32(hex, radix: 16),
              let scalar = Unicode.Scalar(codePoint) else {
            throw TOMLError.invalidEscapeSequence("\\u\(hex)")
        }
        
        return Character(scalar)
    }
    
    // MARK: - Array Parsing
    
    private func parseArray() throws -> TOMLValue {
        advance() // skip '['
        
        var elements: [TOMLValue] = []
        
        skipWhitespaceAndNewlines()
        
        while !isAtEnd && currentChar != "]" {
            // Skip comments
            if currentChar == "#" {
                skipToEndOfLine()
                skipWhitespaceAndNewlines()
                continue
            }
            
            let value = try parseValue()
            elements.append(value)
            
            skipWhitespaceAndNewlines()
            
            // Skip comments
            while !isAtEnd && currentChar == "#" {
                skipToEndOfLine()
                skipWhitespaceAndNewlines()
            }
            
            if !isAtEnd && currentChar == "," {
                advance()
                skipWhitespaceAndNewlines()
                
                // Skip comments after comma
                while !isAtEnd && currentChar == "#" {
                    skipToEndOfLine()
                    skipWhitespaceAndNewlines()
                }
            }
        }
        
        guard !isAtEnd && currentChar == "]" else {
            throw TOMLError.invalidSyntax(line: lineNumber, message: "Expected ']'")
        }
        advance()
        
        return .array(elements)
    }
    
    // MARK: - Inline Table Parsing
    
    private func parseInlineTable() throws -> TOMLValue {
        advance() // skip '{'
        
        var table: [String: TOMLValue] = [:]
        
        skipWhitespace()
        
        while !isAtEnd && currentChar != "}" {
            var keys: [String] = []
            
            // Parse dotted key
            while true {
                let key = try parseKey()
                keys.append(key)
                
                skipWhitespace()
                
                if !isAtEnd && currentChar == "." {
                    advance()
                    skipWhitespace()
                } else {
                    break
                }
            }
            
            skipWhitespace()
            
            guard !isAtEnd && currentChar == "=" else {
                throw TOMLError.invalidSyntax(line: lineNumber, message: "Expected '=' in inline table")
            }
            advance()
            
            skipWhitespace()
            
            let value = try parseValue()
            
            // Set nested value
            setNestedValue(&table, keys: keys, value: value)
            
            skipWhitespace()
            
            if !isAtEnd && currentChar == "," {
                advance()
                skipWhitespace()
            }
        }
        
        guard !isAtEnd && currentChar == "}" else {
            throw TOMLError.invalidSyntax(line: lineNumber, message: "Expected '}'")
        }
        advance()
        
        return .table(table)
    }
    
    private func setNestedValue(_ table: inout [String: TOMLValue], keys: [String], value: TOMLValue) {
        guard !keys.isEmpty else { return }
        
        if keys.count == 1 {
            table[keys[0]] = value
        } else {
            let firstKey = keys[0]
            let remainingKeys = Array(keys.dropFirst())
            
            var nestedTable: [String: TOMLValue]
            if let existing = table[firstKey], case .table(let t) = existing {
                nestedTable = t
            } else {
                nestedTable = [:]
            }
            
            setNestedValue(&nestedTable, keys: remainingKeys, value: value)
            table[firstKey] = .table(nestedTable)
        }
    }
    
    // MARK: - Scalar Parsing
    
    private func parseScalar() throws -> TOMLValue {        
        // Collect the scalar value
        var scalar = ""
        while !isAtEnd && !currentChar.isWhitespace && currentChar != "," && currentChar != "]" && currentChar != "}" && currentChar != "#" && currentChar != "\n" && currentChar != "\r" {
            scalar.append(currentChar)
            advance()
        }
        
        // Boolean
        if scalar == "true" {
            return .boolean(true)
        }
        if scalar == "false" {
            return .boolean(false)
        }
        
        // Try to parse as datetime
        if let date = parseDateTime(scalar) {
            return .datetime(date)
        }
        
        // Try to parse as integer
        if let intValue = parseInteger(scalar) {
            return .integer(intValue)
        }
        
        // Try to parse as float
        if let floatValue = parseFloat(scalar) {
            return .float(floatValue)
        }
        
        throw TOMLError.invalidValue(scalar)
    }
    
    private func parseInteger(_ string: String) -> Int64? {
        var s = string
        
        // Handle sign
        var negative = false
        if s.hasPrefix("+") {
            s = String(s.dropFirst())
        } else if s.hasPrefix("-") {
            negative = true
            s = String(s.dropFirst())
        }
        
        // Remove underscores
        s = s.replacingOccurrences(of: "_", with: "")
        
        var result: Int64?
        
        // Hexadecimal
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            result = Int64(String(s.dropFirst(2)), radix: 16)
        }
        // Octal
        else if s.hasPrefix("0o") || s.hasPrefix("0O") {
            result = Int64(String(s.dropFirst(2)), radix: 8)
        }
        // Binary
        else if s.hasPrefix("0b") || s.hasPrefix("0B") {
            result = Int64(String(s.dropFirst(2)), radix: 2)
        }
        // Decimal
        else {
            result = Int64(s)
        }
        
        if let r = result {
            return negative ? -r : r
        }
        return nil
    }
    
    private func parseFloat(_ string: String) -> Double? {
        var s = string
        
        // Special values
        if s == "inf" || s == "+inf" {
            return Double.infinity
        }
        if s == "-inf" {
            return -Double.infinity
        }
        if s == "nan" || s == "+nan" || s == "-nan" {
            return Double.nan
        }
        
        // Remove underscores
        s = s.replacingOccurrences(of: "_", with: "")
        
        return Double(s)
    }
    
    private func parseDateTime(_ string: String) -> Date? {
        let formatters: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate, .withTime, .withColonSeparatorInTime],
            [.withFullDate]
        ]
        
        for options in formatters {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        // Try local datetime (without timezone)
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let date = localFormatter.date(from: string) {
            return date
        }
        
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = localFormatter.date(from: string) {
            return date
        }
        
        localFormatter.dateFormat = "HH:mm:ss.SSSSSS"
        if let date = localFormatter.date(from: string) {
            return date
        }
        
        localFormatter.dateFormat = "HH:mm:ss"
        if let date = localFormatter.date(from: string) {
            return date
        }
        
        return nil
    }
    
    // MARK: - Path Helpers
    
    private func getValueAtPath(_ path: [String]) -> TOMLValue? {
        var current: TOMLValue = .table(root)
        
        for key in path {
            if case .table(let dict) = current {
                if let value = dict[key] {
                    current = value
                } else {
                    return nil
                }
            } else if case .array(let arr) = current, let last = arr.last {
                if case .table(let dict) = last, let value = dict[key] {
                    current = value
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        return current
    }
    
    private func setValueAtPath(_ path: [String], value: TOMLValue) {
        guard !path.isEmpty else { return }
        
        if path.count == 1 {
            root[path[0]] = value
            return
        }
        
        var current = root
        var pathStack: [[String: TOMLValue]] = []
        
        for i in 0..<(path.count - 1) {
            let key = path[i]
            pathStack.append(current)
            
            if let existing = current[key] {
                if case .table(let t) = existing {
                    current = t
                } else if case .array(let arr) = existing, let last = arr.last, case .table(let t) = last {
                    current = t
                } else {
                    current = [:]
                }
            } else {
                current = [:]
            }
        }
        
        current[path.last!] = value
        
        // Rebuild the path
        for i in stride(from: path.count - 2, through: 0, by: -1) {
            var parent = pathStack[i]
            let key = path[i]
            
            if let existing = parent[key], case .array(var arr) = existing {
                if arr.isEmpty {
                    arr.append(.table(current))
                } else {
                    arr[arr.count - 1] = .table(current)
                }
                parent[key] = .array(arr)
            } else {
                parent[key] = .table(current)
            }
            
            current = parent
        }
        
        root = current
    }
}

// MARK: - TOML Document (Editor)

public class TOMLDocument {
    private var data: [String: TOMLValue]
    
    public init() {
        self.data = [:]
    }
    
    public init(data: [String: TOMLValue]) {
        self.data = data
    }
    
    public convenience init(content: String) throws {
        let parser = TOMLParser(content: content)
        let data = try parser.parse()
        self.init(data: data)
    }
    
    public convenience init(fileURL: URL) throws {
        let parser = try TOMLParser(fileURL: fileURL)
        let data = try parser.parse()
        self.init(data: data)
    }
    
    // MARK: - Accessors
    
    public subscript(key: String) -> TOMLValue? {
        get { return getValue(forKeyPath: key) }
        set { setValue(newValue, forKeyPath: key) }
    }
    
    public func getValue(forKeyPath keyPath: String) -> TOMLValue? {
        let keys = keyPath.split(separator: ".").map(String.init)
        return getValue(forKeys: keys)
    }
    
    public func getValue(forKeys keys: [String]) -> TOMLValue? {
        var current: TOMLValue = .table(data)
        
        for key in keys {
            if case .table(let dict) = current {
                if let value = dict[key] {
                    current = value
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        return current
    }
    
    public func setValue(_ value: TOMLValue?, forKeyPath keyPath: String) {
        let keys = keyPath.split(separator: ".").map(String.init)
        setValue(value, forKeys: keys)
    }
    
    public func setValue(_ value: TOMLValue?, forKeys keys: [String]) {
        guard !keys.isEmpty else { return }
        
        if keys.count == 1 {
            if let v = value {
                data[keys[0]] = v
            } else {
                data.removeValue(forKey: keys[0])
            }
            return
        }
        
        setNestedValue(&data, keys: keys, value: value)
    }
    
    private func setNestedValue(_ dict: inout [String: TOMLValue], keys: [String], value: TOMLValue?) {
        guard !keys.isEmpty else { return }
        
        if keys.count == 1 {
            if let v = value {
                dict[keys[0]] = v
            } else {
                dict.removeValue(forKey: keys[0])
            }
            return
        }
        
        let firstKey = keys[0]
        let remainingKeys = Array(keys.dropFirst())
        
        var nestedDict: [String: TOMLValue]
        if let existing = dict[firstKey], case .table(let t) = existing {
            nestedDict = t
        } else {
            nestedDict = [:]
        }
        
        setNestedValue(&nestedDict, keys: remainingKeys, value: value)
        dict[firstKey] = .table(nestedDict)
    }
    
    // MARK: - Convenience Setters
    
    public func setString(_ value: String, forKeyPath keyPath: String) {
        setValue(.string(value), forKeyPath: keyPath)
    }
    
    public func setInteger(_ value: Int64, forKeyPath keyPath: String) {
        setValue(.integer(value), forKeyPath: keyPath)
    }
    
    public func setFloat(_ value: Double, forKeyPath keyPath: String) {
        setValue(.float(value), forKeyPath: keyPath)
    }
    
    public func setBoolean(_ value: Bool, forKeyPath keyPath: String) {
        setValue(.boolean(value), forKeyPath: keyPath)
    }
    
    public func setArray(_ value: [TOMLValue], forKeyPath keyPath: String) {
        setValue(.array(value), forKeyPath: keyPath)
    }
    
    public func setTable(_ value: [String: TOMLValue], forKeyPath keyPath: String) {
        setValue(.table(value), forKeyPath: keyPath)
    }
    
    // MARK: - Remove
    
    public func removeValue(forKeyPath keyPath: String) {
        setValue(nil, forKeyPath: keyPath)
    }
    
    // MARK: - Serialization
    
    public func toTOMLString() -> String {
        return serialize(data, prefix: "")
    }
    
    public func write(to fileURL: URL) throws {
        let content = toTOMLString()
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func serialize(_ dict: [String: TOMLValue], prefix: String) -> String {
        var result = ""
        var tables: [(String, [String: TOMLValue])] = []
        var arrayOfTables: [(String, [[String: TOMLValue]])] = []
        
        // First, serialize simple key-value pairs
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            switch value {
            case .table(let t):
                let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                tables.append((fullKey, t))
            case .array(let arr) where arr.allSatisfy({ if case .table(_) = $0 { return true } else { return false } }):
                let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                let tableArray = arr.compactMap { value -> [String: TOMLValue]? in
                    if case .table(let t) = value { return t }
                    return nil
                }
                arrayOfTables.append((fullKey, tableArray))
            default:
                result += "\(escapeKey(key)) = \(serializeValue(value))\n"
            }
        }
        
        // Then serialize tables
        for (key, table) in tables {
            result += "\n[\(key)]\n"
            result += serialize(table, prefix: key)
        }
        
        // Finally serialize array of tables
        for (key, tableArray) in arrayOfTables {
            for table in tableArray {
                result += "\n[[\(key)]]\n"
                result += serialize(table, prefix: key)
            }
        }
        
        return result
    }
    
    private func serializeValue(_ value: TOMLValue) -> String {
        switch value {
        case .string(let s):
            return serializeString(s)
        case .integer(let i):
            return String(i)
        case .float(let f):
            if f.isNaN {
                return "nan"
            } else if f.isInfinite {
                return f > 0 ? "inf" : "-inf"
            }
            return String(f)
        case .boolean(let b):
            return b ? "true" : "false"
        case .datetime(let d):
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: d)
        case .array(let arr):
            let elements = arr.map { serializeValue($0) }
            return "[\(elements.joined(separator: ", "))]"
        case .table(let dict):
            let pairs = dict.sorted(by: { $0.key < $1.key }).map { "\(escapeKey($0.key)) = \(serializeValue($0.value))" }
            return "{ \(pairs.joined(separator: ", ")) }"
        }
    }
    
    private func serializeString(_ string: String) -> String {
        // Check if multi-line string is needed
        if string.contains("\n") {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"\"\"", with: "\\\"\\\"\\\"")
            return "\"\"\"\n\(escaped)\"\"\""
        }
        
        // Single line string
        var escaped = ""
        for char in string {
            switch char {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(char)
            }
        }
        return "\"\(escaped)\""
    }
    
    private func escapeKey(_ key: String) -> String {
        // Check if bare key is valid
        let bareKeyPattern = "^[A-Za-z0-9_-]+$"
        if key.range(of: bareKeyPattern, options: .regularExpression) != nil {
            return key
        }
        
        // Need to quote the key
        var escaped = ""
        for char in key {
            switch char {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            default: escaped.append(char)
            }
        }
        return "\"\(escaped)\""
    }
    
    // MARK: - Raw Data Access
    
    public var rawData: [String: TOMLValue] {
        return data
    }
}
