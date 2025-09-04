import Logger
import SwiftUI

struct LoggingSection: View {
    @AppStorage(\.verboseLoggingEnabled) var verboseLoggingEnabled: Bool
    @State private var shouldPresentRestartAlert = false

    var verboseLoggingBinding: Binding<Bool> {
        Binding(
            get: { verboseLoggingEnabled },
            set: {
                verboseLoggingEnabled = $0
                shouldPresentRestartAlert = $0
            }
        )
    }

    var body: some View {
        SettingsSection(title: "Logging") {
            SettingsToggle(
                title: "Verbose Logging",
                isOn: verboseLoggingBinding
            )
            Divider()
            SettingsLink(
                URL(fileURLWithPath: FileLoggingLocation.path.string),
                title: "Open Copilot Log Folder"
            )
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
        }
        .alert(isPresented: $shouldPresentRestartAlert) {
            Alert(
                title: Text("Quit And Restart Xcode"),
                message: Text(
                    """
                    Logging level changes will take effect the next time Copilot \
                    for Xcode is started. To update logging now, please quit \
                    Copilot for Xcode and restart Xcode.
                    """
                ),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    LoggingSection()
}
