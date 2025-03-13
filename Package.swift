// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .tvOS(.v17),
        .visionOS(.v1),
        .watchOS(.v10)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NetworkKit",
            targets: ["NetworkHandler", "WebSocketHandler"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NetworkHandler"
        ),
        .testTarget(
            name: "NetworkHandlerTests",
            dependencies: ["NetworkHandler"]
        ),
        .target(
            name: "WebSocketHandler",
            dependencies: ["NetworkHandler"]
        ),
        .testTarget(
            name: "WebSocketHandlerTests",
            dependencies: ["WebSocketHandler"]
        ),
    ]
)
