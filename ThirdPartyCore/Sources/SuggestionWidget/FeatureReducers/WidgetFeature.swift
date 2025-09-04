import ActiveApplicationMonitor
import AppActivator
import AsyncAlgorithms
import ComposableArchitecture
import Foundation
import GitHubCopilotService
import Logger
import Preferences
import SwiftUI
import Toast
import XcodeInspector

@Reducer
public struct WidgetFeature {
    public struct WindowState: Equatable {
        var alphaValue: Double = 0
        var frame: CGRect = .zero
    }

    public enum WindowCanBecomeKey: Equatable {
        case sharedPanel
        case chatPanel
    }

    @ObservableState
    public struct State: Equatable {
        var focusingDocumentURL: URL?
        public var colorScheme: ColorScheme = .light

        var toastPanel = ToastPanel.State()

        // MARK: Panels

        public var panelState = PanelFeature.State()

        // MARK: CircularWidget

        public struct CircularWidgetState: Equatable {
            var isProcessingCounters = [CircularWidgetFeature.IsProcessingCounter]()
            var isProcessing: Bool = false
        }

        public var circularWidgetState = CircularWidgetState()
        var _internalCircularWidgetState: CircularWidgetFeature.State {
            get {
                .init(
                    isProcessingCounters: circularWidgetState.isProcessingCounters,
                    isProcessing: circularWidgetState.isProcessing,
                    isDisplayingContent: {
                        if panelState.sharedPanelState.isPanelDisplayed,
                           !panelState.sharedPanelState.isEmpty
                        {
                            return true
                        }
                        if panelState.suggestionPanelState.isPanelDisplayed,
                           panelState.suggestionPanelState.content != nil
                        {
                            return true
                        }
                        return false
                    }(),
                    isContentEmpty: true,
                    isChatPanelDetached: true,
                    isChatOpen: false
                )
            }
            set {
                circularWidgetState = .init(
                    isProcessingCounters: newValue.isProcessingCounters,
                    isProcessing: newValue.isProcessing
                )
            }
        }

        public init() {}
    }

    private enum CancelID {
        case observeActiveApplicationChange
        case observeCompletionPanelChange
        case observeFullscreenChange
        case observeWindowChange
        case observeEditorChange
        case observeUserDefaults
    }

    public enum Action: Equatable {
        case startup
        case observeActiveApplicationChange
        case observeFullscreenChange
        case observeColorSchemeChange

        case updateActiveApplication
        case updateColorScheme

        case updatePanelStateToMatch(WidgetLocation)
        case updateFocusingDocumentURL
        case setFocusingDocumentURL(to: URL?)
        case updateKeyWindow(WindowCanBecomeKey)

        case toastPanel(ToastPanel.Action)
        case panel(PanelFeature.Action)
        case circularWidget(CircularWidgetFeature.Action)
    }

    var windowsController: WidgetWindowsController? {
        suggestionWidgetControllerDependency.windowsController
    }

