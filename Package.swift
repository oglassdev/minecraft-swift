// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinecraftSwift",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "MinecraftCore", targets: ["MinecraftCore"])],
    targets: [
        .systemLibrary(name: "CZlib", providers: [.apt(["zlib1g-dev"])]),
        .target(name: "MinecraftCore", dependencies: ["CZlib"]),
        .testTarget(
            name: "MinecraftCoreTests", dependencies: ["MinecraftCore"], resources: [.process("Fixtures")]),
    ]
)
