import AppKit
import Foundation

// MARK: - State

public extension AXUIElement {
    /// Set global timeout in seconds.
    static func setGlobalMessagingTimeout(_ timeout: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
    }

    /// Set timeout in seconds for this element.
    func setMessagingTimeout(_ timeout: Float) {
        AXUIElementSetMessagingTimeout(self, timeout)
    }

    var identifier: String {
        (try? copyValue(key: kAXIdentifierAttribute)) ?? ""
    }

    var value: String {
        (try? copyValue(key: kAXValueAttribute)) ?? ""
    }

    var intValue: Int? {
        (try? copyValue(key: kAXValueAttribute))
    }

    var title: String {
        (try? copyValue(key: kAXTitleAttribute)) ?? ""
    }

    var role: String {
        (try? copyValue(key: kAXRoleAttribute)) ?? ""
    }

    var doubleValue: Double {
        (try? copyValue(key: kAXValueAttribute)) ?? 0.0
    }

    var document: String? {
        try? copyValue(key: kAXDocumentAttribute)
    }

    /// Label in Accessibility Inspector.
    var description: String {
        (try? copyValue(key: kAXDescriptionAttribute)) ?? ""
    }

    /// Type in Accessibility Inspector.
    var roleDescription: String {
        (try? copyValue(key: kAXRoleDescriptionAttribute)) ?? ""
    }

    var label: String {
        (try? copyValue(key: kAXLabelValueAttribute)) ?? ""
    }

    var isSourceEditor: Bool {
        description == "Source Editor"
    }
    
    var isEditorArea: Bool {
        description == "editor area"
    }
    
    var isXcodeWorkspaceWindow: Bool {
        description == "Xcode.WorkspaceWindow" || identifier == "Xcode.WorkspaceWindow"
    }

    var selectedTextRange: ClosedRange<Int>? {
        guard let value: AXValue = try? copyValue(key: kAXSelectedTextRangeAttribute)
        else { return nil }
        var range: CFRange = .init(location: 0, length: 0)
        if AXValueGetValue(value, .cfRange, &range) {
            return range.location...(range.location + range.length)
        }
        return nil
    }

    var isFocused: Bool {
        (try? copyValue(key: kAXFocusedAttribute)) ?? false
    }

    var isEnabled: Bool {
        (try? copyValue(key: kAXEnabledAttribute)) ?? false
    }

    var isHidden: Bool {
        (try? copyValue(key: kAXHiddenAttribute)) ?? false
    }
}

// MARK: - Rect

public extension AXUIElement {
    var position: CGPoint? {
        guard let value: AXValue = try? copyValue(key: kAXPositionAttribute)
        else { return nil }
        var point: CGPoint = .zero
        if AXValueGetValue(value, .cgPoint, &point) {
            return point
        }
        return nil
    }

    var size: CGSize? {
        guard let value: AXValue = try? copyValue(key: kAXSizeAttribute)
        else { return nil }
        var size: CGSize = .zero
        if AXValueGetValue(value, .cgSize, &size) {
            return size
        }
        return nil
    }

    var rect: CGRect? {
        guard let position, let size else { return nil }
        return .init(origin: position, size: size)
    }
}

// MARK: - Relationship

public extension AXUIElement {
    var focusedElement: AXUIElement? {
        try? copyValue(key: kAXFocusedUIElementAttribute)
    }

    var sharedFocusElements: [AXUIElement] {
        (try? copyValue(key: kAXChildrenAttribute)) ?? []
    }

    var window: AXUIElement? {
        try? copyValue(key: kAXWindowAttribute)
    }

    var windows: [AXUIElement] {
        (try? copyValue(key: kAXWindowsAttribute)) ?? []
    }

    var isFullScreen: Bool {
        (try? copyValue(key: "AXFullScreen")) ?? false
    }

    var focusedWindow: AXUIElement? {
        try? copyValue(key: kAXFocusedWindowAttribute)
    }

    var topLevelElement: AXUIElement? {
        try? copyValue(key: kAXTopLevelUIElementAttribute)
    }

    var rows: [AXUIElement] {
        (try? copyValue(key: kAXRowsAttribute)) ?? []
    }

    var parent: AXUIElement? {
        try? copyValue(key: kAXParentAttribute)
    }

    var children: [AXUIElement] {
        (try? copyValue(key: kAXChildrenAttribute)) ?? []
    }

