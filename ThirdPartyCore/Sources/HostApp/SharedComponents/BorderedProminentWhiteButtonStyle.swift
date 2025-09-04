import SwiftUI

extension ButtonStyle where Self == BorderedProminentWhiteButtonStyle {
    static var borderedProminentWhite: BorderedProminentWhiteButtonStyle {
        BorderedProminentWhiteButtonStyle()
    }
}

public struct BorderedProminentWhiteButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .padding(.vertical, 0)
            .frame(height: 22, alignment: .leading)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .background(
                colorScheme == .dark ? Color(red: 0.43, green: 0.43, blue: 0.44) : .white
            )
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5).stroke(.clear, lineWidth: 1)
            )
    }
}

