import Client
import SwiftUI
import Toast

struct ProxySection: View {
    @AppStorage(\.gitHubCopilotProxyUrl) var gitHubCopilotProxyUrl
    @AppStorage(\.gitHubCopilotProxyUsername) var gitHubCopilotProxyUsername
    @AppStorage(\.gitHubCopilotProxyPassword) var gitHubCopilotProxyPassword
    @AppStorage(\.gitHubCopilotUseStrictSSL) var gitHubCopilotUseStrictSSL

    @Environment(\.toast) var toast

    var body: some View {
        SettingsSection(title: "Proxy") {
            SettingsTextField(
                title: "Proxy URL",
                prompt: "http://host:port",
                text: $gitHubCopilotProxyUrl,
                onDebouncedChange: { _ in refreshConfiguration() }
            )
            SettingsTextField(
                title: "Proxy username",
                prompt: "username",
                text: $gitHubCopilotProxyUsername,
                onDebouncedChange: { _ in refreshConfiguration() }
            )
            SettingsTextField(
                title: "Proxy password",
                prompt: "password",
                text: $gitHubCopilotProxyPassword,
                isSecure: true,
                onDebouncedChange: { _ in refreshConfiguration() }
            )
            SettingsToggle(
                title: "Proxy strict SSL",
                isOn: $gitHubCopilotUseStrictSSL
            )
            .onChange(of: gitHubCopilotUseStrictSSL) { _ in refreshConfiguration() }
        }
    }

    func refreshConfiguration() {
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
}

#Preview {
    ProxySection()
}
