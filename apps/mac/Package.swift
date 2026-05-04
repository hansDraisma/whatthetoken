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
    targets: [
        .executableTarget(
            name: "WhatTheTokenMac",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WhatTheTokenMacTests",
            dependencies: ["WhatTheTokenMac"]
        )
    ]
)
