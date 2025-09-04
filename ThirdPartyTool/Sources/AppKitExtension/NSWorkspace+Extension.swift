import AppKit
import Logger

extension NSWorkspace {
    public static func getXcodeBundleURL() -> URL? {
        var xcodeBundleURL: URL?
        
        // Get currently running Xcode application URL
        if let xcodeApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dt.Xcode" }) {
            xcodeBundleURL = xcodeApp.bundleURL
        }
        
        // Fallback to standard path if we couldn't get the running instance
        if xcodeBundleURL == nil {
            let standardPath = "/Applications/Xcode.app"
            if FileManager.default.fileExists(atPath: standardPath) {
                xcodeBundleURL = URL(fileURLWithPath: standardPath)
            }
        }
        
        return xcodeBundleURL
    }
    
    public static func openFileInXcode(
        fileURL: URL, 
        completion: ((NSRunningApplication?, Error?) -> Void)? = nil
    ) {
        guard let xcodeBundleURL = Self.getXcodeBundleURL() else {
            if let completion = completion {
                completion(nil, NSError(domain: "The Xcode app is not found.", code: 0))
            }
            return
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = false
        
        Self.shared.open(
            [fileURL],
            withApplicationAt: xcodeBundleURL,
            configuration: configuration
        ) { app, error in
            if let completion = completion {
                completion(app, error)
            } else if let error = error {
                Logger.client.error("Failed to open file \(String(describing: error))")
            }
        }
    }
}
