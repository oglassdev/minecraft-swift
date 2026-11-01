import MetalKit
import MinecraftCore
import simd

@MainActor
final class EntityRenderer {
    private let device: MTLDevice
    private let loader: MTKTextureLoader
    private let atlas: MTLTexture
    private let items: MTLTexture
    private var textures: [String: MTLTexture] = [:]
    private var animations: [Int64: Animation] = [:]
    private var blockModels: [UInt16: [BlockVertex]] = [:]
    private var pistons: [BlockPosition: (progress: Float, time: CFTimeInterval)] = [:]
    private let signs = SignGeometry()

    private struct Animation {
        var lastAge: Int
        var lastTickTime: CFTimeInterval
        var phase: Float = 0
        var amplitude: Float = 0
    }

    private struct Batch {
        let texture: String
        var vertices: [BlockVertex]
        var blended = false
        var additive = false
    }

    init(device: MTLDevice, atlas: MTLTexture, items: MTLTexture) {
        self.device = device
        self.atlas = atlas
        self.items = items
        loader = MTKTextureLoader(device: device)
    }

    func draw(
        encoder: MTLRenderCommandEncoder, entities: [GameEntity], world: BlockWorld,
        camera: Camera, origin: SIMD3<Double>, now: CFTimeInterval, opaquePipeline: MTLRenderPipelineState,
        transparentPipeline: MTLRenderPipelineState, additivePipeline: MTLRenderPipelineState,
        writeDepth: MTLDepthStencilState,
        readDepth: MTLDepthStencilState, frustum: RenderFrustum? = nil,
        visibleChunks: Set<ChunkPosition>? = nil, renderDistance: Float = 128
    ) {
        let activeIDs = Set(entities.map(\.id))
        animations = animations.filter { activeIDs.contains($0.key) }
        var batches: [Batch] = []
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
            var animation = animations[entity.id] ?? Animation(lastAge: entity.ageTicks, lastTickTime: now)
            if animation.lastAge != entity.ageTicks {
                let dx = entity.position.x - entity.previousPosition.x
                let dz = entity.position.z - entity.previousPosition.z
                let speed = min(1, Float(sqrt(dx * dx + dz * dz)) * 4)
                animation.amplitude += (speed - animation.amplitude) * 0.4
                animation.phase += animation.amplitude
                animation.lastAge = entity.ageTicks
                animation.lastTickTime = now
            }
            animations[entity.id] = animation
            let partial = Float(min(1, max(0, (now - animation.lastTickTime) * 20)))
            let interpolated =
                entity.previousPosition + (entity.position - entity.previousPosition) * Double(partial)
            let local = interpolated - origin
            let position = SIMD3(Float(local.x), Float(local.y), Float(local.z))
            let sample = world.light(
                at: BlockPosition(
                    Int(floor(entity.position.x)),
                    Int(floor(entity.position.y + entity.height * 0.85)), Int(floor(entity.position.z))))
            let light = sample.sky << 4 | max(sample.block, entity.fireTicks > 0 ? 15 : 0)
            let age = Float(entity.ageTicks) + partial
            let damageTint: SIMD3<Float> = entity.hurtTicks > 0 ? SIMD3(1, 0.5, 0.5) : SIMD3(repeating: 1)
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
                    let right = simd_normalize(simd_cross(camera.forward, SIMD3(0, 1, 0)))
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
                    if stack.id < 256, let kind = BlockKind(rawValue: UInt8(stack.id)), kind.isSolid {
                        batches.append(
                            Batch(
                                texture: "terrain",
                                vertices: blockVertices(
                                    state: BlockState(
                                        kind, metadata: UInt8(truncatingIfNeeded: stack.damage)),
                                    position: position + offset, yaw: age / 20, scale: 0.25, light: light)))
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
                        vertices: arrow(entity: entity, position: position, light: light)))
            default:
                let layers = EntityModels.layers(
                    entity: entity, phase: animation.phase,
                    amplitude: animation.amplitude, age: age)
                for layer in layers {
                    let vertices = layer.parts.flatMap {
                        $0.vertices(
                            position: position, yaw: entity.yaw, scale: layer.scale,
                            originY: layer.originY, tint: layer.tint * damageTint, light: light,
                            opacity: layer.opacity)
                    }
                    batches.append(Batch(texture: layer.texture, vertices: vertices, blended: layer.blended))
                }
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
        var activePistons: Set<BlockPosition> = []
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
                activePistons.insert(cell)
                var animation = pistons[cell] ?? (state.progress, now)
                if animation.progress != state.progress { animation = (state.progress, now) }
                pistons[cell] = animation
                let fraction = Float(min(1, max(0, (now - animation.time) * 20)))
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
        pistons = pistons.filter { activePistons.contains($0.key) }
        encoder.setCullMode(.none)
        for blended in [false, true] {
            encoder.setRenderPipelineState(blended ? transparentPipeline : opaquePipeline)
            encoder.setDepthStencilState(blended ? readDepth : writeDepth)
            for batch in batches where batch.blended == blended {
                guard !batch.vertices.isEmpty, let texture = texture(named: batch.texture) else { continue }
                let buffer = batch.vertices.withUnsafeBytes { bytes -> MTLBuffer? in
                    guard let address = bytes.baseAddress else { return nil }
                    return device.makeBuffer(bytes: address, length: bytes.count, options: .storageModeShared)
                }
                guard let buffer else { continue }
                encoder.setRenderPipelineState(
                    batch.additive ? additivePipeline : (blended ? transparentPipeline : opaquePipeline))
                encoder.setFragmentTexture(texture, index: 0)
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: batch.vertices.count)
            }
        }
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
        if let texture = textures[name] { return texture }
        guard let root = Bundle.main.resourceURL,
            let texture = try? loader.newTexture(
                URL: root.appendingPathComponent("Vanilla/\(name).png"),
                options: [
                    .origin: MTKTextureLoader.Origin.topLeft, .SRGB: false,
                ])
        else { return nil }
        textures[name] = texture
        return texture
    }

    private func blockVertices(
        state: BlockState, position: SIMD3<Float>, yaw: Float,
        scale: Float, light: UInt8
    ) -> [BlockVertex] {
        let key = UInt16(state.kind.rawValue) << 8 | UInt16(state.metadata)
        let source: [BlockVertex]
        if let cached = blockModels[key] {
            source = cached
        } else {
            var world = BlockWorld()
            world.setBlock(state, at: BlockPosition(0, 0, 0))
            source = BlockMesh(world: world).vertices
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
        let right = simd_normalize(simd_cross(camera.forward, SIMD3(0, 1, 0))) * width / 2
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

    private func arrow(entity: GameEntity, position: SIMD3<Float>, light: UInt8) -> [BlockVertex] {
        var result: [BlockVertex] = []
        for rotation in [Float.pi / 4, Float.pi * 3 / 4] {
            let points = [SIMD3<Float>(-8, -2, 0), SIMD3(8, -2, 0), SIMD3(8, 2, 0), SIMD3(-8, 2, 0)].map {
                let rolled = EntityModelPart.rotate($0, by: SIMD3(rotation, 0, 0)) * 0.05625
                let rotated = EntityModelPart.rotate(
                    rolled, by: SIMD3(0, -entity.yaw - .pi / 2, -entity.pitch))
                return position + rotated
            }
            result += quad(
                points: points, uv: [SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(0.5, 5 / 32), SIMD2(0, 5 / 32)],
                color: SIMD3(repeating: 1), light: light)
        }
        return result
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
