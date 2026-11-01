import MetalKit
import MinecraftCore
import simd

@MainActor
final class WorldEffectsRenderer {
    private let device: MTLDevice
    private var atlas: MTLTexture
    private let textures: NamedTextures
    private var particles: [Particle] = []
    private var roofCache: [SIMD2<Int>: Int] = [:]
    private var biomeCache: [SIMD2<Int>: BetaBiome] = [:]
    private var roofRevision: UInt64?
    private var weatherTicks: Float = 0
    private var random = JavaRandom(seed: 18727)
    private var climate: BetaClimateSource?
    private var climateSeed: Int64?
    private var dimension: Int8?

    private struct Particle {
        var position: SIMD3<Double>
        var velocity: SIMD3<Double>
        var age: Float = 0
        var lifetime: Float
        var size: Float
        var gravity: Double
        var index: Int
        var color: SIMD3<Float>
        var terrain = false
        var animated = false
        var fullbright = false
        var crop = SIMD2<Float>.zero
    }

    init(device: MTLDevice, atlas: MTLTexture) {
        self.device = device
        self.atlas = atlas
        textures = NamedTextures(device: device)
    }

    func reload(atlas: MTLTexture) {
        self.atlas = atlas
        textures.removeAll()
    }

    func draw(
        encoder: MTLRenderCommandEncoder, events: [BlockEvent], world: BlockWorld, camera: Camera,
        origin: SIMD3<Double>,
        delta: Float, rain: Float, pipeline: MTLRenderPipelineState, weatherPipeline: MTLRenderPipelineState,
        depth: MTLDepthStencilState, fancy: Bool = true
    ) {
        if climateSeed != world.seed || dimension != world.dimension {
            particles.removeAll(keepingCapacity: true)
            roofCache.removeAll(keepingCapacity: true)
            biomeCache.removeAll(keepingCapacity: true)
            climateSeed = world.seed
            dimension = world.dimension
            climate = BetaClimateSource(seed: world.seed)
        }
        weatherTicks += delta * 20
        for event in events {
            switch event {
            case .particle(let name, let position): spawn(name: name, position: position)
            case .explosion(let position, let power):
                for _ in 0..<min(256, Int(power * 24)) {
                    let offset = SIMD3(
                        random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1)
                    spawn(name: "explode", position: position + offset * Double(power) * 0.5)
                }
            default: break
            }
        }
        if particles.count > 4096 { particles.removeFirst(particles.count - 4096) }
        var terrain: [BlockVertex] = []
        var sprites: [BlockVertex] = []
        let step = Double(delta * 20)
        let right = SIMD3<Float>(cos(camera.yaw), 0, sin(camera.yaw))
        let up = simd_cross(right, camera.forward)
        for index in particles.indices {
            particles[index].age += delta
            particles[index].velocity.y -= particles[index].gravity * step
            let next = particles[index].position + particles[index].velocity * step
            if particles[index].gravity > 0, particles[index].velocity.y < 0,
                world[BlockPosition(Int(floor(next.x)), Int(floor(next.y)), Int(floor(next.z)))]?.isSolid
                    == true
            {
                particles[index].position.y = floor(next.y) + 1.001
                particles[index].velocity.y = 0
                particles[index].velocity.x *= 0.7
                particles[index].velocity.z *= 0.7
            } else {
                particles[index].position = next
            }
            particles[index].velocity *= pow(0.96, step)
            let particle = particles[index]
            let local = particle.position - origin
            let position = SIMD3(Float(local.x), Float(local.y), Float(local.z))
            let sample = world.light(
                at: BlockPosition(
                    Int(floor(particle.position.x)), Int(floor(particle.position.y)),
                    Int(floor(particle.position.z))))
            let light = particle.fullbright ? 255 : sample.sky << 4 | sample.block
            let frame =
                particle.animated ? max(0, 7 - Int(particle.age / particle.lifetime * 8)) : particle.index
            let tileOrigin = SIMD2(Float(frame & 15), Float(frame >> 4)) / 16 + particle.crop
            let uvSize: Float = particle.terrain ? 3.996 / 256 : 15.99 / 256
            let half = particle.size * min(1, particle.age * 32 / particle.lifetime)
            for corner in Self.cornerOrder {
                let vertex = BlockVertex(
                    position: position + right * (corner.x * half) + up * (corner.y * half),
                    color: particle.color,
                    uv: tileOrigin + SIMD2((corner.x + 1) / 2, (1 - corner.y) / 2) * uvSize, light: light)
                if particle.terrain { terrain.append(vertex) } else { sprites.append(vertex) }
            }
        }
        particles.removeAll { $0.age >= $0.lifetime }
        encoder.setCullMode(.none)
        encoder.setDepthStencilState(depth)
        encoder.setRenderPipelineState(pipeline)
        draw(vertices: terrain, texture: atlas, encoder: encoder)
        if let texture = textures.texture("particles") {
            draw(vertices: sprites, texture: texture, encoder: encoder)
        }
        guard rain > 0, world.dimension == 0 else { return }
        let radius = fancy ? 10 : 5
        if roofRevision != world.revision {
            roofRevision = world.revision
            roofCache.removeAll(keepingCapacity: true)
        }
        let center = SIMD2(
            Int(floor(origin.x + Double(camera.position.x))), Int(floor(origin.z + Double(camera.position.z)))
        )
        roofCache = roofCache.filter {
            abs($0.key.x - center.x) <= radius && abs($0.key.y - center.y) <= radius
        }
        biomeCache = biomeCache.filter {
            abs($0.key.x - center.x) <= radius && abs($0.key.y - center.y) <= radius
        }
        var rainVertices: [BlockVertex] = []
        var snowVertices: [BlockVertex] = []
        for x in center.x - radius...center.x + radius {
            for z in center.y - radius...center.y + radius {
                guard world.chunks[BlockPosition(x, 0, z).chunk] != nil else { continue }
                let key = SIMD2(x, z)
                let biome: BetaBiome
                if let cached = biomeCache[key] {
                    biome = cached
                } else {
                    biome = climate!.sample(x: x, z: z).biome
                    biomeCache[key] = biome
                }
                guard biome != .desert else { continue }
                let roof: Int
                if let cached = roofCache[key] {
                    roof = cached
                } else {
                    roof =
                        ((0..<128).reversed().first { y in
                            guard let block = world[BlockPosition(x, y, z)] else { return false }
                            return block.isMaterialSolid || block.isLiquid
                        } ?? -1) + 1
                    roofCache[key] = roof
                }
                let bottom = Float(max(roof, Int(floor(camera.position.y)) - radius))
                let top = Float(max(roof, Int(floor(camera.position.y)) + radius))
                guard top > bottom else { continue }
                let seed = Int32(
                    truncatingIfNeeded: x &* x &* 3121 &+ x &* 45_238_971 &+ z &* z &* 418711 &+ z &* 13761)
                var columnRandom = JavaRandom(seed: Int64(seed))
                let distance =
                    simd_length(
                        SIMD2(
                            Float(Double(x) - origin.x) + 0.5 - camera.position.x,
                            Float(Double(z) - origin.z) + 0.5 - camera.position.z)) / Float(radius)
                let snow = biome.hasSnow
                let opacity = max(0, (1 - distance * distance) * (snow ? 0.3 : 0.5) + 0.5) * rain
                let scroll: Float
                var horizontal: Float = 0
                if snow {
                    let time = weatherTicks
                    horizontal = columnRandom.nextFloat() + time * 0.01 * Float(columnRandom.nextGaussian())
                    scroll =
                        Float(Int(time) & 511) / 512 + columnRandom.nextFloat() + time
                        * Float(columnRandom.nextGaussian()) * 0.001
                } else {
                    scroll =
                        Float((Int(weatherTicks) &+ Int(seed)) & 31) / 32 * (3 + columnRandom.nextFloat())
                }
                let sample = world.light(at: BlockPosition(x, max(roof, Int(camera.position.y)), z))
                let light: UInt8 = snow ? sample.sky << 4 | sample.block : 240
                let uv = [
                    SIMD2(horizontal, bottom / 4 + scroll), SIMD2(horizontal + 1, bottom / 4 + scroll),
                    SIMD2(horizontal + 1, top / 4 + scroll), SIMD2(horizontal, top / 4 + scroll),
                ]
                let fx = Float(Double(x) - origin.x)
                let fz = Float(Double(z) - origin.z)
                let first = [
                    SIMD3(fx, bottom, fz + 0.5), SIMD3(fx + 1, bottom, fz + 0.5),
                    SIMD3(fx + 1, top, fz + 0.5), SIMD3(fx, top, fz + 0.5),
                ]
                let second = [
                    SIMD3(fx + 0.5, bottom, fz), SIMD3(fx + 0.5, bottom, fz + 1),
                    SIMD3(fx + 0.5, top, fz + 1), SIMD3(fx + 0.5, top, fz),
                ]
                let vertices =
                    Self.quad(first, uv: uv, light: light, opacity: opacity, textureWeight: snow ? 1 : 2)
                    + Self.quad(second, uv: uv, light: light, opacity: opacity, textureWeight: snow ? 1 : 2)
                if snow { snowVertices += vertices } else { rainVertices += vertices }
            }
        }
        encoder.setRenderPipelineState(weatherPipeline)
        if let texture = textures.texture("environment/rain") {
            draw(vertices: rainVertices, texture: texture, encoder: encoder)
        }
        if let texture = textures.texture("environment/snow") {
            draw(vertices: snowVertices, texture: texture, encoder: encoder)
        }
    }

