import Combine
import Perception
import SharedUIComponents
import SuggestionBasic
import SwiftUI
import XcodeInspector
import Foundation
import SuggestionBasic

public final class ExpandableSuggestionService: ObservableObject {
    public static let shared = ExpandableSuggestionService()
    @Published public var isSuggestionExpanded: Bool = false

    private init() {}
}

struct CodeBlockSuggestionPanel: View {
    let code: String
    let language: String
    let startLineIndex: Int
    let firstLineIndent: Double
    let lineHeight: Double
    let isPanelDisplayed: Bool
    @Environment(CursorPositionTracker.self) var cursorPositionTracker
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.suggestionCodeFont) var codeFont
    @AppStorage(\.suggestionDisplayCompactMode) var suggestionDisplayCompactMode
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode
    @AppStorage(\.hideCommonPrecedingSpacesInSuggestion) var hideCommonPrecedingSpaces
    @AppStorage(\.syncSuggestionHighlightTheme) var syncHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark
    @AppStorage(\.currentLineBackgroundColorLight) var currentLineBackgroundColorLight
    @AppStorage(\.currentLineBackgroundColorDark) var currentLineBackgroundColorDark
    @AppStorage(\.codeFontLight) var codeFontLight
    @AppStorage(\.codeFontDark) var codeFontDark

    @ObservedObject var object = ExpandableSuggestionService.shared

    var body: some View {
           WithPerceptionTracking {
               VStack(spacing: 0) {
                   WithPerceptionTracking {
                       AsyncCodeBlock(
                           code: code,
                           language: language,
                           startLineIndex: startLineIndex,
                           scenario: "suggestion",
                           firstLineIndent: firstLineIndent,
                           lineHeight: lineHeight,
                           font: {
                               if syncHighlightTheme {
                                   return colorScheme == .light ? codeFontLight.value.nsFont : codeFontDark.value.nsFont
                               }
                               return codeFont.value.nsFont
                           }(),
                           droppingLeadingSpaces: hideCommonPrecedingSpaces,
                           proposedForegroundColor: {
                               if syncHighlightTheme {
                                   if colorScheme == .light,
                                      let color = codeForegroundColorLight.value?.swiftUIColor
                                   {
                                       return color
                                   } else if let color = codeForegroundColorDark.value?
                                       .swiftUIColor
                                   {
                                       return color
                                   }
                               }
                               return nil
                           }(),
                           proposedBackgroundColor: {
                               if syncHighlightTheme {
                                   if colorScheme == .light,
                                      let color = codeBackgroundColorLight.value?.swiftUIColor
                                   {
                                       return color
                                   } else if let color = codeBackgroundColorDark.value?.swiftUIColor
                                   {
                                       return color
                                   }
                               }
                               return nil
                           }(),
                           currentLineBackgroundColor:  {
                               if colorScheme == .light,
                                  let color = currentLineBackgroundColorLight.value?.swiftUIColor {
                                   return color
                               } else if let color = currentLineBackgroundColorDark.value?.swiftUIColor {
                                   return color
                               }
                               return nil
                           }(),
                           dimmedCharacterCount: startLineIndex
                               == cursorPositionTracker.cursorPosition.line
                               ? cursorPositionTracker.cursorPosition.character
                           : 0,
                           isExpanded: $object.isSuggestionExpanded,
                           isPanelDisplayed: isPanelDisplayed
                       )
                       .frame(maxWidth: .infinity)
                       .padding(Style.inlineSuggestionPadding)
                   }
               }
           }
           .background(Color.clear)
       }
   }

// MARK: - Previews

#Preview("Code Block Suggestion Panel") {
    CodeBlockSuggestionPanel(code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,firstLineIndent: 0, lineHeight: 12, isPanelDisplayed: true, suggestionDisplayCompactMode: .init(
        wrappedValue: false,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(false, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .frame(width: 450, height: 400)
    .padding()
}
