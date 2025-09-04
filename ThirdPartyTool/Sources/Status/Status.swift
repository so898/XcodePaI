import AppKit
import Foundation

@objc public enum ExtensionPermissionStatus: Int {
    case unknown = -1, notGranted = 0, disabled = 1, granted = 2
}

@objc public enum ObservedAXStatus: Int {
    case unknown = -1, granted = 1, notGranted = 0
}

private struct AccessibilityStatusInfo {
    let icon: StatusResponse.Icon?
    let message: String?
    let url: String?
}

public extension Notification.Name {
    static let serviceStatusDidChange = Notification.Name("com.tpp.CopilotForXcode.serviceStatusDidChange")
}

private var currentUserName: String? = nil
private var currentUserCopilotPlan: String? = nil

public final actor Status {
    public static let shared = Status()

    private var extensionStatus: ExtensionPermissionStatus = .unknown
    private var axStatus: ObservedAXStatus = .unknown
    
    private let okIcon = StatusResponse.Icon(name: "MenuBarIcon")
    private let errorIcon = StatusResponse.Icon(name: "MenuBarErrorIcon")
    private let warningIcon = StatusResponse.Icon(name: "MenuBarWarningIcon")
    private let inactiveIcon = StatusResponse.Icon(name: "MenuBarInactiveIcon")

    private init() {}

    public static func currentUser() -> String? {
        return currentUserName
    }
    
    public func currentUserPlan() -> String? {
        return currentUserCopilotPlan
    }

    public func updateExtensionStatus(_ status: ExtensionPermissionStatus) {
        guard status != extensionStatus else { return }
        extensionStatus = status
        broadcast()
    }

    public func updateAXStatus(_ status: ObservedAXStatus) {
        guard status != axStatus else { return }
        axStatus = status
        broadcast()
    }
    
    public func getExtensionStatus() -> ExtensionPermissionStatus {
        extensionStatus
    }

    public func getAXStatus() -> ObservedAXStatus {
        if isXcodeRunning() {
            return axStatus
        } else if AXIsProcessTrusted() {
            return .granted
        } else {
            return axStatus
        }
    }

    private func isXcodeRunning() -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dt.Xcode"
        ).isEmpty
    }

    public func getStatus() -> StatusResponse {
        let extensionStatusIcon = (
            extensionStatus == ExtensionPermissionStatus.disabled || extensionStatus == ExtensionPermissionStatus.notGranted
        ) ? errorIcon : nil
        let accessibilityStatusInfo: AccessibilityStatusInfo = getAccessibilityStatusInfo()
        return .init(
            icon: extensionStatusIcon ?? accessibilityStatusInfo.icon ?? okIcon,
            message: accessibilityStatusInfo.message,
            extensionStatus: extensionStatus,
            url: accessibilityStatusInfo.url,
        )
    }

    private func getAccessibilityStatusInfo() -> AccessibilityStatusInfo {
        switch getAXStatus() {
        case .granted:
            return AccessibilityStatusInfo(icon: nil, message: nil, url: nil)
        case .notGranted:
            return AccessibilityStatusInfo(
                icon: errorIcon,
                message: """
                Enable accessibility in system preferences
                """,
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        case .unknown:
            return AccessibilityStatusInfo(
                icon: errorIcon,
                message: """
                Enable accessibility or restart Copilot
                """,
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .serviceStatusDidChange, object: nil)
        // Can remove DistributedNotificationCenter if the settings UI moves in-process
        DistributedNotificationCenter.default().post(name: .serviceStatusDidChange, object: nil)
    }
}
