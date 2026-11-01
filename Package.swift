// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinecraftSwift",
    products: [.library(name: "MinecraftCore", targets: ["MinecraftCore"])],
    targets: [
        .target(name: "MinecraftCore"),
        .testTarget(name: "MinecraftCoreTests", dependencies: ["MinecraftCore"]),
    ]
)
