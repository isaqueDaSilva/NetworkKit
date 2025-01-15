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
            targets: ["Common", "NetworkHandler", "WebSocketHandler"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.78.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Common"
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: ["Common"]
        ),
        .target(
            name: "NetworkHandler",
            dependencies: [.target(name: "Common")]
        ),
        .testTarget(
            name: "NetworkHandlerTests",
            dependencies: ["NetworkHandler"]
        ),
        .target(
            name: "WebSocketHandler",
            dependencies: [
                .target(name: "Common"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "WebSocketHandlerTests",
            dependencies: ["WebSocketHandler"]
        ),
    ]
)
