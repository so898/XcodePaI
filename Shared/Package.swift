// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MainAppService", targets: ["MainAppService"]),
        .library(name: "EditExtensionService", targets: ["EditExtensionService"]),
    ],
    dependencies: [
        .package(path: "../ThirdParty"),
    ],
    targets: [
        // MARK: - Helpers
        .target(name: "MainAppService", dependencies: [
            "IPCServer",
        ]),
        .target(name: "EditExtensionService", dependencies: [
            "IPCClient",
        ]),
        
        .target(name: "IPCServer", dependencies: [
            "IPCShared",
        ]),
        .target(name: "IPCClient", dependencies: [
            "IPCShared",
        ]),
        
        .target(name: "IPCShared", dependencies: [
            .product(name: "SuggestionBasic", package: "ThirdParty"),
        ]),
        
    ]
)
