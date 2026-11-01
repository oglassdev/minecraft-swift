import Foundation

public struct WorldWeather: Sendable {
    public enum Precipitation: Sendable { case none, rain, snow }

    public var raining: Bool
    public var thundering: Bool
    public var rainTime: Int
    public var thunderTime: Int
    public var rainStrength: Float
    public var thunderStrength: Float
    public private(set) var previousRainStrength: Float = 0
    public private(set) var previousThunderStrength: Float = 0
    public private(set) var lightningFlashTicks = 0
    private var random: JavaRandom
    private var coordinateState: Int32
    private let climate: BetaClimateSource

    public init(
        seed: Int64, raining: Bool = false, thundering: Bool = false,
        rainTime: Int = 0, thunderTime: Int = 0
    ) {
        self.raining = raining
        self.thundering = thundering
        self.rainTime = rainTime
        self.thunderTime = thunderTime
        rainStrength = raining ? 1 : 0
        thunderStrength = raining && thundering ? 1 : 0
        random = JavaRandom(seed: seed)
        coordinateState = Int32(truncatingIfNeeded: seed)
        climate = BetaClimateSource(seed: seed)
    }

    public var weightedThunderStrength: Float { rainStrength * thunderStrength }

    public mutating func tick(world: inout BlockWorld, players: [SIMD3<Double>], time: Int64) -> [BlockEvent]
    {
        var random = self.random
        let events = tick(world: &world, players: players, time: time, random: &random)
        self.random = random
        return events
    }

    public mutating func tick(
        world: inout BlockWorld, players: [SIMD3<Double>], time: Int64,
        random: inout JavaRandom
    ) -> [BlockEvent] {
        guard world.dimension != -1 else { return [] }
        if lightningFlashTicks > 0 { lightningFlashTicks -= 1 }
        if thunderTime <= 0 {
            thunderTime =
                thundering ? random.nextInt(bound: 12000) + 3600 : random.nextInt(bound: 168000) + 12000
        } else {
            thunderTime -= 1
            if thunderTime == 0 { thundering.toggle() }
        }
        if rainTime <= 0 {
            rainTime = raining ? random.nextInt(bound: 12000) + 12000 : random.nextInt(bound: 168000) + 12000
        } else {
            rainTime -= 1
            if rainTime == 0 { raining.toggle() }
        }
        previousRainStrength = rainStrength
        previousThunderStrength = thunderStrength
        rainStrength = min(1, max(0, Float(Double(rainStrength) + (raining ? 0.01 : -0.01))))
        thunderStrength = min(1, max(0, Float(Double(thunderStrength) + (thundering ? 0.01 : -0.01))))

        let playerChunks = players.map { ChunkPosition(Int(floor($0.x / 16)), Int(floor($0.z / 16))) }
        let active = world.chunks.keys.filter { chunk in
            playerChunks.contains { abs($0.x - chunk.x) <= 9 && abs($0.z - chunk.z) <= 9 }
        }.sorted { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }
        var events: [BlockEvent] = []
        for chunk in active {
            if random.nextInt(bound: 100000) == 0 && Double(rainStrength) > 0.2
                && Double(weightedThunderStrength) > 0.9
            {
                let column = nextColumn(in: chunk)
                let position = BlockPosition(
                    column.x, precipitationHeight(x: column.x, z: column.z, in: world), column.z)
                if canStrikeLightning(at: position, in: world) {
                    events.append(
                        .spawnEntity(
                            kind: "lightningBolt",
                            position: SIMD3(Double(position.x), Double(position.y), Double(position.z))))
                    lightningFlashTicks = 2
                }
            }
            if random.nextInt(bound: 16) == 0 {
                let column = nextColumn(in: chunk)
                applyPrecipitation(x: column.x, z: column.z, world: &world)
            }
            // World.tickBlocksAndAmbiance also consumes 80 LCG coordinates after its weather checks.
            for _ in 0..<80 { advanceCoordinates() }
        }
        return events
    }

    public mutating func stopPrecipitation() {
        rainTime = 0
        thunderTime = 0
        raining = false
        thundering = false
    }

    public func interpolatedRainStrength(_ fraction: Float) -> Float {
        previousRainStrength + (rainStrength - previousRainStrength) * fraction
    }

    public func interpolatedThunderStrength(_ fraction: Float) -> Float {
        (previousThunderStrength + (thunderStrength - previousThunderStrength) * fraction)
            * interpolatedRainStrength(fraction)
    }

