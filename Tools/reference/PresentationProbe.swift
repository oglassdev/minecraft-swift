import Foundation
import ImageIO
import MetalKit
import MinecraftCore
import UniformTypeIdentifiers
import simd

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
        try verifyLeafCulling(device: device, queue: queue, library: library, atlas: atlas)
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
    private static func verifyLeafCulling(
        device: MTLDevice, queue: MTLCommandQueue, library: MTLLibrary, atlas: MTLTexture
    ) throws {
        guard MemoryLayout<Renderer.Uniforms>.stride == 144 else { throw failure("Uniform layout changed") }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "blockVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "blockFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw failure("Missing depth state")
        }
        let size = 96
        func render(_ vertices: [BlockVertex], eye: SIMD3<Float>, cull: MTLCullMode, leafRule: Bool) throws
            -> [UInt8]
        {
            let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
            colorDescriptor.storageMode = .shared
            colorDescriptor.usage = .renderTarget
            let zDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float, width: size, height: size, mipmapped: false)
            zDescriptor.usage = .renderTarget
            guard let color = device.makeTexture(descriptor: colorDescriptor),
                let z = device.makeTexture(descriptor: zDescriptor),
                let buffer = device.makeSharedBuffer(vertices), let command = queue.makeCommandBuffer()
            else { throw failure("Missing leaf render resources") }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = color
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.depthAttachment.texture = z
            pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.clearDepth = 1
            let forward = simd_normalize(SIMD3<Float>(1, 0.5, 0.5) - eye)
            let right = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
            let up = simd_cross(right, forward)
            let view = simd_float4x4(
                columns: (
                    SIMD4(right.x, up.x, -forward.x, 0), SIMD4(right.y, up.y, -forward.y, 0),
                    SIMD4(right.z, up.z, -forward.z, 0),
                    SIMD4(-simd_dot(right, eye), -simd_dot(up, eye), simd_dot(forward, eye), 1)
                ))
            let near: Float = 0.05
            let far: Float = 64
            let scale: Float = 1 / tan(Float.pi / 6)
            let projection = simd_float4x4(
                columns: (
                    SIMD4(scale, 0, 0, 0), SIMD4(0, scale, 0, 0),
                    SIMD4(0, 0, far / (near - far), -1), SIMD4(0, 0, far * near / (near - far), 0)
                ))
            var uniforms = Renderer.Uniforms(
                viewProjection: projection * view, renderOffset: .zero, cameraPosition: eye,
                fogColor: .zero, fogStart: 100, fogEnd: 200, skySubtraction: 0,
                fogDensity: 0, ambientFloor: 0.05, cullLeaves: leafRule ? 1 : 0)
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
                throw failure("Missing render encoder")
            }
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depth)
            encoder.setFrontFacing(.counterClockwise)
            encoder.setCullMode(cull)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Renderer.Uniforms>.stride, index: 1)
            encoder.setFragmentTexture(atlas, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            pixels.withUnsafeMutableBytes {
                color.getBytes(
                    $0.baseAddress!, bytesPerRow: size * 4,
                    from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
            }
            return pixels
        }
        var mismatchedOldPixels = 0
        for metadata: UInt8 in 0...2 {
            var world = BlockWorld()
            world.setBlock(BlockState(.leaves, metadata: metadata), at: BlockPosition(0, 0, 0))
            world.setBlock(BlockState(.leaves, metadata: (metadata + 1) % 3), at: BlockPosition(1, 0, 0))
            let vertices = BlockMesh(world: world, options: BlockMeshOptions(smoothLighting: false))
                .cutoutVertices
            for step in 0..<8 {
                let angle = Float(step) * Float.pi / 4 + 0.13
                let eye = SIMD3<Float>(1 + sin(angle) * 3, 1.3, 0.5 + cos(angle) * 3)
                let reference = try render(vertices, eye: eye, cull: .back, leafRule: false)
                let fixed = try render(vertices, eye: eye, cull: .none, leafRule: true)
                let old = try render(vertices, eye: eye, cull: .none, leafRule: false)
                guard reference == fixed else {
                    throw failure("Leaf back-face result differs from hardware culling")
                }
                guard stride(from: 3, to: reference.count, by: 4).contains(where: { reference[$0] > 0 })
                else {
                    throw failure("Empty leaf fixture")
                }
                mismatchedOldPixels +=
                    stride(from: 0, to: old.count, by: 4).filter {
                        old[$0..<($0 + 4)] != reference[$0..<($0 + 4)]
                    }.count
            }
        }
        guard mismatchedOldPixels > 0 else {
            throw failure("Leaf fixture did not reproduce the old overlap bug")
        }
        print(
            "Leaf culling: 24 views match hardware back-face culling; old renderer differed at \(mismatchedOldPixels) pixels"
        )
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
