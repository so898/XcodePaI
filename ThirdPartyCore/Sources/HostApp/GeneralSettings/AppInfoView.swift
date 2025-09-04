import ComposableArchitecture
import GitHubCopilotService
import SwiftUI

struct AppInfoView: View {
    class Settings: ObservableObject {
        @AppStorage(\.installPrereleases)
        var installPrereleases
    }

    @Environment(\.updateChecker) var updateChecker
    @Environment(\.toast) var toast

    @StateObject var settings = Settings()

    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    @State var automaticallyCheckForUpdates: Bool?

    let store: StoreOf<General>

    var body: some View {
        WithPerceptionTracking {
            HStack(alignment: .center, spacing: 16) {
                let appImage = if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                } else {
                    Image(systemName: "app")
                }
                appImage
                    .resizable()
                    .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String ?? "GitHub Copilot for Xcode")
                            .font(.title)
                        Text("(\(appVersion ?? ""))")
                            .font(.title)
                    }
                    Text("Language Server Version: \(store.xpcCLSVersion ?? "Loading...")")
                    Button(action: {
                        updateChecker.checkForUpdates()
                    }) {
                        HStack(spacing: 2) {
                            Text("Check for Updates")
                        }
                    }
                    HStack {
                        Toggle(isOn: .init(
                            get: { automaticallyCheckForUpdates ?? updateChecker.getAutomaticallyChecksForUpdates() },
                            set: { updateChecker.setAutomaticallyChecksForUpdates($0); automaticallyCheckForUpdates = $0 }
                        )) {
                            Text("Automatically Check for Updates")
                        }
                        
                        Toggle(isOn: $settings.installPrereleases) {
                            Text("Install pre-releases")
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 15)
        }
    }
}

#Preview {
    AppInfoView(
        store: .init(initialState: .init(), reducer: { General() })
    )
}
