import AppKit
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import XcodeInspector
import AXHelper

actor WidgetWindowsController: NSObject {
    let userDefaultsObservers = WidgetUserDefaultsObservers()
    var xcodeInspector: XcodeInspector { .shared }

    nonisolated let windows: WidgetWindows
    nonisolated let store: StoreOf<WidgetFeature>

    var currentApplicationProcessIdentifier: pid_t?
    
    weak var currentXcodeApp: XcodeAppInstanceInspector?
    weak var previousXcodeApp: XcodeAppInstanceInspector?

    var cancellable: Set<AnyCancellable> = []
    var observeToAppTask: Task<Void, Error>?
    var observeToFocusedEditorTask: Task<Void, Error>?

    var updateWindowOpacityTask: Task<Void, Error>?
    var lastUpdateWindowOpacityTime = Date(timeIntervalSince1970: 0)

    var updateWindowLocationTask: Task<Void, Error>?
    var lastUpdateWindowLocationTime = Date(timeIntervalSince1970: 0)

    var beatingCompletionPanelTask: Task<Void, Error>?

    deinit {
        userDefaultsObservers.presentationModeChangeObserver.onChange = {}
        observeToAppTask?.cancel()
        observeToFocusedEditorTask?.cancel()
    }

    init(store: StoreOf<WidgetFeature>) {
        self.store = store
        windows = .init(store: store)
        super.init()
        windows.controller = self
    }

    @MainActor func send(_ action: WidgetFeature.Action) {
        store.send(action)
    }

    func start() {
        cancellable.removeAll()

        xcodeInspector.$activeApplication.sink { [weak self] app in
            guard let app else { return }
            Task { [weak self] in await self?.activate(app) }
        }.store(in: &cancellable)

        xcodeInspector.$focusedEditor.sink { [weak self] editor in
            guard let editor, !editor.isChatTextField else { return }
            Task { [weak self] in await self?.observe(toEditor: editor) }
        }.store(in: &cancellable)

        xcodeInspector.$completionPanel.sink { [weak self] newValue in
            Task { [weak self] in
                await self?.handleCompletionPanelChange(isDisplaying: newValue != nil)
            }
        }.store(in: &cancellable)

        userDefaultsObservers.presentationModeChangeObserver.onChange = { [weak self] in
            Task { [weak self] in
                await self?.updateWindowLocation(animated: false, immediately: false)
                await self?.send(.updateColorScheme)
            }
        }
    }
}

// MARK: - Observation

private extension WidgetWindowsController {
    func activate(_ app: AppInstanceInspector) {
        Task {
            if app.isXcode {
                updateWindowLocation(animated: false, immediately: true)
                updateWindowOpacity(immediately: false)
                
                if let xcodeApp = app as? XcodeAppInstanceInspector {
                    previousXcodeApp = currentXcodeApp ?? xcodeApp
                    currentXcodeApp = xcodeApp
                }
                
            } else {
                updateWindowOpacity(immediately: true)
                updateWindowLocation(animated: false, immediately: false)
                await hideSuggestionPanelWindow()
            }
        }
        guard currentApplicationProcessIdentifier != app.processIdentifier else { return }
        currentApplicationProcessIdentifier = app.processIdentifier
        observe(toApp: app)
    }

    func observe(toApp app: AppInstanceInspector) {
        guard let app = app as? XcodeAppInstanceInspector else { return }
        let notifications = app.axNotifications
        observeToAppTask?.cancel()
        observeToAppTask = Task {
            await windows.orderFront()

            for await notification in await notifications.notifications() {
                try Task.checkCancellation()

                /// Hide the widgets before switching to another window/editor
                /// so the transition looks better.
                func hideWidgetForTransitions() async {
                    let newDocumentURL = await xcodeInspector.safe.realtimeActiveDocumentURL
                    let documentURL = await MainActor
                        .run { store.withState { $0.focusingDocumentURL } }
                    if documentURL != newDocumentURL {
                        await send(.panel(.removeDisplayedContent))
                        await hidePanelWindows()
                    }
                    await send(.updateFocusingDocumentURL)
                }

                func removeContent() async {
                    await send(.panel(.removeDisplayedContent))
                }

                func updateWidgetsAndNotifyChangeOfEditor(immediately: Bool) async {
                    await send(.panel(.switchToAnotherEditorAndUpdateContent))
                    updateWindowLocation(animated: false, immediately: immediately)
                    updateWindowOpacity(immediately: immediately)
                }

                func updateWidgets(immediately: Bool) async {
                    updateWindowLocation(animated: false, immediately: immediately)
                    updateWindowOpacity(immediately: immediately)
                }

                switch notification.kind {
                case .focusedWindowChanged, .focusedUIElementChanged:
                    await hideWidgetForTransitions()
                    await updateWidgetsAndNotifyChangeOfEditor(immediately: true)
                case .applicationActivated:
                    await updateWidgetsAndNotifyChangeOfEditor(immediately: false)
                case .mainWindowChanged:
                    await updateWidgetsAndNotifyChangeOfEditor(immediately: false)
                case .windowMiniaturized, .windowDeminiaturized:
                    await updateWidgets(immediately: false)
                case .resized,
                    .moved,
                    .windowMoved,
                    .windowResized:
                    await updateWidgets(immediately: false)
                case .created, .uiElementDestroyed, .xcodeCompletionPanelChanged,
                     .applicationDeactivated:
                    continue
                case .titleChanged:
                    continue
                }
            }
        }
    }

