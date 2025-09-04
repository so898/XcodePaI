import AppKit
import SharedUIComponents
import SwiftUI

enum Style {
    static let panelHeight: Double = 560
    static let panelWidth: Double = 504
    static let minChatPanelWidth: Double = 242 // Following the minimal width of Navigator in Xcode
    static let inlineSuggestionMaxHeight: Double = 400
    static let inlineSuggestionPadding: Double = 25
    static let widgetHeight: Double = 20
    static var widgetWidth: Double { widgetHeight }
    static let widgetPadding: Double = 4
    static let chatWindowTitleBarHeight: Double = 24
    static let trafficLightButtonSize: Double = 12
}

extension Color {
    static var contentBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.isDarkMode {
                return #colorLiteral(red: 0.1580096483, green: 0.1730263829, blue: 0.2026666105, alpha: 1)
            }
            return .white
        }))
    }

    static var userChatContentBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.isDarkMode {
                return #colorLiteral(red: 0.2284317913, green: 0.2145925438, blue: 0.3214019983, alpha: 1)
            }
            return #colorLiteral(red: 0.9458052187, green: 0.9311983998, blue: 0.9906365955, alpha: 1)
        }))
    }
}

extension NSAppearance {
    var isDarkMode: Bool {
        if bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return true
        } else {
            return false
        }
    }
}

struct XcodeLikeFrame<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content
    let cornerRadius: Double

    var body: some View {
        content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Material.bar)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(0, cornerRadius), style: .continuous)
                    .stroke(Color.black.opacity(0.1), style: .init(lineWidth: 1))
            ) // Add an extra border just incase the background is not displayed.
            .overlay(
                RoundedRectangle(cornerRadius: max(0, cornerRadius - 1), style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
                    .padding(1)
            )
    }
}

extension View {
    func xcodeStyleFrame(cornerRadius: Double? = nil) -> some View {
        XcodeLikeFrame(content: self, cornerRadius: cornerRadius ?? 10)
    }
}
