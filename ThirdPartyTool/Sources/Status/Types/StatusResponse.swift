import AppKit

public struct StatusResponse {
    public struct Icon {
        /// Name of the icon resource
        public let name: String

        public init(name: String) {
            self.name = name
        }

        public var nsImage: NSImage? {
            return NSImage(named: name)
        }
    }

    /// The icon to display in the menu bar
    public let icon: Icon
    /// Additional message (for accessibility or extension status)
    public let message: String?
    /// Extension status
    public let extensionStatus: ExtensionPermissionStatus
    /// URL for system preferences or other actions
    public let url: String?
}
