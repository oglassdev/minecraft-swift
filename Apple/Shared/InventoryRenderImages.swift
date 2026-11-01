import Combine
import CoreGraphics
@preconcurrency import MetalKit
import MinecraftCore
import simd

@MainActor
final class InventoryRenderImages: ObservableObject {
    static let shared = InventoryRenderImages()
    @Published private(set) var revision: UInt64 = 0
    private var images: [UInt64: CGImage] = [:]
    private var requested: Set<UInt64> = []
    private var waiting: [(stack: ItemStack, scale: Int)] = []
    private var active = 0
    private var generation: UInt64 = 0
    private var device: MTLDevice?
    private var queue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var depth: MTLDepthStencilState?
    private var atlas: MTLTexture?
    private var textures: NamedTextures?
    private var preview: CGImage?
    private var previewKey: PreviewRequest?
    private var pendingPreview: PreviewRequest?
    private var previewActive = false

    private struct PreviewRequest: Equatable {
        var armor: [ItemStack?]
        var held: ItemStack?
        var pointer: SIMD2<Int>
        var scale: Int
    }

    private struct Batch {
        var vertices: [BlockVertex]
        var texture: MTLTexture
    }

    func configure(device: MTLDevice, atlas: MTLTexture, library: MTLLibrary, queue: MTLCommandQueue) throws {
        guard self.atlas !== atlas else { return }
        generation &+= 1
        images.removeAll()
        requested.removeAll()
        waiting.removeAll()
        textures = NamedTextures(device: device)
        preview = nil
        previewKey = nil
        pendingPreview = nil
        revision &+= 1
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "blockVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "blockFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let state = MTLDepthStencilDescriptor()
        state.depthCompareFunction = .lessEqual
        state.isDepthWriteEnabled = true
        depth = device.makeDepthStencilState(descriptor: state)
        self.device = device
        self.atlas = atlas
        self.queue = queue
        pump()
    }

    func image(for stack: ItemStack, rasterScale: Int = 2) -> CGImage? {
        guard HeldItemGeometry.rendersAsBlock(stack.id) else { return nil }
        let scale = max(1, rasterScale)
        let key = iconKey(stack, scale: scale)
        if let image = images[key] { return image }
        if requested.insert(key).inserted {
            waiting.append((stack, scale))
            pump()
        }
        return nil
    }

    /// The pointer is relative to the original GUI model's feet at (51,75).
    func playerPreview(
        armor: [ItemStack?], heldItem: ItemStack?, pointer: SIMD2<Float>, rasterScale: Int = 2
    ) -> CGImage? {
        let request = PreviewRequest(
            armor: armor, held: heldItem,
            pointer: SIMD2(Int(pointer.x.rounded(.towardZero)), Int(pointer.y.rounded(.towardZero))),
            scale: max(1, rasterScale))
        if previewKey != request && pendingPreview != request {
            pendingPreview = request
            pump()
        }
        return preview
    }

    private func pump() {
        guard let atlas else { return }
        while active < 2 && !waiting.isEmpty {
            let (stack, scale) = waiting.removeFirst()
            let key = iconKey(stack, scale: scale)
            guard let kind = BlockKind(rawValue: UInt8(stack.id)) else { continue }
            var world = BlockWorld()
            world.setBlock(
                BlockState(kind, metadata: UInt8(truncatingIfNeeded: stack.damage)),
                at: BlockPosition(0, 0, 0))
            let source = BlockMesh(
                world: world, blockAt: BlockPosition(0, 0, 0),
                options: BlockMeshOptions(smoothLighting: false, inventory: true)
            ).vertices
            let t = HeldItemGeometry.translation
            let r = HeldItemGeometry.rotation
            let model =
                t(SIMD3(-2, 3, -3)) * HeldItemGeometry.scale(10) * t(SIMD3(1, 0.5, 1))
                * simd_float4x4(diagonal: SIMD4(1, 1, -1, 1))
                * r(210, SIMD3(1, 0, 0)) * r(45, SIMD3(0, 1, 0))
                * r(-90, SIMD3(0, 1, 0)) * t(SIMD3(repeating: -0.5))
            let normals = simd_float3x3(
                columns: (
                    SIMD3(model.columns.0.x, model.columns.0.y, model.columns.0.z),
                    SIMD3(model.columns.1.x, model.columns.1.y, model.columns.1.z),
                    SIMD3(model.columns.2.x, model.columns.2.y, model.columns.2.z)
                ))
            var vertices: [BlockVertex] = []
            for start in stride(from: 0, to: source.count, by: 6) {
                let face = source[start..<min(start + 6, source.count)]
                guard face.count == 6 else { continue }
                let a = source[start].position
                let normal = simd_normalize(
                    simd_cross(source[start + 1].position - a, source[start + 2].position - a))
                let flatShade: Float =
                    abs(normal.y) > 0.9 ? (normal.y > 0 ? 1 : 0.5) : (abs(normal.z) > 0.9 ? 0.8 : 0.6)
                let shade = BetaLighting.guiShade(normal: simd_normalize(normals * normal))
                vertices += face.map {
                    let point = model * SIMD4($0.position, 1)
                    return BlockVertex(
                        position: SIMD3(point.x, point.y, point.z),
                        color: $0.color / flatShade * shade, uv: $0.uv, light: 255)
                }
            }
            active += 1
            let generation = self.generation
            if !render(
                batches: [Batch(vertices: vertices, texture: atlas)], width: 16 * scale, height: 16 * scale,
                logicalSize: SIMD2(16, 16),
                completion: { [weak self] image in
                    guard let self else { return }
                    if self.generation == generation, let image {
                        self.images[key] = image
                        self.revision &+= 1
                    }
                    self.active -= 1
                    self.pump()
                })
            {
                active -= 1
            }
        }
        guard !previewActive, let request = pendingPreview else { return }
        pendingPreview = nil
        previewActive = true
        let generation = self.generation
        let batches = previewBatches(request)
        if !render(
            batches: batches, width: 64 * request.scale, height: 80 * request.scale,
            logicalSize: SIMD2(64, 80),
            completion: { [weak self] image in
                guard let self else { return }
                if self.generation == generation, let image {
                    self.preview = image
                    self.previewKey = request
                    self.revision &+= 1
                }
                self.previewActive = false
                self.pump()
            })
        {
            previewActive = false
        }
    }

