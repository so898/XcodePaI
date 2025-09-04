import AppKit
import Foundation
import XcodeInspector

public struct WidgetLocation: Equatable {
    struct PanelLocation: Equatable {
        var frame: CGRect
        var alignPanelTop: Bool
        var firstLineIndent: Double?
        var lineHeight: Double?
    }

    var widgetFrame: CGRect
    var tabFrame: CGRect
    var defaultPanelLocation: PanelLocation
    var suggestionPanelLocation: PanelLocation?
}

enum UpdateLocationStrategy {
    struct AlignToTextCursor {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement,
            hideCircularWidget: Bool = UserDefaults.shared.value(for: \.hideCircularWidget),
            preferredInsideEditorMinWidth: Double = UserDefaults.shared
                .value(for: \.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
        ) -> WidgetLocation {
            guard let selectedRange: AXValue = try? editor
                .copyValue(key: kAXSelectedTextRangeAttribute),
                let rect: AXValue = try? editor.copyParameterizedValue(
                    key: kAXBoundsForRangeParameterizedAttribute,
                    parameters: selectedRange
                )
            else {
                return FixedToBottom().framesForWindows(
                    editorFrame: editorFrame,
                    mainScreen: mainScreen,
                    activeScreen: activeScreen,
                    hideCircularWidget: hideCircularWidget
                )
            }
            var frame: CGRect = .zero
            let found = AXValueGetValue(rect, .cgRect, &frame)
            guard found else {
                return FixedToBottom().framesForWindows(
                    editorFrame: editorFrame,
                    mainScreen: mainScreen,
                    activeScreen: activeScreen,
                    hideCircularWidget: hideCircularWidget
                )
            }
            return HorizontalMovable().framesForWindows(
                y: mainScreen.frame.height - frame.maxY,
                alignPanelTopToAnchor: nil,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen,
                preferredInsideEditorMinWidth: preferredInsideEditorMinWidth,
                hideCircularWidget: hideCircularWidget
            )
        }
    }

