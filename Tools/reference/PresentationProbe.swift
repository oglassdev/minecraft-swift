import Foundation
import ImageIO
import MetalKit
import MinecraftCore
import UniformTypeIdentifiers

/// Compile with the shared Apple sources (except MinecraftApp.swift) and MinecraftCore.
/// Arguments: asset directory, metallib, arrow oracle JSON, output directory.
@main
struct PresentationProbe {
    private struct ArrowCase: Decodable {
        var yaw: Float
        var pitch: Float
        var shake: Int
        var vertices: [[Double]]
    }

    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 5 else {
            throw failure("Expected assets, metallib, arrow oracle JSON, and output directory")
        }
        let arguments = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) }
        let assets = arguments[0]
        let output = arguments[3]
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let cases = try JSONDecoder().decode([ArrowCase].self, from: Data(contentsOf: arguments[2]))
        var maximumError: Double = 0
        var checked = 0
        for fixture in cases {
            let vertices = ArrowGeometry.vertices(
                position: .zero, yaw: fixture.yaw * Float.pi / 180,
                pitch: fixture.pitch * Float.pi / 180,
                shake: max(0, Float(fixture.shake) - 0.25), light: 255)
            let expected = stride(from: 0, to: fixture.vertices.count, by: 4).flatMap { start in
                [0, 1, 2, 0, 2, 3].map { fixture.vertices[start + $0] }
            }
            guard vertices.count == expected.count else { throw failure("Arrow vertex count") }
            for (vertex, reference) in zip(vertices, expected) {
                let actual = [
                    vertex.position.x, vertex.position.y, vertex.position.z, vertex.uv.x, vertex.uv.y,
                ]
                for (value, target) in zip(actual, reference) {
                    maximumError = max(maximumError, abs(Double(value) - target))
                }
                checked += 1
            }
        }
        guard maximumError < 0.00002 else { throw failure("Arrow geometry error: \(maximumError)") }
        print("Arrow parity: \(cases.count) poses, \(checked) vertices, maximum error \(maximumError)")

        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw failure("Metal unavailable")
        }
        let library = try device.makeLibrary(URL: arguments[1])
        let atlas = try await MTKTextureLoader(device: device).newTexture(
            URL: assets.appendingPathComponent("terrain.png"),
            options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false])
        TextureResources.configure(overrideURL: assets, revision: 1)
        let images = InventoryRenderImages.shared
        try images.configure(device: device, atlas: atlas, library: library, queue: queue)
        for scale in 1...4 {
            for id: UInt16 in [1, 2, 5, 17, 35, 44, 53, 85] {
                let image = try await wait {
                    images.image(for: ItemStack(id: id), rasterScale: scale)
                }
                guard image.width == 16 * scale && image.height == 16 * scale else {
                    throw failure("Icon raster size")
                }
                try write(image, to: output.appendingPathComponent("item-\(id)-scale-\(scale).png"))
            }
            let image = try await wait {
                let image = images.playerPreview(
                    armor: [nil, nil, nil, nil], heldItem: nil, pointer: SIMD2(0, -50), rasterScale: scale)
                return image?.width == 64 * scale ? image : nil
            }
            guard image.height == 80 * scale else { throw failure("Preview raster size") }
            try write(image, to: output.appendingPathComponent("player-scale-\(scale).png"))
        }
        print("Metal presentation: 32 icons and 4 player previews rendered at native GUI raster scales")
    }

    @MainActor
    private static func wait(_ image: () -> CGImage?) async throws -> CGImage {
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while ContinuousClock.now < deadline {
            if let result = image() { return result }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw failure("Timed out waiting for offscreen Metal image")
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw failure("Cannot create PNG") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw failure("Cannot write PNG") }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "PresentationProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
