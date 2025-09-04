import SwiftUI
import Perception

struct SettingsButtonRow<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        WithPerceptionTracking{
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.footnote)
                    }
                }
                Spacer()
                content()
            }
            .foregroundStyle(.primary)
            .padding(10)
        }
    }
}

#Preview {
    SettingsButtonRow(
        title: "Example",
        subtitle: "This is an example"
    ) {
        Button("Button") { }
        Button("Button") { }
    }
}
