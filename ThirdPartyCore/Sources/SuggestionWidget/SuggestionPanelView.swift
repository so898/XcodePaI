import ComposableArchitecture
import Foundation
import SwiftUI

struct SuggestionPanelView: View {
    let store: StoreOf<SuggestionPanelFeature>

    var body: some View {
        WithPerceptionTracking {
            Group {
                VStack(spacing: 0) {
                    Content(store: store)
                        .allowsHitTesting(
                            store.isPanelDisplayed && !store.isPanelOutOfFrame
                        )
                        .frame(maxWidth: .infinity)
                }
                .preferredColorScheme(store.colorScheme)
                .opacity(store.opacity)
                .animation(
                    featureFlag: \.animationBCrashSuggestion,
                    .easeInOut(duration: 0.2),
                    value: store.isPanelDisplayed
                )
                .animation(
                    featureFlag: \.animationBCrashSuggestion,
                    .easeInOut(duration: 0.2),
                    value: store.isPanelOutOfFrame
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: Style.inlineSuggestionMaxHeight,
                    alignment: .top
                )
            }
        }
    }

    struct Content: View {
        let store: StoreOf<SuggestionPanelFeature>

        var body: some View {
            WithPerceptionTracking {
                if let content = store.content {
                    CodeBlockSuggestionPanel(
                        code: content.code,
                        language: content.language,
                        startLineIndex: content.startLineIndex,
                        firstLineIndent: store.firstLineIndent,
                        lineHeight: store.lineHeight,
                        isPanelDisplayed: store.isPanelDisplayed
                    )
                        .frame(maxWidth: .infinity, maxHeight: Style.inlineSuggestionMaxHeight)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