    func observe(toEditor editor: SourceEditor) {
        observeToFocusedEditorTask?.cancel()
        observeToFocusedEditorTask = Task {
            let selectionRangeChange = await editor.axNotifications.notifications()
                .filter { $0.kind == .selectedTextChanged }
            let scroll = await editor.axNotifications.notifications()
                .filter { $0.kind == .scrollPositionChanged }
            let valueChange = await editor.axNotifications.notifications()
                .filter { $0.kind == .valueChanged }

            if #available(macOS 13.0, *) {
                for await notification in merge(
                    scroll,
                    selectionRangeChange.debounce(for: Duration.milliseconds(0)),
                    valueChange.debounce(for: Duration.milliseconds(100))
                ) {
                    guard await xcodeInspector.safe.latestActiveXcode != nil else { return }
                    try Task.checkCancellation()

                    // for better looking
                    if notification.kind == .scrollPositionChanged {
                        await hideSuggestionPanelWindow()
                    }

                    updateWindowLocation(animated: false, immediately: false)
                    updateWindowOpacity(immediately: false)
                }
            } else {
                for await notification in merge(selectionRangeChange, scroll, valueChange) {
                    guard await xcodeInspector.safe.latestActiveXcode != nil else { return }
                    try Task.checkCancellation()

                    // for better looking
                    if notification.kind == .scrollPositionChanged {
                        await hideSuggestionPanelWindow()
                    }

                    updateWindowLocation(animated: false, immediately: false)
                    updateWindowOpacity(immediately: false)
                }
            }
        }
    }

    func handleCompletionPanelChange(isDisplaying: Bool) {
        beatingCompletionPanelTask?.cancel()
        beatingCompletionPanelTask = Task {
            if !isDisplaying {
                // so that the buttons on the suggestion panel could be
                // clicked
                // before the completion panel updates the location of the
                // suggestion panel
                try await Task.sleep(nanoseconds: 400_000_000)
            }

            updateWindowLocation(animated: false, immediately: false)
            updateWindowOpacity(immediately: false)
        }
    }
}

// MARK: - Window Updating

extension WidgetWindowsController {
    @MainActor
    func hidePanelWindows() {
        windows.sharedPanelWindow.alphaValue = 0
        windows.suggestionPanelWindow.alphaValue = 0
    }

    @MainActor
    func hideSuggestionPanelWindow() {
        windows.suggestionPanelWindow.alphaValue = 0
        send(.panel(.hidePanel))
    }

