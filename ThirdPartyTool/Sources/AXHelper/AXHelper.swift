import XcodeInspector
import AppKit
import SuggestionBasic

public struct AXHelper {
    public init() {}
    
    /// When Xcode commands are not available, we can fallback to directly
    /// set the value of the editor with Accessibility API.
    public func injectUpdatedCodeWithAccessibilityAPI(
        _ result: UpdatedContent,
        focusElement: AXUIElement,
        onSuccess: (() -> Void)? = nil,
        onError: (() -> Void)? = nil
    ) throws {
        let oldPosition = focusElement.selectedTextRange
        let oldScrollPosition = focusElement.parent?.verticalScrollBar?.doubleValue

        let error = AXUIElementSetAttributeValue(
            focusElement,
            kAXValueAttribute as CFString,
            result.content as CFTypeRef
        )

        if error != AXError.success {
            if let onError = onError {
                onError()
            }
        }

        // Recover selection range
        if let selection = result.newSelection {
            var range = SourceEditor.convertCursorRangeToRange(selection, in: result.content)
            if let value = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    focusElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    value
                )
            }
        } else if let oldPosition {
            var range = CFRange(
                location: oldPosition.lowerBound,
                length: 0
            )
            if let value = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    focusElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    value
                )
            }
        }

        // Recover scroll position
        if let oldScrollPosition,
           let scrollBar = focusElement.parent?.verticalScrollBar
        {
            Self.setScrollBarValue(scrollBar, value: oldScrollPosition)
        }
        
        if let onSuccess = onSuccess {
            onSuccess()
        }
    }
    
    /// Helper method to set scroll bar value using Accessibility API
    private static func setScrollBarValue(_ scrollBar: AXUIElement, value: Double) {
        AXUIElementSetAttributeValue(
            scrollBar,
            kAXValueAttribute as CFString,
            value as CFTypeRef
        )
    }
    
    private static func getScrollPositionForLine(_ lineNumber: Int, content: String) -> Double? {
        let lines = content.components(separatedBy: .newlines)
        let linesCount = lines.count
        
        guard lineNumber > 0 && lineNumber <= linesCount 
        else { return nil }
        
        // Calculate relative position (0.0 to 1.0)
        let relativePosition = Double(lineNumber - 1) / Double(linesCount - 1)
        
        // Ensure valid range
        return (0.0 <= relativePosition && relativePosition <= 1.0) ? relativePosition : nil
    }
    
    public static func scrollSourceEditorToLine(_ lineNumber: Int, content: String, focusedElement: AXUIElement) {
        guard focusedElement.isSourceEditor,
              let scrollBar = focusedElement.parent?.verticalScrollBar,
              let linePosition = Self.getScrollPositionForLine(lineNumber, content: content)
        else { return }
        
        Self.setScrollBarValue(scrollBar, value: linePosition)
    }
}
