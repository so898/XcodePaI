import Foundation
import AppKit
import Logger

public let HostAppURL = locateHostBundleURL(url: Bundle.main.bundleURL)

public extension Notification.Name {
    static let openSettingsWindowRequest = Notification
        .Name("com.tpp.CopilotForXcode.OpenSettingsWindowRequest")
}

public enum GitHubCopilotForXcodeSettingsLaunchError: Error, LocalizedError {
    case appNotFound
    case openFailed(errorDescription: String)

    public var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "\(hostAppName()) settings application not found"
        case let .openFailed(errorDescription):
            return "Failed to launch \(hostAppName()) settings (\(errorDescription))"
        }
    }
}

public func getRunningHostApp() -> NSRunningApplication? {
    return NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == (Bundle.main.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String)
    })
}

public func launchHostAppSettings() throws {
    // Try the AppleScript approach first, but only if app is already running
    if let hostApp = getRunningHostApp() {
        let activated = hostApp.activate(options: [.activateIgnoringOtherApps])
        Logger.ui.info("\(hostAppName()) activated: \(activated)")

        let scriptSuccess = tryLaunchWithAppleScript()
        
        // If AppleScript fails, fall back to notification center
        if !scriptSuccess {
            DistributedNotificationCenter.default().postNotificationName(
                .openSettingsWindowRequest,
                object: nil
            )
            Logger.ui.info("\(hostAppName()) settings notification sent after activation")
            return
        }
    } else {
        // If app is not running, launch it with the settings flag
        try launchHostAppWithArgs(args: ["--settings"])
    }
}

private func tryLaunchWithAppleScript() -> Bool {
    // Try to launch settings using AppleScript
    let script = """
    tell application "\(hostAppName())"
        activate
        tell application "System Events"
            keystroke "," using command down
        end tell
    end tell
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        scriptObject.executeAndReturnError(&error)
        
        // Log the result
        if let error = error {
            Logger.ui.info("\(hostAppName()) settings script error: \(error)")
            return false
        }
        
        Logger.ui.info("\(hostAppName()) settings opened successfully via AppleScript")
        return true
    }
    
    return false
}

public func launchHostAppDefault() throws {
    try launchHostAppWithArgs(args: nil)
}

func launchHostAppWithArgs(args: [String]?) throws {
    guard let appURL = HostAppURL else {
        throw GitHubCopilotForXcodeSettingsLaunchError.appNotFound
    }
    
    Task {
        let configuration = NSWorkspace.OpenConfiguration()
        if let args {
            configuration.arguments = args
        }
        configuration.activates = true
        
        try await NSWorkspace.shared
            .openApplication(at: appURL, configuration: configuration)
    }
}

func locateHostBundleURL(url: URL) -> URL? {
    var nextURL = url
    while nextURL.path != "/" {
        nextURL = nextURL.deletingLastPathComponent()
        if nextURL.lastPathComponent.hasSuffix(".app") {
            return nextURL
        }
    }
    let devAppURL = url
        .deletingLastPathComponent()
        .appendingPathComponent("GitHub Copilot for Xcode Dev.app")
    return devAppURL
}

func hostAppName() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
        ?? "GitHub Copilot for Xcode"
}
