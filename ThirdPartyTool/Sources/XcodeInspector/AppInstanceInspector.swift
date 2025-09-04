import AppKit
import Foundation

public class AppInstanceInspector: ObservableObject {
    public let runningApplication: NSRunningApplication
    public let processIdentifier: pid_t
    public let bundleURL: URL?
    public let bundleIdentifier: String?

    public var appElement: AXUIElement { .fromRunningApplication(runningApplication) }

    public var isTerminated: Bool {
        return runningApplication.isTerminated
    }

    public var isActive: Bool {
        guard !runningApplication.isTerminated else { return false }
        return runningApplication.isActive
    }

    public var isXcode: Bool {
        guard !runningApplication.isTerminated else { return false }
        return runningApplication.isXcode
    }

    public var isExtensionService: Bool {
        guard !runningApplication.isTerminated else { return false }
        return runningApplication.isCopilotForXcodeExtensionService
    }

    public func activate() -> Bool {
        return runningApplication.activate()
    }
    
    public func activate(options: NSApplication.ActivationOptions) -> Bool {
        return runningApplication.activate(options: options)
    }

    public init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        processIdentifier = runningApplication.processIdentifier
        bundleURL = runningApplication.bundleURL
        bundleIdentifier = runningApplication.bundleIdentifier
    }
}

