import Foundation
import SuggestionBasic

public struct EditorContent: Codable {
    public struct Selection: Codable {
        public var start: CursorPosition
        public var end: CursorPosition

        public init(start: CursorPosition, end: CursorPosition) {
            self.start = start
            self.end = end
        }
    }

    public init(
        content: String,
        lines: [String],
        uti: String,
        cursorPosition: CursorPosition,
        cursorOffset: Int,
        selections: [Selection],
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        suggesionLineLimit: Int? = nil
    ) {
        self.content = content
        self.lines = lines
        self.uti = uti
        self.cursorPosition = cursorPosition
        self.cursorOffset = cursorOffset
        self.selections = selections
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
        self.suggesionLineLimit = suggesionLineLimit
    }

    public var content: String
    /// Every line has a trailing newline character.
    public var lines: [String]
    public var uti: String
    public var cursorPosition: CursorPosition
    public var cursorOffset: Int
    public var selections: [Selection]
    public var tabSize: Int
    public var indentSize: Int
    public var usesTabsForIndentation: Bool
    public var suggesionLineLimit: Int?

    public func selectedCode(in selection: Selection) -> String {
        return selectedCode(in: selection, for: lines)
    }
    
    private func selectedCode(in selection: EditorContent.Selection, for lines: [String]) -> String {
        return EditorInformation.code(
            in: lines,
            inside: .init(
                start: .init(line: selection.start.line, character: selection.start.character),
                end: .init(line: selection.end.line, character: selection.end.character)
            ),
            ignoreColumns: false
        ).code
    }
}

public struct UpdatedContent: Codable {
    public init(content: String, newSelection: CursorRange? = nil, modifications: [Modification]) {
        self.content = content
        self.newSelection = newSelection
        self.modifications = modifications
    }

    public var content: String
    public var newSelection: CursorRange?
    public var modifications: [Modification]
}
