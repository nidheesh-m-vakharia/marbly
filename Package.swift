// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Marbly",
    platforms: [.macOS(.v14)],
    targets: [
        // Sounds are copied into the app by scripts/bundle.sh; `swift run` reads them in place.
        .executableTarget(name: "Marbly", path: "Sources/Marbly", exclude: ["Resources"]),
        .testTarget(name: "MarblyTests", dependencies: ["Marbly"], path: "Tests/MarblyTests"),
    ]
)