    private func previewBatches(_ request: PreviewRequest) -> [Batch] {
        let horizontal = atan(-Float(request.pointer.x) / 40)
        let vertical = atan((-50 - Float(request.pointer.y)) / 40)
        var entity = GameEntity(id: 0, kind: "player", position: .zero)
        entity.contents = [request.held] + request.armor
        entity.pitch = vertical * 20 * BetaVisualMath.pi / 180
        let bodyYaw = horizontal * 20 * BetaVisualMath.pi / 180
        let tilt = HeldItemGeometry.rotation(-vertical * 20, axis: SIMD3(1, 0, 0))
        let lighting = HeldItemGeometry.rotation(-135, axis: SIMD3(0, 1, 0)) * tilt
        let lightTransform = simd_float3x3(
            columns: (
                SIMD3(lighting.columns.0.x, lighting.columns.0.y, lighting.columns.0.z),
                SIMD3(lighting.columns.1.x, lighting.columns.1.y, lighting.columns.1.z),
                SIMD3(lighting.columns.2.x, lighting.columns.2.y, lighting.columns.2.z)
            ))
        var result: [Batch] = []
        for layer in EntityModels.layers(entity: entity, phase: 0, amplitude: 0, age: 0, headYaw: bodyYaw) {
            guard let texture = textures?.texture(layer.texture) else { continue }
            let source = layer.parts.flatMap {
                $0.vertices(
                    position: .zero, yaw: bodyYaw - BetaVisualMath.pi, scale: layer.scale,
                    originY: layer.originY, tint: layer.tint, light: 255, opacity: 1,
                    transform: layer.transform, lightTransform: lightTransform)
            }
            let vertices = source.map {
                let point = tilt * SIMD4($0.position, 1)
                return BlockVertex(
                    position: SIMD3(32 + point.x * 30, 75 - point.y * 30, point.z * 30),
                    color: $0.color, uv: $0.uv, light: 255)
            }
            result.append(Batch(vertices: vertices, texture: texture))
        }
        return result
    }

    private func iconKey(_ stack: ItemStack, scale: Int) -> UInt64 {
        UInt64(stack.id) << 32 | UInt64(stack.damage & 15) << 16 | UInt64(scale)
    }

    private func render(
        batches: [Batch], width: Int, height: Int, logicalSize: SIMD2<Float>,
        completion: @escaping @MainActor @Sendable (CGImage?) -> Void
    ) -> Bool {
        guard let device, let queue, let pipeline, let depth, let command = queue.makeCommandBuffer() else {
            return false
        }
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        colorDescriptor.usage = [.renderTarget, .shaderRead]
        colorDescriptor.storageMode = .shared
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDescriptor.usage = .renderTarget
        guard let color = device.makeTexture(descriptor: colorDescriptor),
            let z = device.makeTexture(descriptor: depthDescriptor)
        else { return false }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.depthAttachment.texture = z
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        let projection = simd_float4x4(
            columns: (
                SIMD4(2 / logicalSize.x, 0, 0, 0), SIMD4(0, -2 / logicalSize.y, 0, 0), SIMD4(0, 0, -0.001, 0),
                SIMD4(-1, 1, 0.5, 1)
            ))
        var uniforms = Renderer.Uniforms(
            viewProjection: projection, renderOffset: .zero, cameraPosition: .zero,
            fogColor: .zero, fogStart: 1000, fogEnd: 2000, skySubtraction: 0, fogDensity: 0,
            ambientFloor: 0.05)
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depth)
        encoder.setCullMode(.none)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Renderer.Uniforms>.stride, index: 1)
        for batch in batches where !batch.vertices.isEmpty {
            guard let buffer = device.makeSharedBuffer(batch.vertices) else { continue }
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setFragmentTexture(batch.texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: batch.vertices.count)
        }
        encoder.endEncoding()
        command.addCompletedHandler { command in
            let success = command.error == nil
            Task { @MainActor in
                guard success else {
                    completion(nil)
                    return
                }
                var pixels = [UInt8](repeating: 0, count: width * height * 4)
                pixels.withUnsafeMutableBytes {
                    color.getBytes(
                        $0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height),
                        mipmapLevel: 0)
                }
                let image = CGDataProvider(data: Data(pixels) as CFData).flatMap {
                    CGImage(
                        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: $0, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
                }
                completion(image)
            }
        }
        command.commit()
        return true
    }
}
