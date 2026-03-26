// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Daily365",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Daily365",
            path: "Sources/Daily365",
            resources: [
                .copy("Resources/index.html")
            ]
        )
    ]
)