    @Dependency(\.suggestionWidgetUserDefaultsObservers) var userDefaultsObservers
    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.activateThisApp) var activateThisApp
    @Dependency(\.activatePreviousActiveApp) var activatePreviousActiveApp

    public enum DebounceKey: Hashable {
        case updateWindowOpacity
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.toastPanel, action: \.toastPanel) {
            ToastPanel()
        }
        
        Scope(state: \._internalCircularWidgetState, action: \.circularWidget) {
            CircularWidgetFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .circularWidget(.widgetClicked):
                let wasDisplayingContent = state._internalCircularWidgetState.isDisplayingContent
                if wasDisplayingContent {
                    state.panelState.sharedPanelState.isPanelDisplayed = false
                    state.panelState.suggestionPanelState.isPanelDisplayed = false
                } else {
                    state.panelState.sharedPanelState.isPanelDisplayed = true
                    state.panelState.suggestionPanelState.isPanelDisplayed = true
                }
                
                let isDisplayingContent = state._internalCircularWidgetState.isDisplayingContent
                
                return .run { send in
                    if isDisplayingContent, !(await NSApplication.shared.isActive) {
                        activateThisApp()
                    } else if !isDisplayingContent {
                        activatePreviousActiveApp()
                    }
                }
                
            default: return .none
            }
        }
        
        Scope(state: \.panelState, action: \.panel) {
            PanelFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .startup:
                return .merge(
                    .run { send in
                        await send(.toastPanel(.start))
                        await send(.observeActiveApplicationChange)
                        await send(.observeFullscreenChange)
                        await send(.observeColorSchemeChange)
                    }
                )
                
            case .observeActiveApplicationChange:
                return .run { send in
                    let stream = AsyncStream<AppInstanceInspector> { continuation in
                        let cancellable = xcodeInspector.$activeApplication.sink { newValue in
                            guard let newValue else { return }
                            continuation.yield(newValue)
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    
                    var previousAppIdentifier: pid_t?
                    for await app in stream {
                        try Task.checkCancellation()
                        if app.processIdentifier != previousAppIdentifier {
                            await send(.updateActiveApplication)
                        }
                        previousAppIdentifier = app.processIdentifier
                    }
                }.cancellable(id: CancelID.observeActiveApplicationChange, cancelInFlight: true)
                
            case .observeFullscreenChange:
                return .run { _ in
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.activeSpaceDidChangeNotification)
                    for await _ in sequence {
                        try Task.checkCancellation()
                        guard let activeXcode = await xcodeInspector.safe.activeXcode
                        else { continue }
                        guard let windowsController,
                              await windowsController.windows.fullscreenDetector.isOnActiveSpace
                        else { continue }
                        let app = activeXcode.appElement
                        if let _ = app.focusedWindow {
                            await windowsController.windows.orderFront()
                        }
                    }
                }.cancellable(id: CancelID.observeFullscreenChange, cancelInFlight: true)

            case .observeColorSchemeChange:
                return .run { send in
                    await send(.updateColorScheme)
                    let stream = AsyncStream<Void> { continuation in
                        userDefaultsObservers.xcodeColorSchemeChangeObserver.onChange = {
                            continuation.yield()
                        }
                        
                        userDefaultsObservers.systemColorSchemeChangeObserver.onChange = {
                            continuation.yield()
                        }
                        
                        Task { @MainActor in
                            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                                continuation.yield()
                            }
                        }
                        
                        continuation.onTermination = { _ in
                            userDefaultsObservers.xcodeColorSchemeChangeObserver.onChange = {}
                            userDefaultsObservers.systemColorSchemeChangeObserver.onChange = {}
                        }
                    }
                    
                    for await _ in stream {
                        try Task.checkCancellation()
                        await send(.updateColorScheme)
                    }
                }.cancellable(id: CancelID.observeUserDefaults, cancelInFlight: true)
                
                
            case .updateActiveApplication:
                return .none
                
            case .updateColorScheme:
                let xcodePref = UserDefaults(suiteName: "com.apple.dt.Xcode")!
                    .value(forKey: "IDEAppearance") as? Int ?? 0
                let xcodeColorScheme: XcodeColorScheme = .init(rawValue: xcodePref) ?? .system
                let systemColorScheme: ColorScheme = NSApp.effectiveAppearance.name == .darkAqua
                ? .dark
                : .light
                
                let scheme: ColorScheme = {
                    switch (xcodeColorScheme, systemColorScheme) {
                    case (.system, .dark), (.dark, _):
                        return .dark
                    case (.system, .light), (.light, _):
                        return .light
                    case (.system, _):
                        return .light
                    }
                }()
                
                state.colorScheme = scheme
                state.toastPanel.colorScheme = scheme
                state.panelState.sharedPanelState.colorScheme = scheme
                state.panelState.suggestionPanelState.colorScheme = scheme
                return .none
                
            case .updateFocusingDocumentURL:
                return .run { send in
                    await send(.setFocusingDocumentURL(
                        to: await xcodeInspector.safe
                            .realtimeActiveDocumentURL
                    ))
                }
                
            case let .setFocusingDocumentURL(url):
                state.focusingDocumentURL = url
                return .none
                
            case let .updatePanelStateToMatch(widgetLocation):
                state.panelState.sharedPanelState.alignTopToAnchor = widgetLocation
                    .defaultPanelLocation
                    .alignPanelTop
                
                if let suggestionPanelLocation = widgetLocation.suggestionPanelLocation {
                    state.panelState.suggestionPanelState.isPanelOutOfFrame = false
                    state.panelState.suggestionPanelState
                        .alignTopToAnchor = suggestionPanelLocation
                        .alignPanelTop
                    state.panelState.suggestionPanelState.firstLineIndent = suggestionPanelLocation.firstLineIndent ?? 0
                    if let lineHeight = suggestionPanelLocation.lineHeight {
                        state.panelState.suggestionPanelState.lineHeight = lineHeight
                    }
                } else {
                    state.panelState.suggestionPanelState.isPanelOutOfFrame = true
                }
                
                state.toastPanel.alignTopToAnchor = widgetLocation
                    .defaultPanelLocation
                    .alignPanelTop
                
                return .none
                
            case let .updateKeyWindow(window):
                return .run { _ in
                    await MainActor.run {
                    }
                }
                
            case .toastPanel:
                return .none
                
            case .circularWidget:
                return .none
                
            case .panel:
                return .none
            }
        }
    }
}

