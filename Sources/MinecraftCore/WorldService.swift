import Foundation

public struct LoadedGame: Sendable {
    public let world: BlockWorld
    public let level: SavedLevel
    public let center: ChunkPosition
    public let maps: BetaMapCollection
    public let radius: Int
}

public actor WorldService {
    public enum TransitionError: Error { case staleWorld }
    private let storage: WorldStorage
    private let mapStorage: BetaMapStorage
    private let newWorldSeed: Int64
    private let newWorldName: String
    private var generator = BetaTerrainGenerator(seed: 0)
    private var netherGenerator = BetaNetherGenerator(seed: 0)
    private var currentDimension: Int8 = 0

    public init(directory: URL, newWorldSeed: Int64 = 0, newWorldName: String = "World") {
        storage = WorldStorage(directory: directory)
        mapStorage = BetaMapStorage(directory: directory.appendingPathComponent("data"))
        self.newWorldSeed = newWorldSeed
        self.newWorldName = newWorldName
    }

    public func flush() {}

    public func load(radius: Int = 3) throws -> LoadedGame {
        let saved = try storage.loadLevel()
        let seed = saved?.seed ?? newWorldSeed
        generator = BetaTerrainGenerator(seed: seed)
        netherGenerator = BetaNetherGenerator(seed: seed)
        currentDimension = saved?.player.dimension ?? 0
        storage.dimension = currentDimension
        var center =
            saved.map {
                ChunkPosition(Int(floor($0.player.position.x)) >> 4, Int(floor($0.player.position.z)) >> 4)
            } ?? ChunkPosition(0, 0)
        var world = BlockWorld(seed: seed, dimension: currentDimension)
        let spawn: BlockPosition
        if let saved {
            spawn = saved.spawn
        } else {
            var random = JavaRandom(seed: Int64.random(in: .min ... .max))
            _ = random.nextInt(bound: 12000)
            spawn = try BetaSpawn.initialGlobal(world: &world, random: &random, loadChunk: loadChunk)
            center = spawn.chunk
        }
        try loadRegion(around: center, into: &world, radius: radius)
        populate(&world)
        let level: SavedLevel
        if let saved {
            level = saved
        } else {
            let position = try BetaSpawn.playerPosition(world: &world, spawn: spawn, loadChunk: loadChunk)
            let player = SavedPlayer(
                position: position, velocity: .zero, yaw: 0, pitch: 0, health: 20,
                inventory: PlayerInventory(), dimension: currentDimension)
            level = SavedLevel(seed: seed, time: 0, spawn: spawn, player: player, name: newWorldName)
        }
        WorldLighting.rebuild(world: &world)
        return LoadedGame(
            world: world, level: level, center: center, maps: try mapStorage.load(),
            radius: min(16, max(1, radius)))
    }

    public func extend(
        _ snapshot: BlockWorld, around center: ChunkPosition, maximumEntityID: Int64, radius: Int = 3
    ) throws
        -> [Chunk]
    {
        guard snapshot.dimension == currentDimension else { return [] }
        storage.reserveEntityIDs(through: maximumEntityID)
        var world = snapshot
        try loadRegion(around: center, into: &world, radius: radius)
        populate(&world)
        let changedChunks = world.pendingLightingChunks
        WorldLighting.rebuild(world: &world, changedChunks: changedChunks)
        return world.chunks.values.filter { chunk in
            guard let old = snapshot.chunks[chunk.position] else { return true }
            return old.revision != chunk.revision || old.isTerrainPopulated != chunk.isTerrainPopulated
                || old.skyLight != chunk.skyLight || old.blockLight != chunk.blockLight
        }
    }

    public func save(chunks: [Chunk], level: SavedLevel, maps: BetaMapCollection? = nil) throws {
        guard level.player.dimension == currentDimension else { return }
        for chunk in chunks { try storage.saveChunk(chunk, worldTime: level.time) }
        if let maps { try mapStorage.save(maps) }
        try storage.saveLevel(level)
    }

    public func saveChunks(_ chunks: [Chunk], worldTime: Int64, dimension: Int8) throws {
        guard dimension == currentDimension else { return }
        for chunk in chunks { try storage.saveChunk(chunk, worldTime: worldTime) }
    }

    public func travel(
        from snapshot: BlockWorld, level: SavedLevel, to dimension: Int8,
        position: SIMD3<Double>, yaw: Float, placePortal: Bool = true, maps: BetaMapCollection? = nil
    ) throws -> LoadedGame {
        guard snapshot.dimension == currentDimension, level.player.dimension == currentDimension else {
            throw TransitionError.staleWorld
        }
        try save(chunks: Array(snapshot.chunks.values), level: level, maps: maps)
        let previousDimension = currentDimension
        currentDimension = dimension
        storage.dimension = dimension
        do {
            let target = ChunkPosition(Int(floor(position.x)) >> 4, Int(floor(position.z)) >> 4)
            var world = BlockWorld(seed: snapshot.seed, dimension: dimension)
            try loadRegion(around: target, into: &world)
            populate(&world)
            if placePortal { try loadExistingPortalArea(near: position, into: &world) }
            let arrival =
                placePortal ? BetaPortalTravel.place(world: &world, near: position, yaw: yaw) : position
            let center = ChunkPosition(Int(floor(arrival.x)) >> 4, Int(floor(arrival.z)) >> 4)
            try loadRegion(around: center, into: &world)
            populate(&world)
            var level = level
            level.player.position = arrival
            level.player.velocity = .zero
            if placePortal { level.player.pitch = 0 }
            level.player.dimension = dimension
            WorldLighting.rebuild(world: &world)
            for chunk in world.chunks.values { try storage.saveChunk(chunk, worldTime: level.time) }
            for chunk in Array(world.chunks.keys)
            where abs(chunk.x - center.x) > 4 || abs(chunk.z - center.z) > 4 {
                world.removeChunk(at: chunk)
            }
            try storage.saveLevel(level)
            return LoadedGame(
                world: world, level: level, center: center, maps: try maps ?? mapStorage.load(), radius: 3)
        } catch {
            currentDimension = previousDimension
            storage.dimension = previousDimension
            throw error
        }
    }

    private func loadExistingPortalArea(near position: SIMD3<Double>, into world: inout BlockWorld) throws {
        let x = Int(floor(position.x))
        let z = Int(floor(position.z))
        for chunkX in (((x - 128) >> 4) - 1)...(((x + 128) >> 4) + 1) {
            for chunkZ in (((z - 128) >> 4) - 1)...(((z + 128) >> 4) + 1) {
                let chunk = ChunkPosition(chunkX, chunkZ)
                guard world.chunks[chunk] == nil, let saved = try existingChunk(at: chunk) else { continue }
                world.setChunk(saved)
            }
        }
    }

    private func loadRegion(around center: ChunkPosition, into world: inout BlockWorld, radius: Int = 3)
        throws
    {
        let radius = min(16, max(1, radius))
        for x in (center.x - radius)...(center.x + radius) {
            for z in (center.z - radius)...(center.z + radius) {
                try Task.checkCancellation()
                let position = ChunkPosition(x, z)
                guard world.chunks[position] == nil else { continue }
                world.setChunk(try loadChunk(at: position))
            }
        }
    }

    private func populate(_ world: inout BlockWorld) {
        let positions = world.chunks.keys.sorted { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }
        for position in positions {
            guard world.chunks[position]?.isTerrainPopulated == false else { continue }
            let available = ((position.x - 1)...(position.x + 2)).allSatisfy { x in
                ((position.z - 1)...(position.z + 2)).allSatisfy { z in
                    world.chunks[ChunkPosition(x, z)] != nil
                }
            }
            guard available else { continue }
            if world.dimension == -1 {
                netherGenerator.populate(world: &world, chunkX: position.x, chunkZ: position.z)
            } else {
                generator.populate(world: &world, chunkX: position.x, chunkZ: position.z)
            }
            world.markChunkPopulated(at: position)
        }
    }

    private func loadChunk(at position: ChunkPosition) throws -> Chunk {
        try Task.checkCancellation()
        guard let chunk = try existingChunk(at: position) else {
            if currentDimension == -1 { return netherGenerator.generateChunk(x: position.x, z: position.z) }
            return generator.generateChunk(x: position.x, z: position.z)
        }
        return chunk
    }

    private func existingChunk(at position: ChunkPosition) throws -> Chunk? {
        guard var chunk = try storage.loadChunk(at: position) else { return nil }
        if currentDimension == -1 {
            for x in 0..<16 {
                for z in 0..<16 { chunk.setClimate(temperature: 1, humidity: 0, x: x, z: z) }
            }
            return chunk
        }
        let samples = generator.climate.region(x: position.x * 16, z: position.z * 16)
        for x in 0..<16 {
            for z in 0..<16 {
                let sample = samples[x * 16 + z]
                chunk.setClimate(temperature: sample.temperature, humidity: sample.humidity, x: x, z: z)
            }
        }
        return chunk
    }

}