    func generateWidgetLocation() -> WidgetLocation? {
        // Default location when no active application/window
        let defaultLocation = generateDefaultLocation()
        
        if let application = xcodeInspector.latestActiveXcode?.appElement {
            if let focusElement = xcodeInspector.focusedEditor?.element,
               !focusElement.isChatTextField,
               let parent = focusElement.parent,
               let frame = parent.rect,
               let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }),
               let firstScreen = NSScreen.main
            {
                let positionMode = UserDefaults.shared
                    .value(for: \.suggestionWidgetPositionMode)
                let suggestionMode = UserDefaults.shared
                    .value(for: \.suggestionPresentationMode)

                switch positionMode {
                case .fixedToBottom:
                    var result = UpdateLocationStrategy.FixedToBottom().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen
                    )
                    switch suggestionMode {
                    case .nearbyTextCursor:
                        result.suggestionPanelLocation = UpdateLocationStrategy
                            .NearbyTextCursor()
                            .framesForSuggestionWindow(
                                editorFrame: frame, mainScreen: screen,
                                activeScreen: firstScreen,
                                editor: focusElement,
                                completionPanel: xcodeInspector.completionPanel
                            )
                    default:
                        break
                    }
                    return result
                case .alignToTextCursor:
                    var result = UpdateLocationStrategy.AlignToTextCursor().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen,
                        editor: focusElement
                    )
                    switch suggestionMode {
                    case .nearbyTextCursor:
                        result.suggestionPanelLocation = UpdateLocationStrategy
                            .NearbyTextCursor()
                            .framesForSuggestionWindow(
                                editorFrame: frame, mainScreen: screen,
                                activeScreen: firstScreen,
                                editor: focusElement,
                                completionPanel: xcodeInspector.completionPanel
                            )
                    default:
                        break
                    }
                    return result
                }
            } else if var window = application.focusedWindow,
                      var frame = application.focusedWindow?.rect,
                      !["menu bar", "menu bar item"].contains(window.description),
                      frame.size.height > 300,
                      let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }),
                      let firstScreen = NSScreen.main
            {
                if ["open_quickly"].contains(window.identifier)
                    || ["alert"].contains(window.label)
                {
                    // fallback to use workspace window
                    guard let workspaceWindow = application.windows
                        .first(where: { $0.identifier == "Xcode.WorkspaceWindow" }),
                        let rect = workspaceWindow.rect
                    else {
                        return defaultLocation
                    }

                    window = workspaceWindow
                    frame = rect
                }

                var expendedSize = CGSize.zero
                if ["Xcode.WorkspaceWindow"].contains(window.identifier) {
                    // extra padding to bottom so buttons won't be covered
                    frame.size.height -= 40
                } else {
                    // move a bit away from the window so buttons won't be covered
                    frame.origin.x -= Style.widgetPadding + Style.widgetWidth / 2
                    frame.size.width += Style.widgetPadding * 2 + Style.widgetWidth
                    expendedSize.width = (Style.widgetPadding * 2 + Style.widgetWidth) / 2
                    expendedSize.height += Style.widgetPadding
                }

                return UpdateLocationStrategy.FixedToBottom().framesForWindows(
                    editorFrame: frame,
                    mainScreen: screen,
                    activeScreen: firstScreen,
                    preferredInsideEditorMinWidth: 9_999_999_999, // never
                    editorFrameExpendedSize: expendedSize
                )
            }
        }
        return defaultLocation
    }
    
    // Generate a default location when no workspace is opened
    private func generateDefaultLocation() -> WidgetLocation {
        let chatPanelFrame = UpdateLocationStrategy.getChatPanelFrame()
        
        return WidgetLocation(
            widgetFrame: .zero,
            tabFrame: .zero,
            defaultPanelLocation: .init(
                frame: chatPanelFrame,
                alignPanelTop: false
            ),
            suggestionPanelLocation: nil
        )
    }

    func updatePanelState(_ location: WidgetLocation) async {
        await send(.updatePanelStateToMatch(location))
    }

    func updateWindowOpacity(immediately: Bool) {
        let shouldDebounce = !immediately &&
            !(Date().timeIntervalSince(lastUpdateWindowOpacityTime) > 3)
        lastUpdateWindowOpacityTime = Date()
        updateWindowOpacityTask?.cancel()

        let task = Task {
            if shouldDebounce {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            try Task.checkCancellation()
            let xcodeInspector = self.xcodeInspector
            let activeApp = await xcodeInspector.safe.activeApplication
            let latestActiveXcode = await xcodeInspector.safe.latestActiveXcode
            let previousActiveApplication = xcodeInspector.previousActiveApplication
            await MainActor.run {
                let state = store.withState { $0 }
                

                if let activeApp, activeApp.isXcode {
                    let application = activeApp.appElement
                    /// We need this to hide the windows when Xcode is minimized.
                    let noFocus = application.focusedWindow == nil
                    windows.sharedPanelWindow.alphaValue = noFocus ? 0 : 1
                    send(.panel(noFocus ? .hidePanel : .showPanel))
                    windows.suggestionPanelWindow.alphaValue = noFocus ? 0 : 1
                    windows.widgetWindow.alphaValue = noFocus ? 0 : 1
                } else if let activeApp, activeApp.isExtensionService {
                    let noFocus = {
                        guard let xcode = latestActiveXcode else { return true }
                        if let window = xcode.appElement.focusedWindow,
                           window.role == "AXWindow"
                        {
                            return false
                        }
                        return true
                    }()

                    let previousAppIsXcode = previousActiveApplication?.isXcode ?? false

                    send(.panel(noFocus ? .hidePanel : .showPanel))
                    windows.sharedPanelWindow.alphaValue = noFocus ? 0 : 1
                    windows.suggestionPanelWindow.alphaValue = noFocus ? 0 : 1
                    windows.widgetWindow.alphaValue = if noFocus {
                        0
                    } else if previousAppIsXcode {
                        1
                    } else {
                        0
                    }
                } else {
                    windows.sharedPanelWindow.alphaValue = 0
                    windows.suggestionPanelWindow.alphaValue = 0
                    windows.widgetWindow.alphaValue = 0
                }
            }
        }

        updateWindowOpacityTask = task
    }

    func updateWindowLocation(
        animated: Bool,
        immediately: Bool,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        @Sendable @MainActor
        func update() async {
            let state = store.withState { $0 }
            guard let widgetLocation = await generateWidgetLocation() else { return }
            await updatePanelState(widgetLocation)
            
            windows.widgetWindow.setFrame(
                widgetLocation.widgetFrame,
                display: false,
                animate: animated
            )
            windows.sharedPanelWindow.setFrame(
                widgetLocation.defaultPanelLocation.frame,
                display: false,
                animate: animated
            )
            
            if let suggestionPanelLocation = widgetLocation.suggestionPanelLocation {
                windows.suggestionPanelWindow.setFrame(
                    suggestionPanelLocation.frame,
                    display: false,
                    animate: animated
                )
            }
            
        }
        
        let now = Date()
        let shouldThrottle = !immediately &&
        !(now.timeIntervalSince(lastUpdateWindowLocationTime) > 3)
        
        updateWindowLocationTask?.cancel()
        let interval: TimeInterval = 0.05
        
        if shouldThrottle {
            let delay = max(
                0,
                interval - now.timeIntervalSince(lastUpdateWindowLocationTime)
            )
            
            updateWindowLocationTask = Task {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try Task.checkCancellation()
                await update()
            }
        } else {
            Task {
                await update()
            }
        }
        lastUpdateWindowLocationTime = Date()
    }
}

