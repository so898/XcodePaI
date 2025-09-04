import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct SuggestionPanelFeature {
    @ObservableState
    public struct State: Equatable {
        var content: CodeSuggestionProvider?
        var isExpanded: Bool = false
        var colorScheme: ColorScheme = .light
        var alignTopToAnchor = false
        var firstLineIndent: Double = 0
        var lineHeight: Double = 17
        var isPanelDisplayed: Bool = false
        var isPanelOutOfFrame: Bool = false
        var warningMessage: String?
        var warningURL: String?
        var opacity: Double {
            guard isPanelDisplayed else { return 0 }
            if isPanelOutOfFrame { return 0 }
            guard content != nil else { return 0 }
            return 1
        }
    }

    public enum Action: Equatable {
        case noAction
        case dismissWarning
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .dismissWarning:
                state.warningMessage = nil
                state.warningURL = nil
                return .none
            default:
                return .none
            }
        }
    }
}
