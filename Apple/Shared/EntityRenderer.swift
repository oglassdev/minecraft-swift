import MetalKit
import MinecraftCore
import simd

@MainActor
final class EntityRenderer {
    private let device: MTLDevice
    private var atlas: MTLTexture
    private var items: MTLTexture
    private let textures: NamedTextures
    private var blockModels: [UInt32: [BlockVertex]] = [:]
    private let signs = SignGeometry()

    private struct Batch {
        let texture: String
        var vertices: [BlockVertex]
        var blended = false
        var additive = false
        var cull: MTLCullMode = .none
    }

    /// Batches share one vertex array so a frame needs a single GPU buffer.
    private struct BatchList {
        struct Draw {
            let texture: String
            let range: Range<Int>
            let blended: Bool
            let additive: Bool
            let cull: MTLCullMode
        }

        var vertices: [BlockVertex] = []
        var draws: [Draw] = []

        mutating func append(_ batch: Batch) {
            guard !batch.vertices.isEmpty else { return }
            draws.append(
                Draw(
                    texture: batch.texture,
                    range: vertices.count..<vertices.count + batch.vertices.count,
                    blended: batch.blended, additive: batch.additive, cull: batch.cull))
            vertices += batch.vertices
        }
    }

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

    func draw(
        encoder: MTLRenderCommandEncoder, entities: [GameEntity], world: BlockWorld,
        camera: Camera, origin: SIMD3<Double>, now: CFTimeInterval, opaquePipeline: MTLRenderPipelineState,
        transparentPipeline: MTLRenderPipelineState, additivePipeline: MTLRenderPipelineState,
        writeDepth: MTLDepthStencilState,
        readDepth: MTLDepthStencilState, frustum: RenderFrustum? = nil,
        visibleChunks: Set<ChunkPosition>? = nil, renderDistance: Float = 128, skySubtraction: Float = 0,
        partialTick: Float = 1
    ) {
        let partial = min(1, max(0, partialTick))
        var batches = BatchList()
        for entity in entities {
            let relative =
                entity.position
                - origin
                - SIMD3(Double(camera.position.x), Double(camera.position.y), Double(camera.position.z))
            let entityDistance = Double(min(128, renderDistance))
            guard
                relative.x * relative.x + relative.y * relative.y + relative.z * relative.z < entityDistance
                    * entityDistance
            else { continue }
            if let frustum, entity.kind != "lightningBolt",
                !frustum.intersects(
                    minimum: SIMD3<Float>(entity.bounds.min - origin),
                    maximum: SIMD3<Float>(entity.bounds.max - origin))
            {
                continue
            }
            let interpolated =
                entity.previousPosition + (entity.position - entity.previousPosition) * Double(partial)
            let local = interpolated - origin
            var position = SIMD3(Float(local.x), Float(local.y), Float(local.z))
            var pose = entity
            pose.pitch = entity.previousPitch + (entity.pitch - entity.previousPitch) * partial
            var yawDelta = (entity.yaw - entity.previousYaw).remainder(dividingBy: BetaVisualMath.pi * 2)
            if yawDelta < -BetaVisualMath.pi { yawDelta += BetaVisualMath.pi * 2 }
            if yawDelta >= BetaVisualMath.pi { yawDelta -= BetaVisualMath.pi * 2 }
            let viewYaw = entity.previousYaw + yawDelta * partial
            let bodyYaw =
                entity.previousBodyYawDegrees + (entity.bodyYawDegrees - entity.previousBodyYawDegrees)
                * partial
            var renderYaw =
                entity.isLiving && entity.kind != "squid"
                ? bodyYaw * BetaVisualMath.pi / 180 - BetaVisualMath.pi : viewYaw
            let headYaw =
                (viewYaw * 180 / BetaVisualMath.pi + 180 - bodyYaw).remainder(dividingBy: 360)
                * BetaVisualMath.pi / 180
            if entity.kind == "minecart" {
                let center = interpolated + SIMD3(0, entity.height / 2, 0)
                if let rail = EntitySimulation.railPoint(center, world: world) {
                    let before = EntitySimulation.railOffsetPoint(center, offset: 0.3, world: world) ?? rail
                    let after = EntitySimulation.railOffsetPoint(center, offset: -0.3, world: world) ?? rail
                    let adjustment = SIMD3(
                        rail.x - center.x, (before.y + after.y) / 2 - center.y, rail.z - center.z)
                    position += SIMD3<Float>(adjustment)
                    let direction = after - before
                    if simd_length_squared(direction) > 0 {
                        let normalized = simd_normalize(direction)
                        let sourceYaw = Float(atan2(normalized.z, normalized.x) * 180 / Double.pi)
                        renderYaw = sourceYaw * BetaVisualMath.pi / 180 - BetaVisualMath.pi
                        pose.pitch = -Float(atan(normalized.y) * 73) * BetaVisualMath.pi / 180
                    }
                }
            }
            let sample = world.light(
                at: BlockPosition(
                    Int(floor(entity.position.x)),
                    Int(floor(entity.position.y + entity.height * 0.66)), Int(floor(entity.position.z))))
            let light = sample.sky << 4 | sample.block
            let age = Float(entity.ageTicks) + partial
            switch entity.kind {
            case "painting":
                batches.append(
                    Batch(
                        texture: "art/kz",
                        vertices: EntityDecorationGeometry.painting(
                            entity: entity, position: position, world: world)))
            case "fishingHook":
                batches.append(
                    Batch(
                        texture: "particles",
                        vertices: sprite(
                            position: position - SIMD3(0, 0.25, 0), camera: camera, width: 0.5, height: 0.5,
                            index: 33, light: light)))
                let hand: SIMD3<Float>
                if let owner = entities.first(where: { $0.id == entity.projectileOwner }) {
                    let local = owner.position - origin
                    hand =
                        SIMD3(Float(local.x), Float(local.y + owner.height * 0.75), Float(local.z))
                        + SIMD3(cos(owner.yaw), 0, sin(owner.yaw)) * 0.35
                } else {
                    let right = SIMD3<Float>(cos(camera.yaw), 0, sin(camera.yaw))
                    hand = camera.position + right * 0.5 + camera.forward * 0.8 + SIMD3(0, 0.03, 0)
                }
                batches.append(
                    Batch(
                        texture: "terrain",
                        vertices: EntityDecorationGeometry.fishingLine(
                            from: position, to: hand, camera: camera)))
            case "lightningBolt":
                if entity.lightningState >= 0 {
                    batches.append(
                        Batch(
                            texture: "terrain",
                            vertices: Self.lightning(seed: entity.effectSeed, position: position),
                            blended: true, additive: true))
                }
            case "item":
                guard let stack = entity.itemStack else { continue }
                let bob = sin(age / 10 + Float(entity.id % 100) * 0.1) * 0.1 + 0.1
                let copies = stack.count > 20 ? 4 : (stack.count > 5 ? 3 : (stack.count > 1 ? 2 : 1))
                for copy in 0..<copies {
                    let offset = SIMD3<Float>(
                        copy == 0 ? 0 : Float(copy % 2) * 0.08 - 0.04,
                        bob + Float(copy) * 0.015, copy == 0 ? 0 : Float(copy / 2) * 0.08 - 0.04)
                    if HeldItemGeometry.rendersAsBlock(stack.id),
                        let kind = BlockKind(rawValue: UInt8(stack.id))
                    {
                        batches.append(
                            Batch(
                                texture: "terrain",
                                vertices: blockVertices(
                                    state: BlockState(
                                        kind, metadata: UInt8(truncatingIfNeeded: stack.damage)),
                                    position: position + offset, yaw: age / 20, scale: 0.25, light: light,
                                    inventory: true)))
                    } else if let definition = stack.definition {
                        batches.append(
                            Batch(
                                texture: definition.iconTexture,
                                vertices: sprite(
                                    position: position + offset, camera: camera, width: 0.5, height: 0.5,
                                    index: definition.iconIndex(damage: stack.damage), light: light)))
                    }
                }
            case "primedTnt", "fallingSand":
                let state =
                    entity.kind == "primedTnt" ? BlockState(.tnt) : entity.fallingBlock ?? BlockState(.sand)
                let pulse: Float =
                    entity.kind == "primedTnt" && entity.fuseTicks < 10
                    ? 1 + pow(1 - Float(entity.fuseTicks) / 10, 4) * 0.3 : 1
                batches.append(
                    Batch(
                        texture: "terrain",
                        vertices: blockVertices(
                            state: state,
                            position: position, yaw: 0, scale: 0.98 * pulse, light: light)))
            case "snowball", "egg", "fireball":
                let id: UInt16 = entity.kind == "egg" ? 344 : 332
                let index = ItemDefinition.definition(for: id)?.iconIndex ?? 14
                let size: Float = entity.kind == "fireball" ? 2 : 0.5
                batches.append(
                    Batch(
                        texture: "gui/items",
                        vertices: sprite(
                            position: position, camera: camera,
                            width: size, height: size, index: index,
                            light: entity.kind == "fireball" ? 255 : light)))
            case "arrow":
                batches.append(
                    Batch(
                        texture: "item/arrows",
                        vertices: ArrowGeometry.vertices(
                            position: position, yaw: viewYaw, pitch: pose.pitch,
                            shake: max(0, Float(entity.pickupDelay) - partial), light: light),
                        cull: .back))
            default:
                let layers = EntityModels.layers(
                    entity: pose, phase: entity.limbSwing - entity.limbSwingAmount * (1 - partial),
                    amplitude: min(
                        1,
                        entity.previousLimbSwingAmount
                            + (entity.limbSwingAmount - entity.previousLimbSwingAmount) * partial), age: age,
                    partial: partial, headYaw: headYaw)
                for layer in layers {
                    var transform = layer.transform
                    if entity.deathTicks > 0 && entity.kind != "squid" {
                        let progress = min(
                            1, sqrt(max(0, (Float(entity.deathTicks) + partial - 1) / 20 * 1.6)))
                        transform =
                            HeldItemGeometry.rotation(
                                progress * (entity.kind == "spider" ? 180 : 90), axis: SIMD3(0, 0, 1))
                            * transform
                    }
                    let opacity: Float
                    if layer.texture == "mob/spider_eyes" {
                        let level = max(Int(sample.sky) - Int(skySubtraction), Int(sample.block))
                        opacity =
                            (1
                                - BetaLighting.brightness(
                                    level: level, ambient: world.dimension == -1 ? 0.1 : 0.05)) * 0.5
                    } else {
                        opacity = layer.opacity
                    }
                    var vertices = layer.parts.flatMap {
                        $0.vertices(
                            position: position, yaw: renderYaw, scale: layer.scale,
                            originY: layer.originY, tint: layer.tint, light: layer.fullbright ? 255 : light,
                            opacity: opacity, transform: transform)
                    }
                    if layer.uvOffset != .zero {
                        vertices = vertices.map { vertex in
                            BlockVertex(
                                position: vertex.position, color: vertex.color,
                                uv: vertex.uv + layer.uvOffset,
                                opacity: vertex.opacity, lightSamples: vertex.lightSamples)
                        }
                    }
                    batches.append(
                        Batch(
                            texture: layer.texture, vertices: vertices, blended: layer.blended,
                            additive: layer.additive))
                    if (entity.hurtTicks > 0 || entity.deathTicks > 0) && !layer.blended {
                        let red = vertices.map { vertex -> BlockVertex in
                            let shade = max(
                                vertex.color.x / max(0.0001, layer.tint.x),
                                vertex.color.y / max(0.0001, layer.tint.y),
                                vertex.color.z / max(0.0001, layer.tint.z))
                            return BlockVertex(
                                position: vertex.position, color: SIMD3(shade, 0, 0), opacity: 0.4,
                                textureWeight: 0, light: light)
                        }
                        batches.append(Batch(texture: "terrain", vertices: red, blended: true))
                    }
                    if entity.kind == "creeper", !layer.blended,
                        Int(Float(entity.fuseTicks) / 28 * 10) & 1 != 0
                    {
                        let white = vertices.map {
                            BlockVertex(
                                position: $0.position, color: $0.color,
                                opacity: min(1, Float(entity.fuseTicks) / 28 * 0.2), textureWeight: 0,
                                light: light)
                        }
                        batches.append(Batch(texture: "terrain", vertices: white, blended: true))
                    }
                }
                if entity.kind == "minecart", entity.metadata == 1 || entity.metadata == 2 {
                    let contents = blockVertices(
                        state: BlockState(entity.metadata == 1 ? .chest : .furnace),
                        position: SIMD3(0, -0.140625, 0), yaw: -BetaVisualMath.pi / 2, scale: 0.75,
                        light: light, inventory: true)
                    let transform = layers.first?.transform ?? matrix_identity_float4x4
                    let vertices = contents.map { vertex -> BlockVertex in
                        let point = transform * SIMD4(vertex.position, 1)
                        return BlockVertex(
                            position: position
                                + EntityModelPart.rotate(
                                    SIMD3(point.x, point.y, point.z), by: SIMD3(0, -renderYaw, 0)),
                            color: vertex.color, uv: vertex.uv, light: light)
                    }
                    batches.append(Batch(texture: "terrain", vertices: vertices))
                }
            }
            if entity.fireTicks > 0 || entity.remoteFlags & 1 != 0 {
                batches.append(
                    Batch(
                        texture: "terrain",
                        vertices: EntityDecorationGeometry.fire(
                            entity: entity, position: position, cameraYaw: camera.yaw)))
            }
            if entity.isLiving && entity.onGround {
                let radius = Float(entity.width) * 0.55
                let points = [
                    position + SIMD3(-radius, 0.006, -radius), position + SIMD3(radius, 0.006, -radius),
                    position + SIMD3(radius, 0.006, radius), position + SIMD3(-radius, 0.006, radius),
                ]
                batches.append(
                    Batch(
                        texture: "misc/shadow",
                        vertices: quad(
                            points: points,
                            uv: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)], color: .zero,
                            light: light, opacity: 0.3), blended: true))
            }
        }
        for chunk in world.chunks.values where visibleChunks?.contains(chunk.position) != false {
            for (cell, tile) in chunk.blockEntities {
                if case .sign(let lines) = tile, let state = world.state(at: cell) {
                    let local = SIMD3(Double(cell.x), Double(cell.y), Double(cell.z)) - origin
                    let sample = world.light(at: cell)
                    let geometry = signs.vertices(
                        state: state, lines: lines,
                        position: SIMD3(Float(local.x), Float(local.y), Float(local.z)),
                        light: sample.sky << 4 | sample.block)
                    batches.append(Batch(texture: "item/sign", vertices: geometry.board))
                    batches.append(Batch(texture: "font/default", vertices: geometry.text))
                }
                guard case .piston(let state) = tile else { continue }
                let fraction = partial
                guard state.interpolatedProgress(fraction) < 1 else { continue }
                let local = SIMD3(Double(cell.x) + 0.5, Double(cell.y), Double(cell.z) + 0.5) - origin
                let base = SIMD3(Float(local.x), Float(local.y), Float(local.z))
                let sample = world.light(at: cell)
                let light = sample.sky << 4 | max(sample.block, state.block.kind.lightEmission)
                if state.isSource && !state.extending {
                    let sticky: UInt8 = state.block.kind == .stickyPiston ? 8 : 0
                    batches.append(
                        Batch(
                            texture: "terrain",
                            vertices: blockVertices(
                                state: BlockState(.pistonHead, metadata: state.facing | sticky),
                                position: base + state.offset(interpolation: fraction), yaw: 0, scale: 1,
                                light: light)))
                    batches.append(
                        Batch(
                            texture: "terrain",
                            vertices: blockVertices(
                                state: BlockState(state.block.kind, metadata: state.facing | 8),
                                position: base, yaw: 0, scale: 1, light: light)))
                } else {
                    batches.append(
                        Batch(
                            texture: "terrain",
                            vertices: blockVertices(
                                state: state.block,
                                position: base + state.offset(interpolation: fraction), yaw: 0, scale: 1,
                                light: light)))
                }
            }
        }
        encoder.setCullMode(.none)
        guard let buffer = device.makeSharedBuffer(batches.vertices) else { return }
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        for blended in [false, true] {
            encoder.setDepthStencilState(blended ? readDepth : writeDepth)
            for draw in batches.draws where draw.blended == blended {
                guard let texture = texture(named: draw.texture) else { continue }
                encoder.setRenderPipelineState(
                    draw.additive ? additivePipeline : (blended ? transparentPipeline : opaquePipeline))
                encoder.setFragmentTexture(texture, index: 0)
                encoder.setCullMode(draw.cull)
                encoder.drawPrimitives(
                    type: .triangle, vertexStart: draw.range.lowerBound, vertexCount: draw.range.count)
            }
        }
        encoder.setCullMode(.none)
    }

    static func lightning(seed: Int64, position: SIMD3<Float>) -> [BlockVertex] {
        var random = JavaRandom(seed: seed)
        var x = [Float](repeating: 0, count: 8)
        var z = x
        var endX: Float = 0
        var endZ: Float = 0
        for index in (0..<8).reversed() {
            x[index] = endX
            z[index] = endZ
            endX += Float(random.nextInt(bound: 11) - 5)
            endZ += Float(random.nextInt(bound: 11) - 5)
        }
        var vertices: [BlockVertex] = []
        for layer in 0..<4 {
            var branchRandom = JavaRandom(seed: seed)
            for branch in 0..<3 {
                let start = branch == 0 ? 7 : 7 - branch
                let finish = branch == 0 ? 0 : start - 2
                var currentX = x[start] - endX
                var currentZ = z[start] - endZ
                for segment in stride(from: start, through: finish, by: -1) {
                    let previousX = currentX
                    let previousZ = currentZ
                    let spread = branch == 0 ? 11 : 31
                    currentX += Float(branchRandom.nextInt(bound: spread) - spread / 2)
                    currentZ += Float(branchRandom.nextInt(bound: spread) - spread / 2)
                    let radius = Float(0.1 + Double(layer) * 0.2)
                    let upperRadius = radius * (branch == 0 ? Float(segment) * 0.1 + 1 : 1)
                    let lowerRadius = radius * (branch == 0 ? Float(segment - 1) * 0.1 + 1 : 1)
                    var strip: [SIMD3<Float>] = []
                    for corner in 0..<5 {
                        let highX = (corner == 1 || corner == 2 ? upperRadius : -upperRadius) + previousX
                        let highZ = (corner == 2 || corner == 3 ? upperRadius : -upperRadius) + previousZ
                        let lowX = (corner == 1 || corner == 2 ? lowerRadius : -lowerRadius) + currentX
                        let lowZ = (corner == 2 || corner == 3 ? lowerRadius : -lowerRadius) + currentZ
                        strip.append(position + SIMD3(0.5 + lowX, Float(segment * 16), 0.5 + lowZ))
                        strip.append(position + SIMD3(0.5 + highX, Float((segment + 1) * 16), 0.5 + highZ))
                    }
                    for index in 2..<strip.count {
                        for vertex in [index - 2, index - 1, index] {
                            vertices.append(
                                BlockVertex(
                                    position: strip[vertex], color: SIMD3(0.45, 0.45, 0.5), opacity: 0.3,
                                    textureWeight: 0, light: 255))
                        }
                    }
                }
            }
        }
        return vertices
    }

    private func texture(named name: String) -> MTLTexture? {
        if name == "terrain" { return atlas }
        if name == "gui/items" { return items }
        return textures.texture(name)
    }

    private func blockVertices(
        state: BlockState, position: SIMD3<Float>, yaw: Float,
        scale: Float, light: UInt8, inventory: Bool = false
    ) -> [BlockVertex] {
        let key = UInt32(state.kind.rawValue) << 8 | UInt32(state.metadata) | (inventory ? 1 << 16 : 0)
        let source: [BlockVertex]
        if let cached = blockModels[key] {
            source = cached
        } else {
            var world = BlockWorld()
            world.setBlock(state, at: BlockPosition(0, 0, 0))
            source =
                BlockMesh(
                    world: world, blockAt: BlockPosition(0, 0, 0),
                    options: BlockMeshOptions(smoothLighting: false, inventory: inventory)
                ).vertices
            blockModels[key] = source
        }
        return source.map { vertex in
            let local = (vertex.position - SIMD3(0.5, 0, 0.5)) * scale
            return BlockVertex(
                position: position + EntityModelPart.rotate(local, by: SIMD3(0, -yaw, 0)),
                color: vertex.color, uv: vertex.uv, opacity: vertex.opacity, light: light)
        }
    }

    private func sprite(
        position: SIMD3<Float>, camera: Camera, width: Float, height: Float,
        index: Int, light: UInt8
    ) -> [BlockVertex] {
        let right = SIMD3<Float>(cos(camera.yaw), 0, sin(camera.yaw)) * width / 2
        let up = SIMD3<Float>(0, height, 0)
        let points = [position - right, position + right, position + right + up, position - right + up]
        let x = Float(index & 15) / 16
        let y = Float(index >> 4) / 16
        let size: Float = 1 / 16
        return quad(
            points: points,
            uv: [SIMD2(x, y + size), SIMD2(x + size, y + size), SIMD2(x + size, y), SIMD2(x, y)],
            color: SIMD3(repeating: 1), light: light)
    }

    private func quad(
        points: [SIMD3<Float>], uv: [SIMD2<Float>], color: SIMD3<Float>,
        light: UInt8, opacity: Float = 1
    ) -> [BlockVertex] {
        [0, 1, 2, 0, 2, 3].map {
            BlockVertex(
                position: points[$0], color: color, uv: uv[$0],
                opacity: opacity, light: light)
        }
    }
}
