import MetalKit
import MinecraftCore
import simd

enum HeldItemGeometry {
    static func rendersAsBlock(_ id: UInt16) -> Bool {
        guard id > 0 && id <= 96 else { return false }
        return ![
            6, 8, 9, 10, 11, 26, 27, 28, 30, 31, 32, 34, 36, 37, 38, 39, 40, 50, 51, 55,
            59, 63, 64, 65, 66, 68, 69, 71, 75, 76, 83, 93, 94,
        ].contains(Int(id))
    }

    static func sprite(index: Int) -> [BlockVertex] {
        let u0 = Float(index & 15) / 16
        let u1 = u0 + 15.99 / 256
        let v0 = Float(index >> 4) / 16
        let v1 = v0 + 15.99 / 256
        let depth: Float = -1 / 16
        var vertices: [BlockVertex] = []
        func quad(_ points: [SIMD3<Float>], _ uv: [SIMD2<Float>], shade: Float = 1) {
            vertices += [0, 1, 2, 0, 2, 3].map {
                BlockVertex(position: points[$0], color: SIMD3(repeating: shade), uv: uv[$0])
            }
        }
        quad(
            [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(0, 1, 0)],
            [SIMD2(u1, v1), SIMD2(u0, v1), SIMD2(u0, v0), SIMD2(u1, v0)])
        quad(
            [SIMD3(0, 1, depth), SIMD3(1, 1, depth), SIMD3(1, 0, depth), SIMD3(0, 0, depth)],
            [SIMD2(u1, v0), SIMD2(u0, v0), SIMD2(u0, v1), SIMD2(u1, v1)])
        for index in 0..<16 {
            let fraction = Float(index) / 16
            let u = u1 + (u0 - u1) * fraction - 1 / 512
            let v = v1 + (v0 - v1) * fraction - 1 / 512
            let high = fraction + 1 / 16
            quad(
                [
                    SIMD3(fraction, 0, depth), SIMD3(fraction, 0, 0), SIMD3(fraction, 1, 0),
                    SIMD3(fraction, 1, depth),
                ],
                [SIMD2(u, v1), SIMD2(u, v1), SIMD2(u, v0), SIMD2(u, v0)], shade: 0.8)
            quad(
                [SIMD3(high, 1, depth), SIMD3(high, 1, 0), SIMD3(high, 0, 0), SIMD3(high, 0, depth)],
                [SIMD2(u, v0), SIMD2(u, v0), SIMD2(u, v1), SIMD2(u, v1)], shade: 0.8)
            quad(
                [SIMD3(0, high, 0), SIMD3(1, high, 0), SIMD3(1, high, depth), SIMD3(0, high, depth)],
                [SIMD2(u1, v), SIMD2(u0, v), SIMD2(u0, v), SIMD2(u1, v)])
            quad(
                [
                    SIMD3(1, fraction, 0), SIMD3(0, fraction, 0), SIMD3(0, fraction, depth),
                    SIMD3(1, fraction, depth),
                ],
                [SIMD2(u0, v), SIMD2(u1, v), SIMD2(u1, v), SIMD2(u0, v)], shade: 0.6)
        }
        return vertices
    }

    static func translation(_ point: SIMD3<Float>) -> simd_float4x4 {
        var result = matrix_identity_float4x4
        result.columns.3 = SIMD4(point, 1)
        return result
    }

    static func scale(_ value: Float) -> simd_float4x4 {
        simd_float4x4(diagonal: SIMD4(value, value, value, 1))
    }

    static func rotation(_ degrees: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: degrees * BetaVisualMath.pi / 180, axis: simd_normalize(axis)))
    }
}

@MainActor
final class FirstPersonRenderer {
    private let device: MTLDevice
    private var atlas: MTLTexture
    private var items: MTLTexture
    private let textures: NamedTextures
    private var displayedItem: ItemStack?
    private var equip: Float = 0
    private var equipProgress: Float = 0
    private var previousEquipProgress: Float = 0
    private var equippedSlot = -1
    private var swing: Float = 0
    private var blockModels: [UInt32: [BlockVertex]] = [:]
    private var spriteModels: [Int: [BlockVertex]] = [:]
    private var mapTexture: MTLTexture?
    private var mapKey: (id: Int16, revision: UInt64)?

