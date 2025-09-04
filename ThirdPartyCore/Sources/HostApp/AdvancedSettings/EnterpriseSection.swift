import Combine
import Client
import SwiftUI
import Toast

struct EnterpriseSection: View {
    @AppStorage(\.gitHubCopilotEnterpriseURI) var gitHubCopilotEnterpriseURI
    @Environment(\.toast) var toast

    var body: some View {
        SettingsSection(title: "Enterprise") {
            SettingsTextField(
                title: "Auth provider URL",
                prompt: "https://your-enterprise.ghe.com",
                text: $gitHubCopilotEnterpriseURI,
                onDebouncedChange: { url in urlChanged(url)}
            )
        }
    }

    func urlChanged(_ url: String) {
        if !url.isEmpty {
            validateAuthURL(url)
        }
        NotificationCenter.default.post(
            name: .gitHubCopilotShouldRefreshEditorInformation,
            object: nil
        )
        Task {
            do {
                let service = try getService()
                try await service.postNotification(
                    name: Notification.Name
                        .gitHubCopilotShouldRefreshEditorInformation.rawValue
                )
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }

    func validateAuthURL(_ url: String) {
        let maybeURL = URL(string: url)
        guard let parsedURL = maybeURL else {
            toast("Invalid URL", .error)
            return
        }
        if parsedURL.scheme != "https" {
            toast("URL scheme must be https://", .error)
            return
        }
    }
}

#Preview {
    EnterpriseSection()
}
