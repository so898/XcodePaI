import AppKit
import ComposableArchitecture
import Foundation

@Reducer
public struct PanelFeature {
    @ObservableState
    public struct State: Equatable {
        public var content: SharedPanelFeature.Content {
            get { sharedPanelState.content }
            set {
                sharedPanelState.content = newValue
                suggestionPanelState.content = newValue.suggestion
            }
        }

        // MARK: SharedPanel

        var sharedPanelState = SharedPanelFeature.State()

        // MARK: SuggestionPanel

        var suggestionPanelState = SuggestionPanelFeature.State()

        var warningMessage: String?
        var warningURL: String?
    }

    public enum Action: Equatable {
        case presentSuggestion
        case presentSuggestionProvider(CodeSuggestionProvider, displayContent: Bool)
        case presentError(String)
        case displayPanelContent
        case expandSuggestion
        case discardSuggestion
        case removeDisplayedContent
        case switchToAnotherEditorAndUpdateContent
        case hidePanel
        case showPanel

        case sharedPanel(SharedPanelFeature.Action)
        case suggestionPanel(SuggestionPanelFeature.Action)

        case presentWarning(message: String, url: String?)
        case dismissWarning
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activateThisApp) var activateThisApp
    var windows: WidgetWindows? { suggestionWidgetControllerDependency.windowsController?.windows }

    public var body: some ReducerOf<Self> {
        Scope(state: \.suggestionPanelState, action: \.suggestionPanel) {
            SuggestionPanelFeature()
        }

        Scope(state: \.sharedPanelState, action: \.sharedPanel) {
            SharedPanelFeature()
        }

        Reduce { state, action in
            switch action {
            case .presentSuggestion:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.activeDocumentURL,
                          let provider = await fetchSuggestionProvider(fileURL: fileURL)
                    else { return }
                    await send(.presentSuggestionProvider(provider, displayContent: true))
                }

            case let .presentSuggestionProvider(provider, displayContent):
                state.content.suggestion = provider
                if displayContent {
                    return .run { send in
                        await send(.displayPanelContent)
                    }.animation(.easeInOut(duration: 0.2))
                }
                return .none

            case let .presentError(errorDescription):
                state.content.error = errorDescription
                return .run { send in
                    await send(.displayPanelContent)
                }.animation(.easeInOut(duration: 0.2))

            case .displayPanelContent:
                if !state.sharedPanelState.isEmpty {
                    state.sharedPanelState.isPanelDisplayed = true
                }

                if state.suggestionPanelState.content != nil {
                    state.suggestionPanelState.isPanelDisplayed = true
                }

                return .none

            case .discardSuggestion:
                state.content.suggestion = nil
                return .none
            case .expandSuggestion:
                state.content.isExpanded = true
                return .none
            case .switchToAnotherEditorAndUpdateContent:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.realtimeActiveDocumentURL
                    else { return }
                }
            case .hidePanel:
                state.suggestionPanelState.isPanelDisplayed = false
                return .none
            case .showPanel:
                state.suggestionPanelState.isPanelDisplayed = true
                return .none
            case .removeDisplayedContent:
                state.content.error = nil
                state.content.suggestion = nil
                return .none

            case .sharedPanel:
                return .none

            case .suggestionPanel:
                return .none

            case .presentWarning(let message, let url):
                state.warningMessage = message
                state.warningURL = url
                state.suggestionPanelState.warningMessage = message
                state.suggestionPanelState.warningURL = url
                return .none

            case .dismissWarning:
                state.warningMessage = nil
                state.warningURL = nil
                state.suggestionPanelState.warningMessage = nil
                state.suggestionPanelState.warningURL = nil
                return .none
            }
        }
    }

    func fetchSuggestionProvider(fileURL: URL) async -> CodeSuggestionProvider? {
        guard let provider = await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .suggestionForFile(at: fileURL) else { return nil }
        return provider
    }
}

