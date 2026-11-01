public struct BlockPosition: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var vector: SIMD3<Float> { SIMD3(Float(x), Float(y), Float(z)) }
    public var chunk: ChunkPosition { ChunkPosition(x: x >> 4, z: z >> 4) }
}

public struct BlockWorld: Sendable {
    public let seed: Int64
    public let dimension: Int8
    public private(set) var chunks: [ChunkPosition: Chunk] = [:]
    public private(set) var revision: UInt64 = 0
    public private(set) var lightingRevision: UInt64 = 0
    public private(set) var pendingLightingChunks: Set<ChunkPosition> = []
    public private(set) var chunkRevisions: [ChunkPosition: UInt64] = [:]

    public init(seed: Int64 = 0, dimension: Int8 = 0) {
        self.seed = seed
        self.dimension = dimension
    }

    public var blocks: [BlockPosition: BlockKind] {
        var result: [BlockPosition: BlockKind] = [:]
        forEachBlock { position, state in result[position] = state.kind }
        return result
    }

    public subscript(position: BlockPosition) -> BlockKind? {
        get { state(at: position)?.kind }
        set { setBlock(newValue.map { BlockState($0) }, at: position) }
    }

    public func state(at position: BlockPosition) -> BlockState? {
        chunks[position.chunk]?[position.x & 15, position.y, position.z & 15]
    }

    public mutating func setBlock(_ state: BlockState?, at position: BlockPosition) {
        guard (0..<128).contains(position.y), self.state(at: position) != state else { return }
        let oldKind = self.state(at: position)?.kind
        if oldKind != state?.kind
            && !([BlockKind.furnace, .burningFurnace].contains(oldKind ?? .air)
                && [BlockKind.furnace, .burningFurnace].contains(state?.kind ?? .air))
        {
            chunks[position.chunk]?.blockEntities[position] = nil
        }
        chunks[position.chunk, default: Chunk(position: position.chunk)][
            position.x & 15, position.y, position.z & 15] = state
        lightingRevision &+= 1
        pendingLightingChunks.insert(position.chunk)
        invalidate(position.chunk)
        if position.x & 15 == 0 { invalidate(ChunkPosition(position.chunk.x - 1, position.chunk.z)) }
        if position.x & 15 == 15 { invalidate(ChunkPosition(position.chunk.x + 1, position.chunk.z)) }
        if position.z & 15 == 0 { invalidate(ChunkPosition(position.chunk.x, position.chunk.z - 1)) }
        if position.z & 15 == 15 { invalidate(ChunkPosition(position.chunk.x, position.chunk.z + 1)) }
    }

    public mutating func setChunk(_ chunk: Chunk, updateLighting: Bool = true) {
        chunks[chunk.position] = chunk
        if updateLighting {
            lightingRevision &+= 1
            pendingLightingChunks.insert(chunk.position)
        }
        invalidate(chunk.position)
        for offset in [ChunkPosition(-1, 0), ChunkPosition(1, 0), ChunkPosition(0, -1), ChunkPosition(0, 1)] {
            invalidate(ChunkPosition(chunk.position.x + offset.x, chunk.position.z + offset.z))
        }
    }

    public mutating func removeChunk(at position: ChunkPosition) {
        guard chunks.removeValue(forKey: position) != nil else { return }
        pendingLightingChunks.remove(position)
        invalidate(position)
        for offset in [ChunkPosition(-1, 0), ChunkPosition(1, 0), ChunkPosition(0, -1), ChunkPosition(0, 1)] {
            invalidate(ChunkPosition(position.x + offset.x, position.z + offset.z))
        }
    }

    public mutating func markChunkPopulated(at position: ChunkPosition) {
        chunks[position]?.isTerrainPopulated = true
    }

    public func blockEntity(at position: BlockPosition) -> BlockEntity? {
        chunks[position.chunk]?.blockEntities[position]
    }

    public mutating func setBlockEntity(_ entity: BlockEntity?, at position: BlockPosition) {
        guard chunks[position.chunk] != nil, blockEntity(at: position) != entity else { return }
        chunks[position.chunk]?.setBlockEntity(entity, at: position)
        revision &+= 1
    }

    public mutating func applyLighting(from chunk: Chunk) {
        pendingLightingChunks.remove(chunk.position)
        guard let current = chunks[chunk.position],
            current.skyLight != chunk.skyLight || current.blockLight != chunk.blockLight
        else { return }
        chunks[chunk.position]?.skyLight = chunk.skyLight
        chunks[chunk.position]?.blockLight = chunk.blockLight
        invalidate(chunk.position)
        for offset in [ChunkPosition(-1, 0), ChunkPosition(1, 0), ChunkPosition(0, -1), ChunkPosition(0, 1)] {
            invalidate(ChunkPosition(chunk.position.x + offset.x, chunk.position.z + offset.z))
        }
    }

    public func climate(atX x: Int, z: Int) -> (temperature: Double, humidity: Double) {
        guard let chunk = chunks[ChunkPosition(x >> 4, z >> 4)] else { return (0.5, 0.5) }
        let index = (x & 15) * 16 + (z & 15)
        return (chunk.temperatures[index], chunk.humidities[index])
    }

    public func light(at position: BlockPosition) -> (sky: UInt8, block: UInt8) {
        guard position.y >= 0 else { return (0, 0) }
        guard position.y < 128, let chunk = chunks[position.chunk] else {
            return (dimension == -1 ? 0 : 15, 0)
        }
        let index = Chunk.index(x: position.x & 15, y: position.y, z: position.z & 15)
        return (dimension == -1 ? 0 : chunk.skyLight[index], chunk.blockLight[index])
    }

    public func forEachBlock(_ body: (BlockPosition, BlockState) -> Void) {
        for position in chunks.keys.sorted(by: { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }) {
            forEachBlock(in: position, body)
        }
    }

    public func forEachBlock(in position: ChunkPosition, _ body: (BlockPosition, BlockState) -> Void) {
        guard let chunk = chunks[position], chunk.blockCount > 0 else { return }
        for x in 0..<16 {
            for z in 0..<16 {
                for y in 0..<128 {
                    if let state = chunk[x, y, z] {
                        body(BlockPosition(position.x * 16 + x, y, position.z * 16 + z), state)
                    }
                }
            }
        }
    }

    private mutating func invalidate(_ position: ChunkPosition) {
        revision &+= 1
        chunkRevisions[position] = revision
    }

    /// A deterministic hand-built scene; this is not Beta terrain generation.
    public static func demo() -> Self {
        var world = Self()
        for x in -16..<16 {
            for z in -16..<16 {
                let hill = max(0, 4 - (abs(x + 5) + abs(z + 5)) / 3)
                for y in -2...hill {
                    let kind: BlockKind
                    if y == hill {
                        kind = .grass
                    } else if y < hill - 1 {
                        kind = .stone
                    } else {
                        kind = .dirt
                    }
                    world[BlockPosition(x, y, z)] = kind
                }
            }
        }
        for (x, z) in [(3, 1), (-7, 4), (5, -8)] {
            for y in 1...4 { world[BlockPosition(x, y, z)] = .wood }
            for dx in -2...2 {
                for dz in -2...2 {
                    for y in 4...6 where abs(dx) + abs(dz) < 4 {
                        let position = BlockPosition(x + dx, y, z + dz)
                        if world[position] == nil { world[position] = .leaves }
                    }
                }
            }
        }
        for x in 5...9 {
            for z in 5...8 { world[BlockPosition(x, 0, z)] = .sand }
        }
        for y in 1...3 { world[BlockPosition(-1, y, 5)] = .stone }
        return world
    }
}
