// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "ThirdPartyCore",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../ThirdPartyTool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/intitni/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "SuggestionProvider", package: "ThirdPartyTool"),
                .product(name: "Workspace", package: "ThirdPartyTool"),
                .product(name: "UserDefaultsObserver", package: "ThirdPartyTool"),
                .product(name: "AppMonitoring", package: "ThirdPartyTool"),
                .product(name: "SuggestionBasic", package: "ThirdPartyTool"),
                .product(name: "Status", package: "ThirdPartyTool"),
                .product(name: "Logger", package: "ThirdPartyTool"),
                .product(name: "Preferences", package: "ThirdPartyTool"),
                .product(name: "AXHelper", package: "ThirdPartyTool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "ThirdPartyTool"),
                    .product(name: "Preferences", package: "ThirdPartyTool"),
                    .product(name: "SuggestionBasic", package: "ThirdPartyTool"),
                    .product(name: "SuggestionProvider", package: "ThirdPartyTool"),
                    .product(name: "BuiltinExtension", package: "ThirdPartyTool"),
                    .product(name: "GitHubCopilotService", package: "ThirdPartyTool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "ThirdPartyTool")]
        ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    .product(name: "AXHelper", package: "ThirdPartyTool"),
                    .product(name: "GitHubCopilotService", package: "ThirdPartyTool"),
                    .product(name: "Toast", package: "ThirdPartyTool"),
                    .product(name: "UserDefaultsObserver", package: "ThirdPartyTool"),
                    .product(name: "SharedUIComponents", package: "ThirdPartyTool"),
                    .product(name: "AppMonitoring", package: "ThirdPartyTool"),
                    .product(name: "Logger", package: "ThirdPartyTool"),
                    .product(name: "CustomAsyncAlgorithms", package: "ThirdPartyTool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - Helpers
        
        .target(name: "FileChangeChecker"),
        
        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "ThirdPartyTool"),
                .product(name: "AppMonitoring", package: "ThirdPartyTool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),
        
        // MARK: Key Binding
        
            .target(
                name: "KeyBindingManager",
                dependencies: [
                    .product(name: "Workspace", package: "ThirdPartyTool"),
                    .product(name: "Preferences", package: "ThirdPartyTool"),
                    .product(name: "Logger", package: "ThirdPartyTool"),
                    .product(name: "CGEventOverride", package: "CGEventOverride"),
                    .product(name: "AppMonitoring", package: "ThirdPartyTool"),
                    .product(name: "UserDefaultsObserver", package: "ThirdPartyTool"),
                ]
            ),
    ]
)
