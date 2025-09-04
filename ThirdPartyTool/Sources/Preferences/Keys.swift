import Foundation

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct PreferenceKey<T>: UserDefaultPreferenceKey {
    public let defaultValue: T
    public let key: String

    public init(defaultValue: T, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
}

public struct DeprecatedPreferenceKey<T> {
    public let defaultValue: T
    public let key: String

    public init(defaultValue: T, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
}

public struct FeatureFlag: UserDefaultPreferenceKey {
    public let defaultValue: Bool
    public let key: String

    public init(defaultValue: Bool, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
}

public struct UserDefaultPreferenceKeys {
    public init() {}

    // MARK: Quit XPC Service On Xcode And App Quit

    public let quitXPCServiceOnXcodeAndAppQuit = PreferenceKey(
        defaultValue: true,
        key: "QuitXPCServiceOnXcodeAndAppQuit"
    )

    // MARK: Suggestion Widget Position Mode

    public let suggestionWidgetPositionMode = PreferenceKey(
        defaultValue: SuggestionWidgetPositionMode.fixedToBottom,
        key: "SuggestionWidgetPositionMode"
    )

    // MARK: Widget Color Scheme

    public let widgetColorScheme = PreferenceKey(
        defaultValue: WidgetColorScheme.system,
        key: "WidgetColorScheme"
    )

    // MARK: Force Order Widget to Front

    public let forceOrderWidgetToFront = PreferenceKey(
        defaultValue: true,
        key: "ForceOrderWidgetToFront"
    )

    // MARK: Prefer Widget to Stay Inside Editor When Width Greater Than

    public let preferWidgetToStayInsideEditorWhenWidthGreaterThan = PreferenceKey(
        defaultValue: 1400 as Double,
        key: "PreferWidgetToStayInsideEditorWhenWidthGreaterThan"
    )

    // MARK: Hide Circular Widget

    public let hideCircularWidget = PreferenceKey(
        defaultValue: true,
        key: "HideCircularWidget"
    )

    public let showHideWidgetShortcutGlobally = PreferenceKey(
        defaultValue: false,
        key: "ShowHideWidgetShortcutGlobally"
    )

    // MARK: Update Channel

    public let installPrereleases = PreferenceKey(
        defaultValue: false,
        key: "InstallPrereleases"
    )

    // MARK: Completion Hint Shown

    public let completionHintShown = PreferenceKey(
        defaultValue: false,
        key: "CompletionHintShown"
    )

    // MARK: First Time Intro Interface

    public let introLastShownVersion = PreferenceKey(
        defaultValue: "",
        key: "IntroLastShownVersion"
    )

    public let hideIntro = PreferenceKey(
        defaultValue: false,
        key: "HideIntro"
    )

    public let extensionPermissionShown = PreferenceKey(
        defaultValue: false,
        key: "ExtensionPermissionShown"
    )
    
    public let capturePermissionShown = PreferenceKey(
        defaultValue: false,
        key: "CapturePermissionShown"
    )
}

// MARK: - Suggestion

public extension UserDefaultPreferenceKeys {
    var oldSuggestionFeatureProvider: DeprecatedPreferenceKey<BuiltInSuggestionFeatureProvider> {
        .init(defaultValue: .gitHubCopilot, key: "SuggestionFeatureProvider")
    }

    var suggestionFeatureProvider: PreferenceKey<SuggestionFeatureProvider> {
        .init(defaultValue: .builtIn(.gitHubCopilot), key: "NewSuggestionFeatureProvider")
    }

    var realtimeSuggestionToggle: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "RealtimeSuggestionToggle")
    }

    var suggestionDisplayCompactMode: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "SuggestionDisplayCompactMode")
    }

    var suggestionCodeFontSize: PreferenceKey<Double> {
        .init(defaultValue: 13, key: "SuggestionCodeFontSize")
    }

    var disableSuggestionFeatureGlobally: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "DisableSuggestionFeatureGlobally")
    }

    var suggestionFeatureEnabledProjectList: PreferenceKey<[String]> {
        .init(defaultValue: [], key: "SuggestionFeatureEnabledProjectList")
    }

    var suggestionFeatureDisabledLanguageList: PreferenceKey<[String]> {
        .init(defaultValue: [], key: "SuggestionFeatureDisabledLanguageList")
    }

    var hideCommonPrecedingSpacesInSuggestion: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "HideCommonPrecedingSpacesInSuggestion")
    }

    var suggestionPresentationMode: PreferenceKey<PresentationMode> {
        .init(defaultValue: .nearbyTextCursor, key: "SuggestionPresentationMode")
    }

    var realtimeSuggestionDebounce: PreferenceKey<Double> {
        .init(defaultValue: 0.2, key: "RealtimeSuggestionDebounce")
    }

    var acceptSuggestionWithTab: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "AcceptSuggestionWithTab")
    }

    var acceptSuggestionWithModifierCommand: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierCommand")
    }

    var acceptSuggestionWithModifierOption: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierOption")
    }

    var acceptSuggestionWithModifierControl: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierControl")
    }

    var acceptSuggestionWithModifierShift: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierShift")
    }

    var acceptSuggestionWithModifierOnlyForSwift: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierOnlyForSwift")
    }

    var dismissSuggestionWithEsc: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "DismissSuggestionWithEsc")
    }

    var isSuggestionSenseEnabled: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "IsSuggestionSenseEnabled")
    }

    var isSuggestionTypeInTheMiddleEnabled: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "IsSuggestionTypeInTheMiddleEnabled")
    }
    
    var clsWarningDismissedUntilRelaunch: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CLSWarningDismissedUntilRelaunch")
    }
}

