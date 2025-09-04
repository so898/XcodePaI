import DebounceFunction
import Foundation
import Perception
import SwiftUI
import SuggestionBasic

public struct AsyncCodeBlock: View {
    private struct Constants {
        static let paddingLeading = 5.0
        static let paddingBottom = 10.0
        static let paddingTrailing = 10.0
    }

    @Environment(\.colorScheme) var colorScheme
    @Binding var isExpanded: Bool
    @State private var isHovering: Bool = false
    @AppStorage(\.completionHintShown) var  completionHintShown

    let code: String
    let language: String
    let startLineIndex: Int
    let scenario: String
    let firstLineIndent: Double
    let lineHeight: Double
    let font: NSFont
    let proposedForegroundColor: Color?
    let proposedBackgroundColor: Color?
    let currentLineBackgroundColor: Color?
    let dimmedCharacterCount: Int
    let droppingLeadingSpaces: Bool
    let isPanelDisplayed: Bool

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        scenario: String,
        firstLineIndent: Double,
        lineHeight: Double,
        font: NSFont,
        droppingLeadingSpaces: Bool,
        proposedForegroundColor: Color?,
        proposedBackgroundColor: Color?,
        currentLineBackgroundColor: Color?,
        dimmedCharacterCount: Int,
        isExpanded: Binding<Bool>,
        isPanelDisplayed: Bool
    ) {
        self.code = code
        self.startLineIndex = startLineIndex
        self.language = language
        self.scenario = scenario
        self.firstLineIndent = firstLineIndent
        self.lineHeight = lineHeight
        self.font = font
        self.proposedForegroundColor = proposedForegroundColor
        self.proposedBackgroundColor = proposedBackgroundColor
        self.currentLineBackgroundColor = currentLineBackgroundColor
        self.dimmedCharacterCount = dimmedCharacterCount
        self.droppingLeadingSpaces = droppingLeadingSpaces
        self._isExpanded = isExpanded
        self.isPanelDisplayed = isPanelDisplayed
    }

    var foregroundColor: Color {
        if let proposedForegroundColor = proposedForegroundColor {
            return proposedForegroundColor
        }
        return colorScheme == .light ? .black.opacity(0.85) : .white.opacity(0.85)
    }

    var foregroundTextColor: Color {
        return foregroundColor.opacity(0.6)
    }

    var backgroundColor: Color {
        if let proposedBackgroundColor = proposedBackgroundColor {
            return proposedBackgroundColor
        }
        return colorScheme == .dark ? Color(red: 0.1216, green: 0.1216, blue: 0.1412) : .white
    }

    var fontHeight: Double {
        (font.ascender + abs(font.descender)).rounded(.down)
    }

    var lineSpacing: Double {
        lineHeight - fontHeight
    }

    var expandedIndent: Double {
        let lines = code.splitByNewLine()
        guard let firstLine = lines.first else { return 0 }
        let existing = String(firstLine.prefix(dimmedCharacterCount))
        let attr = NSAttributedString(string: existing, attributes: [.font: font])
        return firstLineIndent - attr.size().width
    }

    var hintText: String {
        if isExpanded {
            return "Press ⌥⇥ to accept full suggestion"
        }
        return "Hold ⌥ for full suggestion"
    }


    @ScaledMetric var keyPadding: Double = 3.0

    @ViewBuilder
    func keyBackground(content: () -> some View) -> some View {
        content()
            .padding(.horizontal, keyPadding)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(foregroundColor, lineWidth: 1)
                    .foregroundColor(.clear)
                    .frame(
                        minWidth: fontHeight,
                        minHeight: fontHeight,
                        maxHeight: fontHeight
                    )
            )
    }

    @ViewBuilder
    var optionKey: some View {
        keyBackground {
            Image(systemName: "option")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(height: font.capHeight)
        }
    }

    @ViewBuilder
    var popoverContent: some View {
        HStack {
            if isExpanded {
                Text("Press")
                optionKey
                keyBackground {
                    Text("tab")
                        .font(.init(font))
                }
                Text("to accept full suggestion")
            } else {
                Text("Hold")
                optionKey
                Text("for full suggestion")
            }
        }
        .padding(8)
        .font(.body)
        .fixedSize()
    }

    @ViewBuilder
    func lineBackgroundShape(_ multiLine: Bool) -> some View {
        let color = currentLineBackgroundColor ?? backgroundColor
        switch multiLine {
        case true: HalfCapsule().fill(color)
        case false: Rectangle().fill(color)
        }
    }

    @ScaledMetric var iconPadding: CGFloat = 9.0
    @ScaledMetric var iconSpacing: CGFloat = 6.0
    @ScaledMetric var optionPadding: CGFloat = 0.5

    @ViewBuilder
    var contentView: some View {
        let lines = code.splitByNewLine()
        if let firstLine = lines.first {
            let firstLineTrimmed = firstLine
                .dropFirst(dimmedCharacterCount)
            HStack() {
                HStack(alignment: .center, spacing: 10) {
                    Text(firstLineTrimmed)
                        .foregroundColor(foregroundTextColor)
                        .lineSpacing(lineSpacing) // This only has effect if a line wraps
                    if lines.count > 1 {
                        HStack(spacing: iconSpacing) {
                            Image("CopilotLogo")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                            Image(systemName: "option")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .padding(.vertical, optionPadding)
                        }
                        .frame(height: lineHeight * 0.7)
                        .padding(.horizontal, iconPadding)
                        .background(
                            Capsule()
                                .fill(foregroundColor.opacity(isExpanded ? 0.1 : 0.2))
                                .frame(height: lineHeight)
                        )
                        .frame(height: lineHeight) // Moves popover attachment
                        .popover(isPresented: $isHovering) {
                            popoverContent
                        }
                        .task {
                            isHovering = !completionHintShown
                            completionHintShown = true
                        }
                    }
                }
                .frame(height: lineHeight)
                .background(lineBackgroundShape(lines.count > 1))
                .padding(.leading, firstLineIndent)
                .onHover { hovering in
                    guard hovering != isHovering else { return }
                    withAnimation {
                        isHovering = hovering
                    }
                }
                Spacer()
            }
        }

        if isExpanded && lines.count > 1 {
            HStack() {
                CustomScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.dropFirst()), id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(line)
                                    .foregroundColor(foregroundTextColor)
                                    .lineSpacing(lineSpacing)
                            }
                            .frame(minHeight: lineHeight)
                        }
                    }
                }
                .padding(EdgeInsets(
                    top: 0,
                    leading: Constants.paddingLeading,
                    bottom: Constants.paddingBottom,
                    trailing: Constants.paddingTrailing
                ))
                .background(backgroundColor)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(foregroundColor.opacity(0.2), lineWidth: 1)) // border
                .shadow(color: Color.black.opacity(0.2), radius: 8.0, x: 1, y: 1)
                .onHover { hovering in
                    guard hovering != isHovering else { return }
                    withAnimation {
                        isHovering = hovering
                    }
                }
                Spacer()
            }
            .padding(.leading, expandedIndent - Constants.paddingLeading)
        }
    }

    public var body: some View {
        if isPanelDisplayed {
            WithPerceptionTracking {
                VStack(spacing: 0) {
                    contentView
                }
                .font(.init(font))
                .background(Color.clear)
            }
        }
    }
}
