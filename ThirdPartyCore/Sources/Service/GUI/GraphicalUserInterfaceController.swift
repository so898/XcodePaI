import ActiveApplicationMonitor
import AppActivator
import AppKit
import ComposableArchitecture
import Dependencies
import Preferences
import SuggestionBasic
import SuggestionWidget

@Reducer
struct GUI {
    @ObservableState
    struct State: Equatable {
        var suggestionWidgetState = WidgetFeature.State()
    }

    enum Action {
        case start
//        case createAndSwitchToBrowserTabIfNeeded(url: URL)
        case toggleWidgetsHotkeyPressed

        case suggestionWidget(WidgetFeature.Action)
        case switchWorkspace(path: String, name: String)
    }

    @Dependency(\.activateThisApp) var activateThisApp

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.suggestionWidgetState, action: \.suggestionWidget) {
                WidgetFeature()
            }

            Reduce { state, action in
                switch action {
                case .start:
                    return .none

                case let .switchWorkspace(path, name):
                    return .run { send in
                    }

                case .toggleWidgetsHotkeyPressed:
                    return .run { send in
                        await send(.suggestionWidget(.circularWidget(.widgetClicked)))
                    }

                case .suggestionWidget:
                    return .none
                }
            }
        }
    }
}

@MainActor
public final class GraphicalUserInterfaceController {
    let store: StoreOf<GUI>
    let widgetController: SuggestionWidgetController
    let widgetDataSource: WidgetDataSource
    
    // Used for restoring. Handle concurrency

    class WeakStoreHolder {
        weak var store: StoreOf<GUI>?
    }

    init() {
        let suggestionDependency = SuggestionWidgetControllerDependency()
        let setupDependency: (inout DependencyValues) -> Void = { dependencies in
            dependencies.suggestionWidgetControllerDependency = suggestionDependency
            dependencies.suggestionWidgetUserDefaultsObservers = .init()
        }
        let store = StoreOf<GUI>(
            initialState: .init(),
            reducer: { GUI() },
            withDependencies: setupDependency
        )
        self.store = store
        widgetDataSource = .init()

        widgetController = SuggestionWidgetController(
            store: store.scope(
                state: \.suggestionWidgetState,
                action: \.suggestionWidget
            ),
            dependency: suggestionDependency
        )

        suggestionDependency.suggestionWidgetDataSource = widgetDataSource
    }

    func start() {
        store.send(.start)
    }
}
