// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShixuWorkspace",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Shixu", targets: ["Shixu"])],
    targets: [
        .target(name: "DeskCore"),
        .executableTarget(name: "Shixu", dependencies: ["DeskCore"]),
        .executableTarget(name: "DeskCoreChecks", dependencies: ["DeskCore"], path: "Tests/DeskCoreChecks")
    ],
    swiftLanguageModes: [.v5]
)
