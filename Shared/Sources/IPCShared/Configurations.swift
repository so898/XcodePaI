import Foundation

private var teamIDPrefix: String {
    Bundle.main.infoDictionary?["TEAM_ID_PREFIX"] as? String ?? ""
}

private var bundleIdentifierBase: String {
    Bundle.main.infoDictionary?["BUNDLE_IDENTIFIER_BASE"] as? String ?? ""
}

public var groupBundleId: String {
    "\(teamIDPrefix)group.\(bundleIdentifierBase)"
}