    var menuBar: AXUIElement? {
        try? copyValue(key: kAXMenuBarAttribute)
    }

    var visibleChildren: [AXUIElement] {
        (try? copyValue(key: kAXVisibleChildrenAttribute)) ?? []
    }

    func child(
        identifier: String? = nil,
        title: String? = nil,
        role: String? = nil,
        maxDepth: Int = 50
    ) -> AXUIElement? {
        var visited = Set<UnsafeRawPointer>()
        
        func _child(element: AXUIElement, depth: Int) -> AXUIElement? {
            // Check depth limit
            guard depth < maxDepth else { return nil }
            
            // Check for circular reference
            let pointer = UnsafeRawPointer(Unmanaged.passUnretained(element).toOpaque())
            if visited.contains(pointer) {
                return nil
            }
            visited.insert(pointer)
            
            // First check direct children
            for child in element.children {
                let match = {
                    if let identifier, child.identifier != identifier { return false }
                    if let title, child.title != title { return false }
                    if let role, child.role != role { return false }
                    return true
                }()
                if match { return child }
            }
            
            // Then recursively check descendants
            for child in element.children {
                if let target = _child(element: child, depth: depth + 1) {
                    return target
                }
            }
            
            return nil
        }
        
        return _child(element: self, depth: 0)
    }

    /// Get children that match the requirement
    ///
    /// - important: If the element has a lot of descendant nodes, it will heavily affect the
    /// **performance of Xcode**. Please make use ``AXUIElement\traverse(_:)`` instead.
    @available(
        *,
        deprecated,
        renamed: "traverse(_:)",
        message: "Please make use ``AXUIElement\traverse(_:)`` instead."
    )
    func children(where match: (AXUIElement) -> Bool) -> [AXUIElement] {
        var all = [AXUIElement]()
        for child in children {
            if match(child) { all.append(child) }
        }
        for child in children {
            all.append(contentsOf: child.children(where: match))
        }
        return all
    }
    
    func firstParent(where match: (AXUIElement) -> Bool, maxDepth: Int = 50) -> AXUIElement? {
        var visited = Set<UnsafeRawPointer>()
        var current: AXUIElement? = self
        var depth = 0
        
        while let element = current, depth < maxDepth {
            guard let parent = element.parent else { return nil }
            
            // Check for circular reference on the parent element
            let parentPointer = UnsafeRawPointer(Unmanaged.passUnretained(parent).toOpaque())
            if visited.contains(parentPointer) {
                // Circular reference detected in parent chain
                return nil
            }
            visited.insert(parentPointer)
            
            if match(parent) { return parent }
            current = parent
            depth += 1
        }
        
        return nil
    }
    
    func firstChild(where match: (AXUIElement) -> Bool, maxDepth: Int = 50) -> AXUIElement? {
        var visited = Set<UnsafeRawPointer>()
        
        func _firstChild(element: AXUIElement, depth: Int) -> AXUIElement? {
            // Check depth limit
            guard depth < maxDepth else { return nil }
            
            // Check for circular reference
            let pointer = UnsafeRawPointer(Unmanaged.passUnretained(element).toOpaque())
            if visited.contains(pointer) {
                return nil
            }
            visited.insert(pointer)
            
            // First check direct children
            for child in element.children {
                if match(child) { return child }
            }
            
            // Then recursively check descendants
            for child in element.children {
                if let target = _firstChild(element: child, depth: depth + 1) {
                    return target
                }
            }
            
            return nil
        }
        
        return _firstChild(element: self, depth: 0)
    }
    
    func visibleChild(identifier: String, maxDepth: Int = 50) -> AXUIElement? {
        var visited = Set<UnsafeRawPointer>()
        
        func _visibleChild(element: AXUIElement, depth: Int) -> AXUIElement? {
            // Check depth limit
            guard depth < maxDepth else { return nil }
            
            // Check for circular reference
            let pointer = UnsafeRawPointer(Unmanaged.passUnretained(element).toOpaque())
            if visited.contains(pointer) {
                return nil
            }
            visited.insert(pointer)
            
            for child in element.visibleChildren {
                if child.identifier == identifier { return child }
                if let target = _visibleChild(element: child, depth: depth + 1) {
                    return target
                }
            }
            return nil
        }
        
        return _visibleChild(element: self, depth: 0)
    }
    
