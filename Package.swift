// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MySoundControl",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "MySoundControl", targets: ["MySoundControl"])],
    targets: [
        .target(name: "AudioDSP", linkerSettings: [.linkedFramework("CoreAudio")]),
        .executableTarget(name: "MySoundControl", dependencies: ["AudioDSP"]),
        .testTarget(name: "AudioDSPTests", dependencies: ["AudioDSP"])
    ],
    swiftLanguageModes: [.v5]
)