    struct FixedToBottom {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            hideCircularWidget: Bool = UserDefaults.shared.value(for: \.hideCircularWidget),
            preferredInsideEditorMinWidth: Double = UserDefaults.shared
                .value(for: \.preferWidgetToStayInsideEditorWhenWidthGreaterThan),
            editorFrameExpendedSize: CGSize = .zero
        ) -> WidgetLocation {
            return HorizontalMovable().framesForWindows(
                y: mainScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                alignPanelTopToAnchor: false,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen,
                preferredInsideEditorMinWidth: preferredInsideEditorMinWidth,
                hideCircularWidget: hideCircularWidget,
                editorFrameExpendedSize: editorFrameExpendedSize
            )
        }
    }

    struct HorizontalMovable {
        func framesForWindows(
            y: CGFloat,
            alignPanelTopToAnchor fixedAlignment: Bool?,
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            preferredInsideEditorMinWidth: Double,
            hideCircularWidget: Bool = UserDefaults.shared.value(for: \.hideCircularWidget),
            editorFrameExpendedSize: CGSize = .zero
        ) -> WidgetLocation {
            let maxY = max(
                y,
                mainScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                4 + activeScreen.frame.minY
            )
            let y = min(
                maxY,
                activeScreen.frame.maxY - 4,
                mainScreen.frame.height - editorFrame.minY - Style.widgetHeight - Style
                    .widgetPadding
            )

            var proposedAnchorFrameOnTheRightSide = CGRect(
                x: editorFrame.maxX - Style.widgetPadding,
                y: y,
                width: 0,
                height: 0
            )

            let widgetFrameOnTheRightSide = CGRect(
                x: editorFrame.maxX - Style.widgetPadding - Style.widgetWidth,
                y: y,
                width: Style.widgetWidth,
                height: Style.widgetHeight
            )

            if !hideCircularWidget {
                proposedAnchorFrameOnTheRightSide = widgetFrameOnTheRightSide
            }

            let proposedPanelX = proposedAnchorFrameOnTheRightSide.maxX
                + Style.widgetPadding * 2
                - editorFrameExpendedSize.width
            let putPanelToTheRight = {
                if editorFrame.size.width >= preferredInsideEditorMinWidth { return false }
                return activeScreen.frame.maxX > proposedPanelX + Style.panelWidth
            }()
            let alignPanelTopToAnchor = fixedAlignment ?? (y > activeScreen.frame.midY)

            let chatPanelFrame = getChatPanelFrame(mainScreen)
            
            if putPanelToTheRight {
                let anchorFrame = proposedAnchorFrameOnTheRightSide
                let tabFrame = CGRect(
                    x: anchorFrame.origin.x,
                    y: alignPanelTopToAnchor
                        ? anchorFrame.minY - Style.widgetHeight - Style.widgetPadding
                        : anchorFrame.maxY + Style.widgetPadding,
                    width: Style.widgetWidth,
                    height: Style.widgetHeight
                )

                return .init(
                    widgetFrame: widgetFrameOnTheRightSide,
                    tabFrame: tabFrame,
                    defaultPanelLocation: .init(
                        frame: chatPanelFrame,
                        alignPanelTop: alignPanelTopToAnchor
                    ),
                    suggestionPanelLocation: nil
                )
            } else {
                var proposedAnchorFrameOnTheLeftSide = CGRect(
                    x: editorFrame.minX + Style.widgetPadding,
                    y: proposedAnchorFrameOnTheRightSide.origin.y,
                    width: 0,
                    height: 0
                )

                let widgetFrameOnTheLeftSide = CGRect(
                    x: editorFrame.minX + Style.widgetPadding,
                    y: proposedAnchorFrameOnTheRightSide.origin.y,
                    width: Style.widgetWidth,
                    height: Style.widgetHeight
                )

                if !hideCircularWidget {
                    proposedAnchorFrameOnTheLeftSide = widgetFrameOnTheLeftSide
                }

                let proposedPanelX = proposedAnchorFrameOnTheLeftSide.minX
                    - Style.widgetPadding * 2
                    - Style.panelWidth
                    + editorFrameExpendedSize.width
                let putAnchorToTheLeft = {
                    if editorFrame.size.width >= preferredInsideEditorMinWidth {
                        if editorFrame.maxX <= activeScreen.frame.maxX {
                            return false
                        }
                    }
                    return proposedPanelX > activeScreen.frame.minX
                }()

                if putAnchorToTheLeft {
                    let anchorFrame = proposedAnchorFrameOnTheLeftSide
                    let tabFrame = CGRect(
                        x: anchorFrame.origin.x,
                        y: alignPanelTopToAnchor
                            ? anchorFrame.minY - Style.widgetHeight - Style.widgetPadding
                            : anchorFrame.maxY + Style.widgetPadding,
                        width: Style.widgetWidth,
                        height: Style.widgetHeight
                    )
                    return .init(
                        widgetFrame: widgetFrameOnTheLeftSide,
                        tabFrame: tabFrame,
                        defaultPanelLocation: .init(
                            frame: chatPanelFrame,
                            alignPanelTop: alignPanelTopToAnchor
                        ),
                        suggestionPanelLocation: nil
                    )
                } else {
                    let anchorFrame = proposedAnchorFrameOnTheRightSide
                    let tabFrame = CGRect(
                        x: anchorFrame.minX - Style.widgetPadding - Style.widgetWidth,
                        y: anchorFrame.origin.y,
                        width: Style.widgetWidth,
                        height: Style.widgetHeight
                    )
                    return .init(
                        widgetFrame: widgetFrameOnTheRightSide,
                        tabFrame: tabFrame,
                        defaultPanelLocation: .init(
                            frame: chatPanelFrame,
                            alignPanelTop: alignPanelTopToAnchor
                        ),
                        suggestionPanelLocation: nil
                    )
                }
            }
        }
    }

    struct NearbyTextCursor {
        func framesForSuggestionWindow(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement,
            completionPanel: AXUIElement?
        ) -> WidgetLocation.PanelLocation? {
            guard let selectionFrame = UpdateLocationStrategy
                .getSelectionFirstLineFrame(editor: editor) else { return nil }

            // hide it when the line of code is outside of the editor visible rect
            if selectionFrame.maxY < editorFrame.minY || selectionFrame.minY > editorFrame.maxY {
                return nil
            }

            // Always place suggestion window at cursor position.
            return .init(
                frame: .init(
                    x: editorFrame.minX,
                    y: mainScreen.frame.height - selectionFrame.minY - Style.inlineSuggestionMaxHeight + Style.inlineSuggestionPadding,
                    width: editorFrame.width,
                    height: Style.inlineSuggestionMaxHeight
                ),
                alignPanelTop: true,
                firstLineIndent: selectionFrame.maxX - editorFrame.minX - Style.inlineSuggestionPadding,
                lineHeight: selectionFrame.height
            )
        }
    }

    /// Get the frame of the selection.
    static func getSelectionFrame(editor: AXUIElement) -> CGRect? {
        guard let selectedRange: AXValue = try? editor
            .copyValue(key: kAXSelectedTextRangeAttribute),
            let rect: AXValue = try? editor.copyParameterizedValue(
                key: kAXBoundsForRangeParameterizedAttribute,
                parameters: selectedRange
            )
        else {
            return nil
        }
        var selectionFrame: CGRect = .zero
        let found = AXValueGetValue(rect, .cgRect, &selectionFrame)
        guard found else { return nil }
        return selectionFrame
    }

    /// Get the frame of the first line of the selection.
    static func getSelectionFirstLineFrame(editor: AXUIElement) -> CGRect? {
        // Find selection range rect
        guard let selectedRange: AXValue = try? editor
            .copyValue(key: kAXSelectedTextRangeAttribute),
            let rect: AXValue = try? editor.copyParameterizedValue(
                key: kAXBoundsForRangeParameterizedAttribute,
                parameters: selectedRange
            )
        else {
            return nil
        }
        var selectionFrame: CGRect = .zero
        let found = AXValueGetValue(rect, .cgRect, &selectionFrame)
        guard found else { return nil }

        var firstLineRange: CFRange = .init()
        let foundFirstLine = AXValueGetValue(selectedRange, .cfRange, &firstLineRange)
        firstLineRange.length = 0

        #warning(
            "FIXME: When selection is too low and out of the screen, the selection range becomes something else."
        )

        if foundFirstLine,
           let firstLineSelectionRange = AXValueCreate(.cfRange, &firstLineRange),
           let firstLineRect: AXValue = try? editor.copyParameterizedValue(
               key: kAXBoundsForRangeParameterizedAttribute,
               parameters: firstLineSelectionRange
           )
        {
            var firstLineFrame: CGRect = .zero
            let foundFirstLineFrame = AXValueGetValue(firstLineRect, .cgRect, &firstLineFrame)
            if foundFirstLineFrame {
                selectionFrame = firstLineFrame
            }
        }

        return selectionFrame
    }
    
    static func getChatPanelFrame(_ screen: NSScreen? = nil) -> CGRect {
        let screen = screen ??  NSScreen.main ?? NSScreen.screens.first!
        
        let visibleScreenFrame = screen.visibleFrame
        
        // Default Frame
        let width = min(Style.panelWidth, visibleScreenFrame.width * 0.3)
        let height = visibleScreenFrame.height
        let x = visibleScreenFrame.maxX - width
        let y = visibleScreenFrame.minY
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    static func getAttachedChatPanelFrame(_ screen: NSScreen, workspaceWindowElement: AXUIElement) -> CGRect {
        guard let xcodeScreen = workspaceWindowElement.maxIntersectionScreen,
              let xcodeRect = workspaceWindowElement.rect,
              let mainDisplayScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero })
        else {
            return getChatPanelFrame()
        }
        
        let minWidth = Style.minChatPanelWidth
        let visibleXcodeScreenFrame = xcodeScreen.visibleFrame
        
        let width = max(visibleXcodeScreenFrame.maxX - xcodeRect.maxX, minWidth)
        let height = xcodeRect.height
        let x = visibleXcodeScreenFrame.maxX - width
        
        // AXUIElement coordinates: Y=0 at top-left
        // NSWindow coordinates: Y=0 at bottom-left
        let y = mainDisplayScreen.frame.maxY - xcodeRect.maxY + mainDisplayScreen.frame.minY
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
