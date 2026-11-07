// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feierabend",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Feierabend", targets: ["Feierabend"]),
    ],
    targets: [
        .executableTarget(
            name: "Feierabend",
            path: "Sources/Feierabend",
            exclude: ["Info.plist", "App.entitlements"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
        .testTarget(
            name: "FeierabendTests",
            dependencies: ["Feierabend"],
            path: "Tests/FeierabendTests"
        ),
    ]
)