    init(device: MTLDevice, atlas: MTLTexture, items: MTLTexture) {
        self.device = device
        self.atlas = atlas
        self.items = items
        textures = NamedTextures(device: device)
    }

    func reload(atlas: MTLTexture, items: MTLTexture) {
        self.atlas = atlas
        self.items = items
        textures.removeAll()
    }

    func advance(heldItem: ItemStack?, slot: Int, ticks: Int) {
        for _ in 0..<ticks {
            previousEquipProgress = equipProgress
            let sameSlot = slot == equippedSlot && heldItem?.id == displayedItem?.id
            let sameItem = heldItem?.id == displayedItem?.id && heldItem?.damage == displayedItem?.damage
            let matches = sameSlot || sameItem
            if matches { displayedItem = heldItem }
            equipProgress += min(0.4, max(-0.4, (matches ? 1 : 0) - equipProgress))
            if equipProgress < 0.1 {
                displayedItem = heldItem
                equippedSlot = slot
            }
        }
    }

    func draw(
        encoder: MTLRenderCommandEncoder, swingProgress: Float, partialTick: Float,
        light: UInt8, uniforms: Renderer.Uniforms, pipeline: MTLRenderPipelineState,
        mapPipeline: MTLRenderPipelineState, depth: MTLDepthStencilState,
        map: BetaMapData?, marker: BetaMapMarker?, pitch: Float
    ) {
        equip = previousEquipProgress + (equipProgress - previousEquipProgress) * partialTick
        swing = swingProgress
        var uniforms = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depth)
        encoder.setCullMode(.none)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Renderer.Uniforms>.stride, index: 1)
        if displayedItem?.id == 358, let map {
            drawMap(
                encoder: encoder, map: map, marker: marker, pitch: pitch, light: light,
                mapPipeline: mapPipeline)
            return
        }
        let rootSwing = BetaVisualMath.sine(sqrt(swing) * BetaVisualMath.pi)
        let sinSwing = BetaVisualMath.sine(swing * BetaVisualMath.pi)
        let squaredSwing = BetaVisualMath.sine(swing * swing * BetaVisualMath.pi)
        let wave = BetaVisualMath.sine(sqrt(swing) * BetaVisualMath.pi * 2)
        let t = HeldItemGeometry.translation
        let r = HeldItemGeometry.rotation
        let scale = HeldItemGeometry.scale
        let x = SIMD3<Float>(1, 0, 0)
        let y = SIMD3<Float>(0, 1, 0)
        let z = SIMD3<Float>(0, 0, 1)
        let matrix: simd_float4x4
        let source: [BlockVertex]
        let textureName: String
        if let stack = displayedItem, let definition = stack.definition {
            let outer =
                t(SIMD3(-rootSwing * 0.4, wave * 0.2, -sinSwing * 0.2))
                * t(SIMD3(0.56, -0.52 - (1 - equip) * 0.6, -0.72))
                * r(45, y) * r(-squaredSwing * 20, y) * r(-rootSwing * 20, z)
                * r(-rootSwing * 80, x) * scale(0.4) * r(stack.id == 346 ? 180 : 0, y)
            if HeldItemGeometry.rendersAsBlock(stack.id), let kind = BlockKind(rawValue: UInt8(stack.id)) {
                let key = UInt32(stack.id) << 16 | UInt32(stack.damage)
                if let cached = blockModels[key] {
                    source = cached
                } else {
                    var world = BlockWorld()
                    world.setBlock(
                        BlockState(kind, metadata: UInt8(truncatingIfNeeded: stack.damage)),
                        at: BlockPosition(0, 0, 0))
                    source =
                        BlockMesh(
                            world: world, blockAt: BlockPosition(0, 0, 0),
                            options: BlockMeshOptions(smoothLighting: false, inventory: true)
                        ).vertices
                    blockModels[key] = source
                }
                matrix = outer * r(90, y) * t(SIMD3(repeating: -0.5))
                textureName = "terrain"
            } else {
                let index = definition.iconIndex(damage: stack.damage)
                if let cached = spriteModels[index] {
                    source = cached
                } else {
                    source = HeldItemGeometry.sprite(index: index)
                    spriteModels[index] = source
                }
                matrix =
                    outer * t(SIMD3(0, -0.3, 0)) * scale(1.5) * r(50, y) * r(335, z)
                    * t(SIMD3(-0.9375, -0.0625, 0))
                textureName = definition.iconTexture
            }
        } else {
            let arm = EntityModelPart(
                SIMD3(-3, -2, -2), SIMD3(4, 12, 4), at: SIMD3(-5, 2, 0), uv: SIMD2(40, 16))
            source = arm.vertices(
                position: .zero, yaw: 0, scale: 1, originY: 0, tint: SIMD3(repeating: 1), light: light,
                opacity: 1)
            matrix =
                t(SIMD3(-rootSwing * 0.3, wave * 0.4, -sinSwing * 0.4))
                * t(SIMD3(0.64, -0.6 - (1 - equip) * 0.6, -0.72)) * r(45, y)
                * r(rootSwing * 70, y) * r(-squaredSwing * 20, z) * t(SIMD3(-1, 3.6, 3.5))
                * r(120, z) * r(200, x) * r(-135, y) * t(SIMD3(5.6, 0, 0))
                * simd_float4x4(diagonal: SIMD4(-1, -1, 1, 1))
            textureName = "mob/char"
        }
        let vertices = source.map { vertex -> BlockVertex in
            let transformed = matrix * SIMD4(vertex.position, 1)
            return BlockVertex(
                position: SIMD3(transformed.x, transformed.y, transformed.z), color: vertex.color,
                uv: vertex.uv, opacity: vertex.opacity, textureWeight: vertex.textureWeight, light: light)
        }
        guard let texture = texture(named: textureName) else { return }
        encode(vertices: vertices, texture: texture, encoder: encoder)
    }

    private func drawMap(
        encoder: MTLRenderCommandEncoder, map: BetaMapData, marker: BetaMapMarker?, pitch: Float,
        light: UInt8, mapPipeline: MTLRenderPipelineState
    ) {
        let t = HeldItemGeometry.translation
        let r = HeldItemGeometry.rotation
        let scale = HeldItemGeometry.scale
        let x = SIMD3<Float>(1, 0, 0)
        let y = SIMD3<Float>(0, 1, 0)
        let z = SIMD3<Float>(0, 0, 1)
        let rootSwing = BetaVisualMath.sine(sqrt(swing) * BetaVisualMath.pi)
        let sinSwing = BetaVisualMath.sine(swing * BetaVisualMath.pi)
        let squaredSwing = BetaVisualMath.sine(swing * swing * BetaVisualMath.pi)
        let wave = BetaVisualMath.sine(sqrt(swing) * BetaVisualMath.pi * 2)
        let tiltProgress = min(1, max(0, 1 + pitch * 180 / .pi / 45 + 0.1))
        let tilt = -BetaVisualMath.cosine(tiltProgress * BetaVisualMath.pi) * 0.5 + 0.5
        let outer =
            t(SIMD3(-rootSwing * 0.4, wave * 0.2, -sinSwing * 0.2))
            * t(SIMD3(0, -(1 - equip) * 1.2 - tilt * 0.5 + 0.04, -0.72)) * r(90, y) * r(-tilt * 85, z)
        let arm = EntityModelPart(SIMD3(-3, -2, -2), SIMD3(4, 12, 4), at: SIMD3(-5, 2, 0), uv: SIMD2(40, 16))
        let armVertices = arm.vertices(
            position: .zero, yaw: 0, scale: 1, originY: 0, tint: SIMD3(repeating: 1), light: light, opacity: 1
        )
        if let skin = texture(named: "mob/char") {
            for side in [Float(-1), Float(1)] {
                let transform =
                    outer * t(SIMD3(0, -0.6, 1.1 * side)) * r(-45 * side, x)
                    * r(-90, z) * r(59, z) * r(-65 * side, y)
                    * simd_float4x4(diagonal: SIMD4(-1, -1, 1, 1))
                let vertices = armVertices.map { vertex -> BlockVertex in
                    let point = transform * SIMD4(vertex.position, 1)
                    return BlockVertex(
                        position: SIMD3(point.x, point.y, point.z), color: vertex.color, uv: vertex.uv,
                        light: light)
                }
                encode(vertices: vertices, texture: skin, encoder: encoder)
            }
        }
        let transform =
            outer * r(-squaredSwing * 20, y) * r(-rootSwing * 20, z) * r(-rootSwing * 80, x)
            * scale(0.38) * r(90, y) * r(180, z) * t(SIMD3(-1, -1, 0)) * scale(1 / 64)
        func quad(
            _ points: [SIMD3<Float>], _ uv: [SIMD2<Float>], matrix: simd_float4x4 = matrix_identity_float4x4
        ) -> [BlockVertex] {
            [0, 1, 2, 0, 2, 3].map {
                let point = transform * matrix * SIMD4(points[$0], 1)
                return BlockVertex(
                    position: SIMD3(point.x, point.y, point.z), color: SIMD3(repeating: 1), uv: uv[$0],
                    light: light)
            }
        }
        if let paper = texture(named: "misc/mapbg") {
            encode(
                vertices: quad(
                    [SIMD3(-7, 135, 0), SIMD3(135, 135, 0), SIMD3(135, -7, 0), SIMD3(-7, -7, 0)],
                    [SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 0)]), texture: paper, encoder: encoder)
        }
        if mapTexture == nil || mapKey?.id != map.id || mapKey?.revision != map.revision {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: 128, height: 128, mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = .shaderRead
            mapTexture = device.makeTexture(descriptor: descriptor)
        }
        if let mapTexture {
            if mapKey?.id != map.id || mapKey?.revision != map.revision {
                let pixels = map.rgbaPixels
                pixels.withUnsafeBytes { bytes in
                    if let address = bytes.baseAddress {
                        mapTexture.replace(
                            region: MTLRegionMake2D(0, 0, 128, 128), mipmapLevel: 0, withBytes: address,
                            bytesPerRow: 512)
                    }
                }
                mapKey = (map.id, map.revision)
            }
            encoder.setRenderPipelineState(mapPipeline)
            encode(
                vertices: quad(
                    [SIMD3(0, 128, -0.01), SIMD3(128, 128, -0.01), SIMD3(128, 0, -0.01), SIMD3(0, 0, -0.01)],
                    [SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 0)]), texture: mapTexture,
                encoder: encoder)
        }
        if let marker, let icons = texture(named: "misc/mapicons") {
            let u = Float(marker.type & 3) / 4
            let v = Float(marker.type >> 2) / 4
            let pose =
                t(SIMD3(marker.pixelPosition.x, marker.pixelPosition.y, -0.02))
                * r(Float(marker.rotation) * 360 / 16, z) * scale(4) * t(SIMD3(-0.125, 0.125, 0))
            encode(
                vertices: quad(
                    [SIMD3(-1, 1, 0), SIMD3(1, 1, 0), SIMD3(1, -1, 0), SIMD3(-1, -1, 0)],
                    [SIMD2(u, v), SIMD2(u + 0.25, v), SIMD2(u + 0.25, v + 0.25), SIMD2(u, v + 0.25)],
                    matrix: pose), texture: icons, encoder: encoder)
        }
    }

    private func encode(vertices: [BlockVertex], texture: MTLTexture, encoder: MTLRenderCommandEncoder) {
        guard !vertices.isEmpty else { return }
        guard let buffer = device.makeSharedBuffer(vertices) else { return }
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private func texture(named name: String) -> MTLTexture? {
        if name == "terrain" { return atlas }
        if name == "gui/items" { return items }
        return textures.texture(name)
    }
}
