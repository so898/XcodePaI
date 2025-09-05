// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "MainAppService", targets: ["MainAppService"]),
        .library(name: "EditExtensionService", targets: ["EditExtensionService"]),
    ],
    dependencies: [
        .package(path: "../ThirdPartyTool"),
        .package(path: "../ThirdPartyCore"),
    ],
    targets: [
        // MARK: - Helpers
        .target(name: "MainAppService", dependencies: [
            "IPCServer",
            .product(name: "AppMonitoring", package: "ThirdPartyTool"),
        ]),
        .target(name: "EditExtensionService", dependencies: [
            "IPCClient",
        ]),
        
        .target(name: "IPCServer", dependencies: [
            "IPCShared",
            .product(name: "Service", package: "ThirdPartyCore"),
        ]),
        .target(name: "IPCClient", dependencies: [
            "IPCShared",
        ]),
        
        .target(name: "IPCShared", dependencies: [
            .product(name: "SuggestionBasic", package: "ThirdPartyTool"),
        ]),
        
    ]
)
