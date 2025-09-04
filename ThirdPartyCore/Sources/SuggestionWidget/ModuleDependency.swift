import ActiveApplicationMonitor
import AppKit
import ComposableArchitecture
import Dependencies
import Foundation
import Preferences
import SwiftUI
import UserDefaultsObserver
import XcodeInspector

public final class SuggestionWidgetControllerDependency {
    public var suggestionWidgetDataSource: SuggestionWidgetDataSource?
    var windowsController: WidgetWindowsController?

    public init() {}
}

public final class WidgetUserDefaultsObservers {
    let presentationModeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionPresentationMode.key,
        ], context: nil
    )
    let xcodeColorSchemeChangeObserver = UserDefaultsObserver(
        object: UserDefaults(suiteName: "com.apple.dt.Xcode")!,
        forKeyPaths: ["xcodeColorScheme"],
        context: nil
    )
    let systemColorSchemeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.standard,
        forKeyPaths: ["AppleInterfaceStyle"],
        context: nil
    )

    public init() {}
}

struct SuggestionWidgetControllerDependencyKey: DependencyKey {
    static let liveValue = SuggestionWidgetControllerDependency()
}

struct UserDefaultsDependencyKey: DependencyKey {
    static let liveValue = WidgetUserDefaultsObservers()
}

struct XcodeInspectorKey: DependencyKey {
    static let liveValue = XcodeInspector.shared
}

struct ActiveApplicationMonitorKey: DependencyKey {
    static let liveValue = ActiveApplicationMonitor.shared
}

public extension DependencyValues {
    var suggestionWidgetControllerDependency: SuggestionWidgetControllerDependency {
        get { self[SuggestionWidgetControllerDependencyKey.self] }
        set { self[SuggestionWidgetControllerDependencyKey.self] = newValue }
    }

    var suggestionWidgetUserDefaultsObservers: WidgetUserDefaultsObservers {
        get { self[UserDefaultsDependencyKey.self] }
        set { self[UserDefaultsDependencyKey.self] = newValue }
    }
}

extension DependencyValues {
    var xcodeInspector: XcodeInspector {
        get { self[XcodeInspectorKey.self] }
        set { self[XcodeInspectorKey.self] = newValue }
    }

    var activeApplicationMonitor: ActiveApplicationMonitor {
        get { self[ActiveApplicationMonitorKey.self] }
        set { self[ActiveApplicationMonitorKey.self] = newValue }
    }
}

