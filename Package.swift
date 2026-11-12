// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Dusk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Dusk",
            path: "Sources/Dusk",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
