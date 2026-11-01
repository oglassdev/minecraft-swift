public struct ChunkPosition: Hashable, Codable, Sendable {
    public var x: Int
    public var z: Int

    public init(x: Int, z: Int) {
        self.x = x
        self.z = z
    }
    public init(_ x: Int, _ z: Int) { self.init(x: x, z: z) }

    public func hash(into hasher: inout Hasher) { hasher.combine(x << 32 | z & 0xFFFF_FFFF) }
}

public struct Chunk: Sendable, Codable {
    public static let width = 16
    public static let height = 128
    public static let volume = 32768
    public let position: ChunkPosition
    public var isTerrainPopulated = false
    public var blockEntities: [BlockPosition: BlockEntity] = [:]
    public var entities: [GameEntity] = []
    public private(set) var blockIDs: [UInt8]
    public private(set) var metadata: [UInt8]
    public var skyLight: [UInt8]
    public var blockLight: [UInt8]
    public private(set) var temperatures: [Double]
    public private(set) var humidities: [Double]
    public private(set) var revision: UInt64 = 0
    public private(set) var blockCount: Int = 0

    public init(position: ChunkPosition) {
        self.position = position
        blockIDs = Array(repeating: 0, count: Self.volume)
        metadata = Array(repeating: 0, count: Self.volume)
        skyLight = Array(repeating: 15, count: Self.volume)
        blockLight = Array(repeating: 0, count: Self.volume)
        temperatures = Array(repeating: 0.5, count: 256)
        humidities = Array(repeating: 0.5, count: 256)
    }

    public enum StorageError: Error { case invalidArrayLength }

    public init(
        position: ChunkPosition, blockIDs: [UInt8], metadata: [UInt8], skyLight: [UInt8], blockLight: [UInt8]
    ) throws {
        guard
            [blockIDs.count, metadata.count, skyLight.count, blockLight.count].allSatisfy({
                $0 == Self.volume
            })
        else {
            throw StorageError.invalidArrayLength
        }
        self.position = position
        self.blockIDs = blockIDs
        self.metadata = metadata.map { $0 & 15 }
        self.skyLight = skyLight.map { $0 & 15 }
        self.blockLight = blockLight.map { $0 & 15 }
        self.blockCount = blockIDs.reduce(0) { $0 + ($1 == 0 ? 0 : 1) }
        temperatures = Array(repeating: 0.5, count: 256)
        humidities = Array(repeating: 0.5, count: 256)
    }

    public subscript(x: Int, y: Int, z: Int) -> BlockState? {
        get {
            guard (0..<16).contains(x), (0..<128).contains(y), (0..<16).contains(z) else { return nil }
            let index = Self.index(x: x, y: y, z: z)
            guard blockIDs[index] != 0, let kind = BlockKind(rawValue: blockIDs[index]) else { return nil }
            return BlockState(kind, metadata: metadata[index])
        }
        set {
            guard (0..<16).contains(x), (0..<128).contains(y), (0..<16).contains(z) else { return }
            let index = Self.index(x: x, y: y, z: z)
            let id = newValue?.kind.rawValue ?? 0
            let data = (newValue?.metadata ?? 0) & 15
            guard blockIDs[index] != id || metadata[index] != data else { return }
            if blockIDs[index] == 0 && id != 0 { blockCount += 1 }
            if blockIDs[index] != 0 && id == 0 { blockCount -= 1 }
            blockIDs[index] = id
            metadata[index] = data
            revision &+= 1
        }
    }

    public static func index(x: Int, y: Int, z: Int) -> Int { x << 11 | z << 7 | y }

    mutating func setBlockEntity(_ entity: BlockEntity?, at position: BlockPosition) {
        guard blockEntities[position] != entity else { return }
        blockEntities[position] = entity
        revision &+= 1
    }

    public mutating func setClimate(temperature: Double, humidity: Double, x: Int, z: Int) {
        temperatures[x * 16 + z] = temperature
        humidities[x * 16 + z] = humidity
    }

    public func highestSolidY(x: Int, z: Int) -> Int? {
        for y in (0..<128).reversed() {
            if self[x, y, z]?.kind.isSolid == true { return y }
        }
        return nil
    }
}
