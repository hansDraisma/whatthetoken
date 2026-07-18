// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhatTheTokenMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WhatTheTokenMac", targets: ["WhatTheTokenMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.22.0")
    ],
    targets: [
        .executableTarget(
            name: "WhatTheTokenMac",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            exclude: [
                "Assets.xcassets"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WhatTheTokenMacTests",
            dependencies: ["WhatTheTokenMac"]
        )
    ],
    swiftLanguageModes: [.v6]
)
