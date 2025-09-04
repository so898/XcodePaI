// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThirdPartyTool",
    platforms: [.macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "Preferences", targets: ["Preferences", "Configs"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "SystemUtils", targets: ["SystemUtils"]),
        .library(name: "FileSystem", targets: ["FileSystem"]),
        .library(name: "SuggestionBasic", targets: ["SuggestionBasic"]),
        .library(name: "Toast", targets: ["Toast"]),
        .library(name: "SharedUIComponents", targets: ["SharedUIComponents"]),
        .library(name: "Status", targets: ["Status"]),
        .library(name: "UserDefaultsObserver", targets: ["UserDefaultsObserver"]),
        .library(name: "Workspace", targets: ["Workspace", "WorkspaceSuggestionService"]),
        .library(
            name: "SuggestionProvider",
            targets: ["SuggestionProvider"]
        ),
        
            .library(
                name: "GitHubCopilotService",
                targets: ["GitHubCopilotService"]
            ),
        .library(
            name: "BuiltinExtension",
            targets: ["BuiltinExtension"]
        ),
        .library(
            name: "AppMonitoring",
            targets: [
                "XcodeInspector",
                "ActiveApplicationMonitor",
                "AXExtension",
                "AXNotificationStream",
                "AppActivator",
            ]
        ),
        .library(name: "DebounceFunction", targets: ["DebounceFunction"]),
        .library(name: "AsyncPassthroughSubject", targets: ["AsyncPassthroughSubject"]),
        .library(name: "CustomAsyncAlgorithms", targets: ["CustomAsyncAlgorithms"]),
        .library(name: "AXHelper", targets: ["AXHelper"]),
        .library(name: "HostAppActivator", targets: ["HostAppActivator"]),
        .library(name: "AppKitExtension", targets: ["AppKitExtension"]),
        .library(name: "SuggestionPortal", targets: ["SuggestionPortal"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        .package(url: "https://github.com/devm33/CopilotForXcodeKit", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SuggestionBasic",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "CodableWrappers", package: "CodableWrappers"),
            ]
        ),
        .target(
            name: "XcodeInspector",
            dependencies: [
                "AXExtension",
                "SuggestionBasic",
                "AXNotificationStream",
                "Logger",
                "Toast",
                "Preferences",
                "AsyncPassthroughSubject",
                "Status",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .target(name: "AXExtension"),
        .target(
            name: "AXNotificationStream",
            dependencies: [
                "Preferences",
                "Logger",
                "Status",
            ]
        ),
        .target(
            name: "AXHelper",
            dependencies: [
                "XcodeInspector"
            ]
        ),
        .target(
            name: "Status"
        ),
        .target(name: "Configs"),
        .target(name: "Preferences", dependencies: ["Configs"]),
        .target(name: "Logger"),
        .target(name: "FileSystem"),
        .target(
            name: "CustomAsyncAlgorithms",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .target(
            name: "Toast",
            dependencies: [
                "AppKitExtension",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(name: "DebounceFunction"),
        .target(
            name: "AppActivator",
            dependencies: [
                "XcodeInspector",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(name: "ActiveApplicationMonitor"),
        .target(
            name: "HostAppActivator",
            dependencies: [
                "Logger",
            ]
        ),
        .target(name: "UserDefaultsObserver"),
        .target(name: "AsyncPassthroughSubject"),
        .target(
            name: "BuiltinExtension",
            dependencies: [
                "SuggestionBasic",
                "SuggestionProvider",
                "Workspace",
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
            ]
        ),
        .target(
            name: "SharedUIComponents",
            dependencies: [
                "Preferences",
                "SuggestionBasic",
                "DebounceFunction",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Workspace",
            dependencies: [
                "UserDefaultsObserver",
                "SuggestionBasic",
                "Logger",
                "Preferences",
                "XcodeInspector",
            ]
        ),
        .target(
            name: "WorkspaceSuggestionService",
            dependencies: [
                "Workspace",
                "SuggestionProvider",
                "BuiltinExtension",
                "GitHubCopilotService",
            ]
        ),
        .target(name: "SuggestionProvider", dependencies: [
            "SuggestionBasic",
            "UserDefaultsObserver",
            "Preferences",
            "Logger",
            .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
        ]),
        .target(
            name: "GitHubCopilotService",
            dependencies: [
                "SuggestionBasic",
                "Logger",
                "Preferences",
                "BuiltinExtension",
                "Status",
                "SystemUtils",
                "Workspace",
                "SuggestionPortal",
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
            ]
        ),
        .target(
            name: "SystemUtils",
            dependencies: ["Logger"]
        ),
        .target(
            name: "AppKitExtension",
            dependencies: ["Logger"]
        ),
        .target(name: "SuggestionPortal", dependencies: [
            "SuggestionBasic",
        ]),
    ]
)