    public func celestialAngle(time: Int64, partialTick: Float = 0, dimension: Int8 = 0) -> Float {
        if dimension == -1 { return 0.5 }
        var angle = (Float(time % 24000) + partialTick) / 24000 - 0.25
        if angle < 0 { angle += 1 }
        if angle > 1 { angle -= 1 }
        let original = angle
        angle = 1 - Float((cos(Double(angle) * .pi) + 1) / 2)
        return original + (angle - original) / 3
    }

    public func skylightSubtraction(time: Int64, partialTick: Float = 1, dimension: Int8 = 0) -> Int {
        let angle = celestialAngle(time: time, partialTick: partialTick, dimension: dimension)
        var darkness = 1 - (Self.cosine(angle * .pi * 2) * 2 + 0.5)
        darkness = min(1, max(0, darkness))
        darkness = 1 - darkness
        darkness = Float(Double(darkness) * (1 - Double(interpolatedRainStrength(partialTick) * 5) / 16))
        darkness = Float(Double(darkness) * (1 - Double(interpolatedThunderStrength(partialTick) * 5) / 16))
        darkness = 1 - darkness
        return Int(darkness * 11)
    }

    public static func precipitation(temperature: Double, humidity: Double, dimension: Int8 = 0)
        -> Precipitation
    {
        guard dimension != -1 else { return .none }
        let biome = BetaBiome.lookup(temperature: temperature, humidity: humidity)
        if biome.hasSnow { return .snow }
        return biome == .desert ? .none : .rain
    }

    public func precipitation(atX x: Int, z: Int, in world: BlockWorld) -> Precipitation {
        guard world.dimension != -1 else { return .none }
        let sample = climate.sample(x: x, z: z)
        if sample.biome.hasSnow { return .snow }
        return sample.biome == .desert ? .none : .rain
    }

    public func canRain(at position: BlockPosition, in world: BlockWorld) -> Bool {
        guard world.dimension != -1, position.y >= 0, Double(rainStrength) > 0.2,
            world.chunks[position.chunk] != nil,
            precipitation(atX: position.x, z: position.z, in: world) == .rain,
            precipitationHeight(x: position.x, z: position.z, in: world) <= position.y
        else { return false }
        if position.y < 128 {
            for y in max(0, position.y)..<128 {
                if (world[BlockPosition(position.x, y, position.z)]?.lightOpacity ?? 0) > 0 { return false }
            }
        }
        return true
    }

    public func canStrikeLightning(at position: BlockPosition, in world: BlockWorld) -> Bool {
        Double(weightedThunderStrength) > 0.9 && canRain(at: position, in: world)
    }

    private func applyPrecipitation(x: Int, z: Int, world: inout BlockWorld) {
        let y = precipitationHeight(x: x, z: z, in: world)
        guard y >= 0, y < 128, precipitation(atX: x, z: z, in: world) == .snow else { return }
        let position = BlockPosition(x, y, z)
        guard world.light(at: position).block < 10 else { return }
        let below = BlockPosition(x, y - 1, z)
        if Double(rainStrength) > 0.2 && world[position] == nil && world[below] != nil && world[below] != .ice
            && world[below]?.isMaterialSolid == true
            && BlockPlacement.canRemain(BlockState(.snowLayer), at: position, in: world)
        {
            world[position] = .snowLayer
        }
        if world[below] == .stillWater && world.state(at: below)?.metadata == 0 { world[below] = .ice }
    }

    private func precipitationHeight(x: Int, z: Int, in world: BlockWorld) -> Int {
        for y in (1..<128).reversed() {
            guard let kind = world[BlockPosition(x, y, z)] else { continue }
            if kind.isMaterialSolid || kind.isLiquid { return y + 1 }
        }
        return -1
    }

    private mutating func advanceCoordinates() { coordinateState = coordinateState &* 3 &+ 1_013_904_223 }

    private mutating func nextColumn(in chunk: ChunkPosition) -> BlockPosition {
        advanceCoordinates()
        let bits = coordinateState >> 2
        return BlockPosition(chunk.x * 16 + Int(bits & 15), 0, chunk.z * 16 + Int(bits >> 8 & 15))
    }

    private static func cosine(_ value: Float) -> Float {
        let index = Int(value * 10430.378 + 16384) & 65535
        return Float(sin(Double(index) * .pi * 2 / 65536))
    }
}