    var verticalScrollBar: AXUIElement? {
        try? copyValue(key: kAXVerticalScrollBarAttribute)
    }
    
    func retrieveSourceEditor() -> AXUIElement? {
        if self.isSourceEditor { return self }
        
        if self.isXcodeWorkspaceWindow {
            return self.firstChild(where: \.isSourceEditor)
        }
        
        guard let xcodeWorkspaceWindowElement = self.firstParent(where: \.isXcodeWorkspaceWindow)
        else { return nil }
        
        return xcodeWorkspaceWindowElement.firstChild(where: \.isSourceEditor)
    }
}

public extension AXUIElement {
    enum SearchNextStep {
        case skipDescendants
        case skipSiblings
        case skipDescendantsAndSiblings
        case continueSearching
        case stopSearching
    }
    /// Traversing the element tree.
    ///
    /// - important: Traversing the element tree is resource consuming and will affect the
    /// **performance of Xcode**. Please make sure to skip as much as possible.
    ///
    /// - todo: Make it not recursive.
    func traverse(_ handle: (_ element: AXUIElement, _ level: Int) -> SearchNextStep) {
        func _traverse(
            element: AXUIElement,
            level: Int,
            handle: (AXUIElement, Int) -> SearchNextStep
        ) -> SearchNextStep {
            let nextStep = handle(element, level)
            switch nextStep {
            case .stopSearching: return .stopSearching
            case .skipDescendants: return .continueSearching
            case .skipDescendantsAndSiblings: return .skipSiblings
            case .continueSearching, .skipSiblings:
                for child in element.children {
                    switch _traverse(element: child, level: level + 1, handle: handle) {
                    case .skipSiblings, .skipDescendantsAndSiblings:
                        break
                    case .stopSearching:
                        return .stopSearching
                    case .continueSearching, .skipDescendants:
                        continue
                    }
                }
                return nextStep
            }
        }
        _ = _traverse(element: self, level: 0, handle: handle)
    }
}

// MARK: - Helper

public extension AXUIElement {
    func copyValue<T>(key: String, ofType _: T.Type = T.self) throws -> T {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, key as CFString, &value)
        if error == .success, let value = value as? T {
            return value
        }
        throw error
    }

    func copyParameterizedValue<T>(
        key: String,
        parameters: AnyObject,
        ofType _: T.Type = T.self
    ) throws -> T {
        var value: AnyObject?
        let error = AXUIElementCopyParameterizedAttributeValue(
            self,
            key as CFString,
            parameters as CFTypeRef,
            &value
        )
        if error == .success, let value = value as? T {
            return value
        }
        throw error
    }
}

// MARK: - Xcode Specific
public extension AXUIElement {
    func findSourceEditorElement(shouldRetry: Bool = true) -> AXUIElement? {
        
        // 1. Check if the current element is a source editor
        if isSourceEditor {
            return self
        }
        
        // 2. Search for child that is a source editor
        if let sourceEditorChild = firstChild(where: \.isSourceEditor) {
            return sourceEditorChild
        }
        
        // 3. Search for parent that is a source editor (XcodeInspector's approach)
        if let sourceEditorParent = firstParent(where: \.isSourceEditor) {
            return sourceEditorParent
        }
        
        // 4. Search for parent that is an editor area
        if let editorAreaParent = firstParent(where: \.isEditorArea) {
            // 3.1 Search for child that is a source editor
            if let sourceEditorChild = editorAreaParent.firstChild(where: \.isSourceEditor) {
                return sourceEditorChild
            }
        }
        
        // 5. Search for the workspace window
        if let xcodeWorkspaceWindowParent = firstParent(where: \.isXcodeWorkspaceWindow) {
            // 4.1 Search for child that is an editor area
            if let editorAreaChild = xcodeWorkspaceWindowParent.firstChild(where: \.isEditorArea) {
                // 4.2 Search for child that is a source editor
                if let sourceEditorChild = editorAreaChild.firstChild(where: \.isSourceEditor) {
                    return sourceEditorChild
                }
            }
        }
        
        // 6. retry
        if shouldRetry {
            Thread.sleep(forTimeInterval: 0.5)
            return findSourceEditorElement(shouldRetry: false)
        }
        
        
        return nil
        
    }
}

#if hasFeature(RetroactiveAttribute)
extension AXError: @retroactive Error {}
#else
extension AXError: Error {}
#endif

