// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Spotlite",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Spotlite",
            path: "Sources/Spotlite",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