    private func spawn(name: String, position: SIMD3<Double>) {
        let parts = name.split(separator: "_")
        let digging = parts.first == "tilecrack" && parts.count >= 2
        let block = digging ? UInt8(parts[1]).flatMap(BlockKind.init(rawValue:)) : nil
        let metadata = parts.count > 2 ? UInt8(parts[2]) ?? 0 : 0
        for index in 0..<(digging ? 64 : 1) {
            let offset =
                digging
                ? SIMD3(
                    Double(index % 4) / 4 - 0.375, Double(index / 16) / 4 - 0.375,
                    Double(index / 4 % 4) / 4 - 0.375) : .zero
            let velocity =
                digging
                ? offset * 0.2 + SIMD3(0, 0.1, 0)
                : SIMD3(random.nextDouble() * 0.04 - 0.02, 0.02, random.nextDouble() * 0.04 - 0.02)
            var particle = Particle(
                position: position + offset, velocity: velocity,
                lifetime: Float(8 / (random.nextDouble() * 0.8 + 0.2)) / 20,
                size: digging ? 0.05 : 0.1, gravity: digging ? 0.04 : -0.004,
                index: 0, color: SIMD3(repeating: digging ? 0.6 : random.nextFloat() * 0.3), terrain: digging,
                animated: !digging)
            if let block {
                particle.index = BlockAtlas.textureIndex(
                    for: BlockState(block, metadata: metadata), face: .bottom)
                particle.crop = SIMD2(random.nextFloat(), random.nextFloat()) * (3 / 64)
            } else {
                switch name {
                case "flame":
                    particle.index = 48
                    particle.animated = false
                    particle.fullbright = true
                    particle.color = SIMD3(repeating: 1)
                    particle.gravity = 0
                case "portal":
                    particle.color = SIMD3(0.9, 0.3, 1)
                    particle.fullbright = true
                    particle.lifetime = 2
                    particle.gravity = 0
                case "reddust", "redstone":
                    particle.color = SIMD3(0.8, 0, 0)
                    particle.gravity = 0
                case "bubble":
                    particle.index = 32
                    particle.animated = false
                    particle.color = SIMD3(repeating: 1)
                    particle.gravity = -0.002
                case "splash":
                    particle.index = 19
                    particle.animated = false
                    particle.color = SIMD3(repeating: 1)
                    particle.gravity = 0.04
                    particle.velocity.y = 0.1
                case "heart":
                    particle.index = 80
                    particle.animated = false
                    particle.color = SIMD3(repeating: 1)
                    particle.gravity = 0
                    particle.velocity.y = 0.05
                case "explode":
                    particle.size = 0.3
                    particle.color = SIMD3(repeating: 0.7 + random.nextFloat() * 0.3)
                    particle.lifetime *= 2
                case "largesmoke": particle.size *= 2.5
                default: break
                }
            }
            particles.append(particle)
        }
    }

    private static let cornerOrder: [SIMD2<Float>] = [
        SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, -1), SIMD2(1, 1), SIMD2(-1, 1),
    ]

    private static func quad(
        _ points: [SIMD3<Float>], uv: [SIMD2<Float>], color: SIMD3<Float> = SIMD3(repeating: 1), light: UInt8,
        opacity: Float = 1, textureWeight: Float = 1
    ) -> [BlockVertex] {
        [0, 1, 2, 0, 2, 3].map {
            BlockVertex(
                position: points[$0], color: color, uv: uv[$0], opacity: opacity,
                textureWeight: textureWeight, light: light)
        }
    }

    private func draw(vertices: [BlockVertex], texture: MTLTexture, encoder: MTLRenderCommandEncoder) {
        guard !vertices.isEmpty else { return }
        guard let buffer = device.makeSharedBuffer(vertices) else { return }
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
}
