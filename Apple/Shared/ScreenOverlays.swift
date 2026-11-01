import MetalKit
import MinecraftCore
import simd

@MainActor
final class ScreenOverlays {
    private let pipeline: MTLRenderPipelineState
    private let blurredPipeline: MTLRenderPipelineState
    private let vignettePipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private var atlas: MTLTexture
    private let textures: NamedTextures
    private var vignette: Float = 1

    init(device: MTLDevice, library: MTLLibrary, atlas: MTLTexture, colorFormat: MTLPixelFormat) throws {
        self.atlas = atlas
        textures = NamedTextures(device: device)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "blockVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "overlayFragment")
        descriptor.colorAttachments[0].pixelFormat = colorFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        let color = descriptor.colorAttachments[0]!
        color.isBlendingEnabled = true
        color.sourceRGBBlendFactor = .sourceAlpha
        color.destinationRGBBlendFactor = .oneMinusSourceAlpha
        color.sourceAlphaBlendFactor = .one
        color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "overlayBlurFragment")
        blurredPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        color.sourceRGBBlendFactor = .zero
        color.destinationRGBBlendFactor = .oneMinusSourceColor
        vignettePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let state = MTLDepthStencilDescriptor()
        state.depthCompareFunction = .always
        state.isDepthWriteEnabled = false
        guard let depth = device.makeDepthStencilState(descriptor: state) else {
            throw Renderer.SetupError.unavailable("could not create overlay depth state")
        }
        self.depth = depth
    }

    func reload(atlas: MTLTexture) {
        self.atlas = atlas
        textures.removeAll()
    }

    func draw(
        encoder: MTLRenderCommandEncoder, world: BlockWorld, player: Player, camera: Camera,
        position: SIMD3<Double>, projection: simd_float4x4, skySubtraction: Float,
        portal: Float, fancy: Bool, pumpkin: Bool, firstPerson: Bool
    ) {
        let sample = world.light(
            at: BlockPosition(
                Int(floor(player.position.x)), Int(floor(player.position.y + 1.8 * 0.66)),
                Int(floor(player.position.z))))
        let brightness = BetaLighting.brightness(
            level: max(Int(sample.sky) - Int(skySubtraction), Int(sample.block)),
            ambient: world.dimension == -1 ? 0.1 : 0.05)
        var uniforms = Renderer.Uniforms(
            viewProjection: projection, renderOffset: .zero, cameraPosition: .zero,
            fogColor: .zero, fogStart: 100, fogEnd: 200, skySubtraction: 0, fogDensity: 0, ambientFloor: 0.05)
        encoder.setDepthStencilState(depth)
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Renderer.Uniforms>.stride, index: 1)
        if firstPerson && player.fireTicks > 0 {
            for side in 0..<2 {
                let tile = 31 + side * 16
                let u = Float(tile & 15) / 16
                let v = Float(tile >> 4) / 16
                let sign = Float(side * 2 - 1)
                let transform =
                    HeldItemGeometry.translation(SIMD3(-sign * 0.24, -0.3, 0))
                    * HeldItemGeometry.rotation(sign * 10, axis: SIMD3(0, 1, 0))
                let points = [
                    SIMD3<Float>(-0.5, -0.5, -0.5), SIMD3(0.5, -0.5, -0.5), SIMD3(0.5, 0.5, -0.5),
                    SIMD3(-0.5, 0.5, -0.5),
                ].map {
                    let point = transform * SIMD4($0, 1)
                    return SIMD3(point.x, point.y, point.z)
                }
                quad(
                    encoder: encoder, points: points,
                    uv: [
                        SIMD2(u + 15.99 / 256, v + 15.99 / 256), SIMD2(u, v + 15.99 / 256), SIMD2(u, v),
                        SIMD2(u + 15.99 / 256, v),
                    ],
                    color: SIMD3(repeating: 1), opacity: 0.9, texture: atlas)
            }
        }
        var inside: BlockState?
        for corner in 0..<8 {
            let point =
                position
                + SIMD3(
                    Double((corner & 1) == 0 ? -0.27 : 0.27), Double((corner & 2) == 0 ? -0.18 : 0.18),
                    Double((corner & 4) == 0 ? -0.27 : 0.27))
            if let state = world.state(
                at: BlockPosition(Int(floor(point.x)), Int(floor(point.y)), Int(floor(point.z)))),
                state.kind.isOpaque
            {
                inside = state
            }
        }
        if firstPerson, let inside {
            let tile = BlockAtlas.textureIndex(for: inside, face: .north)
            // The original overlay uses cell indices as texel offsets.
            let u0 = Float(tile % 16) / 256 - 1 / 128
            let u1 = (Float(tile % 16) + 15.99) / 256 + 1 / 128
            let v0 = Float(tile / 16) / 256 - 1 / 128
            let v1 = (Float(tile / 16) + 15.99) / 256 + 1 / 128
            quad(
                encoder: encoder, points: Self.eyeQuad,
                uv: [SIMD2(u1, v1), SIMD2(u0, v1), SIMD2(u0, v0), SIMD2(u1, v0)],
                color: SIMD3(repeating: 0.1), opacity: 0.5, texture: atlas)
        }
        if firstPerson, player.isEyeUnderwater(in: world), let water = textures.texture("misc/water") {
            let u = -(camera.yaw * 180 / BetaVisualMath.pi + 180) / 64
            let v = -camera.pitch * 180 / BetaVisualMath.pi / 64
            quad(
                encoder: encoder, points: Self.eyeQuad,
                uv: [SIMD2(u + 4, v + 4), SIMD2(u, v + 4), SIMD2(u, v), SIMD2(u + 4, v)],
                color: SIMD3(repeating: brightness), opacity: 0.5, texture: water)
        }
        uniforms.viewProjection = matrix_identity_float4x4
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Renderer.Uniforms>.stride, index: 1)
        if fancy, let image = textures.texture("misc/vignette") {
            vignette += (min(1, max(0, 1 - brightness)) - vignette) * 0.01
            encoder.setRenderPipelineState(vignettePipeline)
            quad(
                encoder: encoder, points: Self.screenQuad, uv: Self.fullUV, color: SIMD3(repeating: vignette),
                opacity: 1, texture: image)
        }
        if pumpkin, let image = textures.texture("misc/pumpkinblur") {
            encoder.setRenderPipelineState(blurredPipeline)
            quad(
                encoder: encoder, points: Self.screenQuad, uv: Self.fullUV, color: SIMD3(repeating: 1),
                opacity: 1, texture: image)
        }
        if portal > 0 {
            encoder.setRenderPipelineState(pipeline)
            let opacity = portal < 1 ? pow(portal, 4) * 0.8 + 0.2 : 1
            let u: Float = 14 / 16
            quad(
                encoder: encoder, points: Self.screenQuad,
                uv: [SIMD2(u, 1 / 16), SIMD2(u + 1 / 16, 1 / 16), SIMD2(u + 1 / 16, 0), SIMD2(u, 0)],
                color: SIMD3(repeating: 1), opacity: opacity, texture: atlas)
        }
    }

    private static let eyeQuad: [SIMD3<Float>] = [
        SIMD3(-1, -1, -0.5), SIMD3(1, -1, -0.5), SIMD3(1, 1, -0.5), SIMD3(-1, 1, -0.5),
    ]
    private static let screenQuad: [SIMD3<Float>] = [
        SIMD3(-1, -1, 0.5), SIMD3(1, -1, 0.5), SIMD3(1, 1, 0.5), SIMD3(-1, 1, 0.5),
    ]
    private static let fullUV: [SIMD2<Float>] = [SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 0)]

    private func quad(
        encoder: MTLRenderCommandEncoder, points: [SIMD3<Float>], uv: [SIMD2<Float>], color: SIMD3<Float>,
        opacity: Float, texture: MTLTexture
    ) {
        let vertices = [0, 1, 2, 0, 2, 3].map {
            BlockVertex(position: points[$0], color: color, uv: uv[$0], opacity: opacity, light: 255)
        }
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<BlockVertex>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
}
