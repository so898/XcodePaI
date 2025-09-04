import SwiftUI
import Perception

struct SettingsSection<Content: View, Footer: View>: View {
    let title: String
    let showWarning: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    
    init(title: String, showWarning: Bool = false, @ViewBuilder content: @escaping () -> Content, @ViewBuilder footer: @escaping () -> Footer) {
        self.title = title
        self.showWarning = showWarning
        self.content = content
        self.footer = footer
    }
    
    var body: some View {
        WithPerceptionTracking{
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .bold()
                    .padding(.horizontal, 10)
                if showWarning {
                    HStack{
                        Text("GitHub Copilot features are disabled. Please [check your subscription](https://github.com/settings/copilot) to access them.")
                            .foregroundColor(Color("WarningForegroundColor"))
                            .padding(4)
                        Spacer()
                    }
                    .background(Color("WarningBackgroundColor"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color("WarningStrokeColor"), lineWidth: 1)
                    )
                }
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                footer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SettingsSection where Footer == EmptyView {
    init(title: String, showWarning: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, showWarning: showWarning, content: content, footer: { EmptyView() })
    }
}

#Preview {
    VStack(spacing: 20) {
        SettingsSection(title: "General") {
            SettingsLink(
                url: "https://github.com", title: "GitHub", subtitle: "footnote")
            Divider()
            SettingsToggle(title: "Example", isOn: .constant(true))
            Divider()
            SettingsLink(url: "https://example.com", title: "Example")
        }
        SettingsSection(title: "Advanced", showWarning: true) {
            SettingsLink(url: "https://example.com", title: "Example")
        } footer: {
            Text("Footer")
        }
    }
    .padding()
    .frame(width: 300)
}