// MARK: - Theme

public extension UserDefaultPreferenceKeys {
    var syncSuggestionHighlightTheme: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "SyncSuggestionHighlightTheme")
    }

    var syncChatCodeHighlightTheme: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SyncChatCodeHighlightTheme")
    }

    var codeForegroundColorLight: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeForegroundColorLight")
    }

    var codeForegroundColorDark: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeForegroundColorDark")
    }

    var codeBackgroundColorLight: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeBackgroundColorLight")
    }

    var codeBackgroundColorDark: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeBackgroundColorDark")
    }

    var currentLineBackgroundColorLight: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CurrentLineBackgroundColorLight")
    }

    var currentLineBackgroundColorDark: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CurrentLineBackgroundColorDark")
    }

    var codeFontLight: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "CodeFontLight"
        )
    }

    var codeFontDark: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "CodeFontDark"
        )
    }

    var suggestionCodeFont: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "SuggestionCodeFont"
        )
    }
}

// MARK: - Bing Search

public extension UserDefaultPreferenceKeys {
    var bingSearchSubscriptionKey: PreferenceKey<String> {
        .init(defaultValue: "", key: "BingSearchSubscriptionKey")
    }

    var bingSearchEndpoint: PreferenceKey<String> {
        .init(
            defaultValue: "https://api.bing.microsoft.com/v7.0/search/",
            key: "BingSearchEndpoint"
        )
    }
}
    
// MARK: - Feature Flags

public extension UserDefaultPreferenceKeys {
    var disableLazyVStack: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-DisableLazyVStack")
    }

    var preCacheOnFileOpen: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-PreCacheOnFileOpen")
    }

    var runNodeWithInteractiveLoggedInShell: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-RunNodeWithInteractiveLoggedInShell")
    }

    var useCustomScrollViewWorkaround: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-UseCustomScrollViewWorkaround")
    }

    var triggerActionWithAccessibilityAPI: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-TriggerActionWithAccessibilityAPI")
    }

    var alwaysAcceptSuggestionWithAccessibilityAPI: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-AlwaysAcceptSuggestionWithAccessibilityAPI")
    }

    var animationACrashSuggestion: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-AnimationACrashSuggestion")
    }

    var animationBCrashSuggestion: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-AnimationBCrashSuggestion")
    }

    var animationCCrashSuggestion: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-AnimationCCrashSuggestion")
    }

    var enableXcodeInspectorDebugMenu: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-EnableXcodeInspectorDebugMenu")
    }

    var disableFunctionCalling: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-DisableFunctionCalling")
    }

    var useUserDefaultsBaseAPIKeychain: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-UseUserDefaultsBaseAPIKeychain")
    }

    var disableGitHubCopilotSettingsAutoRefreshOnAppear: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-DisableGitHubCopilotSettingsAutoRefreshOnAppear"
        )
    }

    var disableEnhancedWorkspace: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-DisableEnhancedWorkspace"
        )
    }

    var restartXcodeInspectorIfAccessibilityAPIIsMalfunctioning: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-RestartXcodeInspectorIfAccessibilityAPIIsMalfunctioning"
        )
    }

    var restartXcodeInspectorIfAccessibilityAPIIsMalfunctioningNoTimer: FeatureFlag {
        .init(
            defaultValue: true,
            key: "FeatureFlag-RestartXcodeInspectorIfAccessibilityAPIIsMalfunctioningNoTimer"
        )
    }

    var toastForTheReasonWhyXcodeInspectorNeedsToBeRestarted: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-ToastForTheReasonWhyXcodeInspectorNeedsToBeRestarted"
        )
    }

    var observeToAXNotificationWithDefaultMode: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-observeToAXNotificationWithDefaultMode")
    }

    var useCloudflareDomainNameForLicenseCheck: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-UseCloudflareDomainNameForLicenseCheck")
    }
}

// MARK: - Advanced Features

public extension UserDefaultPreferenceKeys {

    var gitHubCopilotProxyUrl: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyUrl")
    }

    var gitHubCopilotUseStrictSSL: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "GitHubCopilotUseStrictSSL")
    }

    var gitHubCopilotProxyUsername: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyUsername")
    }

    var gitHubCopilotProxyPassword: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyPassword")
    }
    
    var gitHubCopilotMCPConfig: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotMCPConfig")
    }
    
    var gitHubCopilotMCPUpdatedStatus: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotMCPUpdatedStatus")
    }

    var gitHubCopilotEnterpriseURI: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotEnterpriseURI")
    }

    var verboseLoggingEnabled: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "VerboseLoggingEnabled")
    }
}
