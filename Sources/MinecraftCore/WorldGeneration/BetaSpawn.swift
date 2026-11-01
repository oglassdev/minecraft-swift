import Foundation

public enum BetaSpawn {
    /// The random stream is the world's environmental Random at spawn-search entry.
    public static func initialGlobal(
        world: inout BlockWorld, random: inout JavaRandom,
        loadChunk: (ChunkPosition) throws -> Chunk
    ) rethrows -> BlockPosition {
        var x = 0
        var z = 0
        while true {
            let block = try spawnColumnBlock(x: x, z: z, world: &world, loadChunk: loadChunk)
            let valid =
                world.dimension == -1
                ? block != nil && block != .bedrock && block?.isOpaque == true : block == .sand
            if valid { return BlockPosition(x, 64, z) }
            x += random.nextInt(bound: 64) - random.nextInt(bound: 64)
            z += random.nextInt(bound: 64) - random.nextInt(bound: 64)
        }
    }

    /// World.d() validates the stored global spawn before single-player respawning.
    public static func adjustGlobal(
        world: inout BlockWorld, spawn: inout BlockPosition, random: inout JavaRandom,
        loadChunk: (ChunkPosition) throws -> Chunk
    ) rethrows {
        if spawn.y <= 0 { spawn.y = 64 }
        while try spawnColumnBlock(x: spawn.x, z: spawn.z, world: &world, loadChunk: loadChunk) == nil {
            spawn.x += random.nextInt(bound: 8) - random.nextInt(bound: 8)
            spawn.z += random.nextInt(bound: 8) - random.nextInt(bound: 8)
        }
    }

    /// Single-player starts one block above global spawn, then rises until its bounds clear.
    public static func playerPosition(
        world: inout BlockWorld, spawn: BlockPosition,
        loadChunk: (ChunkPosition) throws -> Chunk
    ) rethrows -> SIMD3<Double> {
        try ensureLoaded(spawn.chunk, world: &world, loadChunk: loadChunk)
        var position = SIMD3(Double(spawn.x) + 0.5, Double(spawn.y + 1), Double(spawn.z) + 0.5)
        while position.y + Double(Float(1.62)) > 0 {
            let bounds = Player(position: position).bounds
            if BlockCollision.boxes(in: world, intersecting: bounds).isEmpty { break }
            position.y += 1
        }
        return position
    }

    private static func spawnColumnBlock(
        x: Int, z: Int, world: inout BlockWorld, loadChunk: (ChunkPosition) throws -> Chunk
    ) rethrows -> BlockKind? {
        try ensureLoaded(ChunkPosition(x >> 4, z >> 4), world: &world, loadChunk: loadChunk)
        var y = 63
        while world[BlockPosition(x, y + 1, z)] != nil { y += 1 }
        return world[BlockPosition(x, y, z)]
    }

    private static func ensureLoaded(
        _ position: ChunkPosition, world: inout BlockWorld,
        loadChunk: (ChunkPosition) throws -> Chunk
    ) rethrows {
        guard world.chunks[position] == nil else { return }
        let chunk = try loadChunk(position)
        precondition(chunk.position == position)
        world.setChunk(chunk)
    }
}