// MARK: - NSWindowDelegate

extension WidgetWindowsController: NSWindowDelegate {
    nonisolated
    func windowWillMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            await Task.yield()
        }
    }

    nonisolated
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            await Task.yield()
        }
    }

    nonisolated
    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            await Task.yield()
        }
    }

    nonisolated
    func windowWillExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            await Task.yield()
        }
    }
}

// MARK: - Windows

public final class WidgetWindows {
    let store: StoreOf<WidgetFeature>
    weak var controller: WidgetWindowsController?
    let cursorPositionTracker = CursorPositionTracker()

    // you should make these window `.transient` so they never show up in the mission control.

    @MainActor
    lazy var fullscreenDetector = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        it.hasShadow = false
        it.setIsVisible(false)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    @MainActor
    lazy var widgetWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .floating
        it.collectionBehavior = [.fullScreenAuxiliary, .transient, .canJoinAllSpaces]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: WidgetView(
                store: store.scope(
                    state: \._internalCircularWidgetState,
                    action: \.circularWidget
                )
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    @MainActor
    lazy var sharedPanelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = widgetLevel(2)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient, .canJoinAllSpaces]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SharedPanelView(
                store: store.scope(
                    state: \.panelState,
                    action: \.panel
                ).scope(
                    state: \.sharedPanelState,
                    action: \.sharedPanel
                )
            ).environment(cursorPositionTracker)
        )
        it.setIsVisible(true)
        return it
    }()

    @MainActor
    lazy var suggestionPanelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = widgetLevel(2)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient, .canJoinAllSpaces]
        it.hasShadow = false
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(
                store: store.scope(
                    state: \.panelState,
                    action: \.panel
                ).scope(
                    state: \.suggestionPanelState,
                    action: \.suggestionPanel
                )
            ).environment(cursorPositionTracker)
        )
        it.canBecomeKeyChecker = { false }
        it.setIsVisible(true)
        return it
    }()

    init(
        store: StoreOf<WidgetFeature>,
    ) {
        self.store = store
    }

    @MainActor
    func orderFront() {
        widgetWindow.orderFrontRegardless()
        sharedPanelWindow.orderFrontRegardless()
        suggestionPanelWindow.orderFrontRegardless()
    }
}

// MARK: - Window Subclasses

class CanBecomeKeyWindow: NSWindow {
    var canBecomeKeyChecker: () -> Bool = { true }
    override var canBecomeKey: Bool { canBecomeKeyChecker() }
    override var canBecomeMain: Bool { canBecomeKeyChecker() }
}

func widgetLevel(_ addition: Int) -> NSWindow.Level {
    let minimumWidgetLevel: Int
    minimumWidgetLevel = NSWindow.Level.floating.rawValue
    return .init(minimumWidgetLevel + addition)
}
