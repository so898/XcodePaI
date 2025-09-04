import SwiftUI

struct SettingsLink: View {
    let action: ()->Void
    let title: String
    let subtitle: AnyView?
    let badge: BadgeItem?

    init<Subtitle: View>(
        action: @escaping ()->Void,
        title: String,
        subtitle: Subtitle?,
        badge: BadgeItem? = nil
    ) {
        self.action = action
        self.title = title
        self.subtitle = subtitle.map { AnyView($0) }
        self.badge = badge
    }
    
    init(
        _ url: URL,
        title: String,
        subtitle: String? = nil,
        badge: BadgeItem? = nil
    ) {
        self.init(
            action: { NSWorkspace.shared.open(url) },
            title: title,
            subtitle: subtitle.map { Text($0) },
            badge: badge
        )
    }

    init(url: String, title: String, subtitle: String? = nil, badge: BadgeItem? = nil) {
        self.init(
            URL(string: url)!,
            title: title,
            subtitle: subtitle,
            badge: badge
        )
    }
    
    init<Subtitle: View>(url: String, title: String, subtitle: Subtitle?, badge: BadgeItem? = nil) {
        self.init(
            action: { NSWorkspace.shared.open(URL(string: url)!) },
            title: title,
            subtitle: subtitle,
            badge: badge
        )
    }

    var body: some View {
        Button(action: action) {
            HStack{
                VStack(alignment: .leading) {
                    HStack{
                        Text(title).font(.body)
                        if let badge = self.badge {
                            Badge(badgeItem: badge)
                        }
                    }
                    if let subtitle = subtitle {
                        subtitle.font(.footnote)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .contentShape(Rectangle())  // This makes the entire HStack clickable
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(10)
    }
}

#Preview {
    SettingsLink(
        url: "https://example.com",
        title: "Example",
        subtitle: "This is an example",
        badge: .init(text: "Not Granted", level: .danger)
    )
}
