// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MySoundControl",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "MySoundControl", targets: ["MySoundControl"])],
    targets: [
        .target(name: "AudioDSP", linkerSettings: [.linkedFramework("CoreAudio")]),
        .target(name: "MixerLogic"),
        .executableTarget(name: "MySoundControl", dependencies: ["AudioDSP", "MixerLogic"]),
        .testTarget(name: "AudioDSPTests", dependencies: ["AudioDSP"]),
        .testTarget(name: "MixerLogicTests", dependencies: ["MixerLogic"])
    ],
    swiftLanguageModes: [.v5]
)
