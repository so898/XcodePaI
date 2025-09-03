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
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),
    ],
    targets: [
        // MARK: - Helpers
        .target(name: "MainAppService", dependencies: [
            "IPCServer",
            "SuggestionBasic"
        ]),
        .target(name: "EditExtensionService", dependencies: [
            "IPCClient",
            "SuggestionBasic"
        ]),
        
        .target(name: "IPCServer", dependencies: ["IPCShared"]),
        .target(name: "IPCClient", dependencies: ["IPCShared"]),
        
        .target(name: "IPCShared", dependencies: ["SuggestionBasic"]),
        
        .target(
            name: "SuggestionBasic",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "CodableWrappers", package: "CodableWrappers"),
            ]
        ),
    ]
)
