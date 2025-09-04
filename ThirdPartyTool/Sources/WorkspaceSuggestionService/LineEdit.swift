import Foundation
import SuggestionBasic

/// Represents an edit from a previous state of the document to the current
/// state when the modified portion of the document is constrained to the
/// current line (the line containing the cursor).
///
/// This divides the current line into a `head` and `tail`. The `head` is
/// everything to the left of the cursor.
///
/// The `tail` is all content to the right of the cursor which is permitted
/// when displaying a completion. That is, any content right of the cursor
/// which was present when the completion was first requested and any
/// characters which are permitted to the immediate right of the cursor for
/// middle-of-line completions (e.g. closing parens or braces).
///
/// This also provides a `userEntered` property which contains everything to
/// the left of the cursor and any content to the right of the cursor which is
/// not permitted in a valid `tail`. When the `userEntered` portion extends to
/// the right of the cursor, it indicates an invalid middle-of-line position
/// for a completion (and any suggestions being shown must be invalidated).
///
/// As an example, consider a file with this initial content (where `|` is the
/// cursor):
///
/// ```
/// let nestedTuple = (1, |)
/// ```
///
/// If the document is changed to (closing paren added automatically by the editor):
///
/// ```
/// let nestedTuple = (1, (2,|))
/// ```
///
/// Here is how those properties would be set:
///
/// ```
/// let nestedTuple = (1, (2,|))
/// ^                        ^    = head
/// ^                        ^    = userEntered
///                          ^  ^ = tail
/// ```
///
/// An important responsibility of this type is determining how a `CodeSuggestion`
/// must be updated following the edit to remain vaild.  This is handled by the
/// `updateSuggestions` method, which modifies the cursor position and selected
/// range of text to match the new document locations following the edit.
public struct LineEdit {
    public let previousState: FilespaceSuggestionSnapshot
    public let suggestion: CodeSuggestion
    public let line: String.SubSequence
    public let cursor: CursorPosition
    public let headEnd: String.Index
    public let tailStart: String.Index

    static let tailChars: Set<Character> = [")", ">", "}", "]", "\"", "'", "`"]

    /// The portion of the line to the left of the cursor.
    public var head: String.SubSequence {
        line[..<headEnd]
    }
    /// The portion of the line which may contain edits made by the user since
    /// the previous state. This will always include everything left of the cursor.
    public var userEntered: String.SubSequence {
        line[..<tailStart]
    }
    /// Any portion of the line to the right of the cursor which may be safely
    /// ignored. This include any text present when the completion was
    /// generated any any automatic brace completions supplied by the editor.
    public var tail: String.SubSequence {
        line[tailStart...]
    }

    public init(snapshot: FilespaceSuggestionSnapshot, suggestion: CodeSuggestion, lines: [String], cursor: CursorPosition) {
        self.previousState = snapshot
        self.suggestion = suggestion
        let newLine = lines[cursor.line].dropLast(1) // strip line ending
        self.line = newLine
        self.cursor = cursor

        // find the tail
        var tailIdx = line.endIndex

        func cursorIdx(_ pos: CursorPosition, onLine: String.SubSequence) -> String.Index {
            return onLine.index(onLine.startIndex, offsetBy: pos.character, limitedBy: onLine.endIndex) ?? onLine.endIndex
        }

        func nextTailChar() -> Character {
            return newLine[newLine.index(before: tailIdx)]
        }

        let oldPos = previousState.cursorPosition
        let oldLine = previousState.currentLine.dropLast(1)
        let oldTail = oldLine[cursorIdx(oldPos, onLine: oldLine)...]
        let newPos = cursorIdx(cursor, onLine: line)
        let afterCursor = line[newPos...]

        // start with the same tail present when the completion was generated (if any)
        if afterCursor.hasSuffix(oldTail) {
            tailIdx = line.index(line.endIndex, offsetBy: -oldTail.count)
        }

        // add any whitespace or valid middle of line characters from the old tail up to the cursor
        while tailIdx > newPos && (LineEdit.tailChars.contains(nextTailChar()) || nextTailChar().isWhitespace) {
            tailIdx = line.index(before: tailIdx)
        }

        self.headEnd = newPos
        self.tailStart = tailIdx
    }

    /// Returns a new set of code suggestions containing the same suggestion
    /// content, but updated with new cursor position and replacement ranges to
    /// match this edit.
    public func updateSuggestions(_ suggestions: [CodeSuggestion]) -> [CodeSuggestion] {
        return suggestions.map({
            guard $0.position == suggestion.position else { return $0 }

            // if the tail includes everything right of the cursor, keep the
            // range the same distance from the end of the line
            let distance = previousState.currentLine.dropLast(1).count - $0.range.end.character
            let rangeEnd = if headEnd == tailStart && $0.range.end.line == cursor.line {
                CursorPosition(line: cursor.line, character: line.count - distance)
            } else {
                // otherwise (this is not expected), use the cursor position
                cursor
            }

            return CodeSuggestion(
                id: $0.id,
                text: $0.text,
                position: cursor,
                range: CursorRange(start: $0.range.start, end: rangeEnd)
            )
        })
    }
}

