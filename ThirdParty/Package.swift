// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThirdParty",
    platforms: [.macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "SuggestionBasic", targets: ["SuggestionBasic"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),
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

    ]
)
