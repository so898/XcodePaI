import SwiftUI

struct BadgeItem {
    enum Level: String, Equatable {
        case warning = "Warning"
        case danger = "Danger"
        case info = "Info"
    }

    let text: String
    let level: Level
    let icon: String?
    let isSelected: Bool

    init(text: String, level: Level, icon: String? = nil, isSelected: Bool = false) {
        self.text = text
        self.level = level
        self.icon = icon
        self.isSelected = isSelected
    }
}

struct Badge: View {
    let text: String
    let level: BadgeItem.Level
    let icon: String?
    let isSelected: Bool

    init(badgeItem: BadgeItem) {
        text = badgeItem.text
        level = badgeItem.level
        icon = badgeItem.icon
        isSelected = badgeItem.isSelected
    }

    init(text: String, level: BadgeItem.Level, icon: String? = nil, isSelected: Bool = false) {
        self.text = text
        self.level = level
        self.icon = icon
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .padding(.vertical, 1)
            }
            Text(text)
                .fontWeight(.semibold)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 3)
        .foregroundColor(
            level == .info ? Color(nsColor: isSelected ? .white : .secondaryLabelColor)
                : Color("\(level.rawValue)ForegroundColor")
        )
        .background(
            level == .info ? Color(nsColor: .clear)
                : Color("\(level.rawValue)BackgroundColor"),
            in: RoundedRectangle(
                cornerRadius: 9999,
                style: .circular
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 9999,
                style: .circular
            )
            .stroke(
                level == .info ? Color(nsColor: isSelected ? .white : .tertiaryLabelColor)
                    : Color("\(level.rawValue)StrokeColor"),
                lineWidth: 1
            )
        )
    }
}
