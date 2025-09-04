import Foundation

public enum Modification: Codable, Equatable {
    case deleted(ClosedRange<Int>)
    case inserted(Int, [String])
    case deletedSelection(CursorRange)
}

public extension [String] {
    mutating func apply(_ modifications: [Modification]) {
        for modification in modifications {
            switch modification {
            case let .deleted(range):
                if isEmpty { break }
                let removingRange = range.lowerBound..<(range.upperBound + 1)
                removeSubrange(removingRange.clamped(to: 0..<endIndex))
            case let .inserted(index, strings):
                insert(contentsOf: strings, at: Swift.min(endIndex, index))
            case let .deletedSelection(cursorRange):
                if isEmpty { break }
                let startLine = cursorRange.start.line
                let startCharacter = cursorRange.start.character
                let endLine = cursorRange.end.line
                let endCharacter = cursorRange.end.character
                
                guard startLine < self.count && endLine < self.count else { break }
                
                if startLine == endLine {
                    let line = self[startLine]
                    let startIndex = line.index(line.startIndex, offsetBy: startCharacter)
                    let endIndex = line.index(line.startIndex, offsetBy: endCharacter)
                    self[startLine].removeSubrange(startIndex..<endIndex)
                } else {
                    let startLineText = self[startLine]
                    let endLineText = self[endLine]
                    let startIndex = startLineText.index(startLineText.startIndex, offsetBy: startCharacter)
                    let endIndex = endLineText.index(endLineText.startIndex, offsetBy: endCharacter)
                    
                    self[startLine] = String(startLineText[..<startIndex])
                    self[endLine] = String(endLineText[endIndex...])
                    
                    self[startLine] += self[endLine]
                    self.remove(at: endLine)
                    
                    if startLine + 1 <= endLine - 1 {
                        self.removeSubrange((startLine + 1)..<endLine)
                    }                    
                }
            }
        }
    }

    func applying(_ modifications: [Modification]) -> Array {
        var newArray = self
        newArray.apply(modifications)
        return newArray
    }
}

public extension NSMutableArray {
    func apply(_ modifications: [Modification]) {
        for modification in modifications {
            switch modification {
            case let .deleted(range):
                if count == 0 { break }
                let newRange = range.clamped(to: 0...(count - 1))
                removeObjects(in: NSRange(newRange))
            case let .inserted(index, strings):
                for string in strings.reversed() {
                    insert(string, at: Swift.min(count, index))
                }
            case let .deletedSelection(cursorRange):
                if count == 0 { break }
                let startLine = cursorRange.start.line
                let startCharacter = cursorRange.start.character
                let endLine = cursorRange.end.line
                let endCharacter = cursorRange.end.character
                
                guard startLine < count && endLine < count else { break }
                    
                if startLine == endLine {
                    if let line = self[startLine] as? String {
                        let startIndex = line.index(line.startIndex, offsetBy: startCharacter)
                        let endIndex = line.index(line.startIndex, offsetBy: endCharacter)
                        let newLine = line.replacingCharacters(in: startIndex..<endIndex, with: "")
                        self[startLine] = newLine
                    }
                } else {
                    if let startLineText = self[startLine] as? String,
                       let endLineText = self[endLine] as? String {
                        let startIndex = startLineText.index(startLineText.startIndex, offsetBy: startCharacter)
                        let endIndex = endLineText.index(endLineText.startIndex, offsetBy: endCharacter)

                        let newStartLine = String(startLineText[..<startIndex])
                        let newEndLine = String(endLineText[endIndex...])

                        self[startLine] = newStartLine
                        self[endLine] = newEndLine
                        
                        self[startLine] = (self[startLine] as! String) + (self[endLine] as! String)
                        removeObject(at: endLine)

                        if startLine + 1 <= endLine - 1 {
                            removeObjects(in: NSRange(location: startLine + 1, length: endLine - startLine - 1))
                        }
                    }
                }
            }
        }
    }
}
