import Foundation

public struct SavedPlayer: Sendable {
    /// Feet coordinates; yaw and pitch use the camera's radians convention.
    public var position: SIMD3<Double>
    public var velocity: SIMD3<Double>
    public var yaw: Float
    public var pitch: Float
    public var health: Int
    public var inventory: PlayerInventory
    public var dimension: Int8
    public var bedSpawn: BlockPosition?

    public init(
        position: SIMD3<Double>, velocity: SIMD3<Double>, yaw: Float, pitch: Float,
        health: Int, inventory: PlayerInventory, dimension: Int8 = 0, bedSpawn: BlockPosition? = nil
    ) {
        self.position = position
        self.velocity = velocity
        self.yaw = yaw
        self.pitch = pitch
        self.health = health
        self.inventory = inventory
        self.dimension = dimension
        self.bedSpawn = bedSpawn
    }
}

public struct SavedLevel: Sendable {
    public var seed: Int64
    public var time: Int64
    public var spawn: BlockPosition
    public var player: SavedPlayer
    public var name: String
    public var nextEntityID: Int64
    public var weather: WorldWeather

    public init(
        seed: Int64, time: Int64, spawn: BlockPosition, player: SavedPlayer, name: String = "World",
        nextEntityID: Int64 = 1, weather: WorldWeather? = nil
    ) {
        self.seed = seed
        self.time = time
        self.spawn = spawn
        self.player = player
        self.name = name
        self.nextEntityID = nextEntityID
        self.weather = weather ?? WorldWeather(seed: seed)
    }
}

/// A single-writer store for Beta's gzip level.dat and zlib-compressed McRegion chunks.
public final class WorldStorage {
    public let directory: URL
    public var dimension: Int8 {
        didSet { if oldValue != dimension { chunkDocuments.removeAll() } }
    }
    private var levelDocument: NBTDocument?
    private var levelSourceData: Data?
    private var chunkDocuments: [ChunkPosition: NBTDocument] = [:]
    private var nextEntityID: Int64 = 1

    public init(directory: URL, dimension: Int8 = 0) {
        self.directory = directory
        self.dimension = dimension
    }

    public func reserveEntityIDs(through id: Int64) {
        if id >= nextEntityID && id < Int64.max - 1 { nextEntityID = id + 1 }
    }

    public func loadLevel() throws -> SavedLevel? {
        var firstError: Error?
        for filename in ["level.dat", "level.dat_old"] {
            let url = directory.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let source = try Data(contentsOf: url)
                let document = try NBTCodec.decode(NBTCompression.gzip.decompress(source))
                guard let data = document.tag.compoundValue?["Data"]?.compoundValue else {
                    throw WorldStorageError.malformed("level.dat has no Data compound")
                }
                let spawn = BlockPosition(
                    Int(data["SpawnX"]?.integerValue ?? 0),
                    Int(data["SpawnY"]?.integerValue ?? 64), Int(data["SpawnZ"]?.integerValue ?? 0))
                let player = try decodePlayer(data["Player"]?.compoundValue ?? [:], spawn: spawn)
                levelDocument = document
                levelSourceData = source
                let counter = max(1, min(Int64.max - 1, data["SwiftNextEntityID"]?.integerValue ?? 1))
                nextEntityID = max(nextEntityID, counter)
                let seed = data["RandomSeed"]?.integerValue ?? 0
                return SavedLevel(
                    seed: seed, time: data["Time"]?.integerValue ?? 0,
                    spawn: spawn, player: player, name: data["LevelName"]?.stringValue ?? "World",
                    nextEntityID: counter,
                    weather: WorldWeather(
                        seed: seed,
                        raining: (data["raining"]?.integerValue ?? 0) != 0,
                        thundering: (data["thundering"]?.integerValue ?? 0) != 0,
                        rainTime: Int(data["rainTime"]?.integerValue ?? 0),
                        thunderTime: Int(data["thunderTime"]?.integerValue ?? 0)))
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
        return nil
    }

    public func saveLevel(_ level: SavedLevel) throws {
        if levelDocument == nil { _ = try loadLevel() }
        var root = levelDocument?.tag.compoundValue ?? [:]
        var data = root["Data"]?.compoundValue ?? [:]
        data["RandomSeed"] = .long(level.seed)
        data["Time"] = .long(level.time)
        data["SpawnX"] = .int(try coordinate(level.spawn.x))
        data["SpawnY"] = .int(try coordinate(level.spawn.y))
        data["SpawnZ"] = .int(try coordinate(level.spawn.z))
        data["LevelName"] = .string(level.name)
        data["version"] = .int(19132)
        data["SwiftNextEntityID"] = .long(max(nextEntityID, level.nextEntityID))
        data["LastPlayed"] = .long(Int64(Date().timeIntervalSince1970 * 1000))
        if data["SizeOnDisk"] == nil { data["SizeOnDisk"] = .long(0) }
        data["rainTime"] = .int(Int32(clamping: level.weather.rainTime))
        data["thunderTime"] = .int(Int32(clamping: level.weather.thunderTime))
        data["raining"] = .byte(level.weather.raining ? 1 : 0)
        data["thundering"] = .byte(level.weather.thundering ? 1 : 0)
        data["Player"] = .compound(
            try encodePlayer(level.player, previous: data["Player"]?.compoundValue ?? [:]))
        root["Data"] = .compound(data)
        let document = NBTDocument(name: levelDocument?.name ?? "", tag: .compound(root))
        let compressed = try NBTCompression.gzip.compress(NBTCodec.encode(document))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("level.dat")
        if let levelSourceData {
            try levelSourceData.write(to: directory.appendingPathComponent("level.dat_old"), options: .atomic)
        }
        try compressed.write(to: destination, options: .atomic)
        levelDocument = document
        levelSourceData = compressed
    }

    public func loadChunk(at position: ChunkPosition) throws -> Chunk? {
        guard var document = try region(at: position).readChunk(at: position) else { return nil }
        guard var root = document.tag.compoundValue, var level = root["Level"]?.compoundValue,
            let blocks = level["Blocks"]?.byteArrayValue, blocks.count == Chunk.volume
        else {
            throw WorldStorageError.malformed("chunk is missing its 32768 Blocks bytes")
        }
        let metadata = try unpackNibbles(level["Data"], field: "Data")
        let skyLight = try unpackNibbles(level["SkyLight"], field: "SkyLight")
        let blockLight = try unpackNibbles(level["BlockLight"], field: "BlockLight")
        var chunk = try Chunk(
            position: position, blockIDs: blocks, metadata: metadata,
            skyLight: skyLight, blockLight: blockLight)
        chunk.isTerrainPopulated = (level["TerrainPopulated"]?.integerValue ?? 0) != 0
        chunk.blockEntities = BlockEntityNBT.decode(level["TileEntities"]?.listValue ?? [], chunk: position)
        let decoded = EntityNBT.decode(level["Entities"]?.listValue ?? [], nextID: &nextEntityID)
        chunk.entities = decoded.entities
        level["Entities"] = .list(decoded.entries.isEmpty ? .byte : .compound, decoded.entries)
        root["Level"] = .compound(level)
        document.tag = .compound(root)
        chunkDocuments[position] = document
        return chunk
    }

    public func saveChunk(_ chunk: Chunk, worldTime: Int64) throws {
        if let maximumID = chunk.entities.map(\.id).max() { reserveEntityIDs(through: maximumID) }
        let region = region(at: chunk.position)
        let previous = try chunkDocuments[chunk.position] ?? region.readChunk(at: chunk.position)
        var root = previous?.tag.compoundValue ?? [:]
        var level = root["Level"]?.compoundValue ?? [:]
        let previousBlocks = level["Blocks"]?.byteArrayValue
        level["xPos"] = .int(try coordinate(chunk.position.x))
        level["zPos"] = .int(try coordinate(chunk.position.z))
        level["LastUpdate"] = .long(worldTime)
        level["Blocks"] = .byteArray(chunk.blockIDs)
        level["Data"] = .byteArray(try packNibbles(chunk.metadata))
        level["SkyLight"] = .byteArray(try packNibbles(chunk.skyLight))
        level["BlockLight"] = .byteArray(try packNibbles(chunk.blockLight))
        level["TerrainPopulated"] = .byte(chunk.isTerrainPopulated ? 1 : 0)
        if previousBlocks != chunk.blockIDs || level["HeightMap"]?.byteArrayValue?.count != 256 {
            level["HeightMap"] = .byteArray(heightMap(chunk))
        }
        level["Entities"] = EntityNBT.encode(chunk.entities, previous: level["Entities"]?.listValue ?? [])
        level["TileEntities"] = BlockEntityNBT.encode(
            chunk.blockEntities,
            previous: level["TileEntities"]?.listValue ?? [])
        root["Level"] = .compound(level)
        let document = NBTDocument(name: previous?.name ?? "", tag: .compound(root))
        try region.writeChunk(document, at: chunk.position)
        chunkDocuments[chunk.position] = nil
    }

    private func region(at position: ChunkPosition) -> McRegionFile {
        let dimensionDirectory = dimension == -1 ? directory.appendingPathComponent("DIM-1") : directory
        return McRegionFile(
            url: dimensionDirectory.appendingPathComponent("region")
                .appendingPathComponent("r.\(position.x >> 5).\(position.z >> 5).mcr"))
    }

    private func decodePlayer(_ tags: [String: NBTTag], spawn: BlockPosition) throws -> SavedPlayer {
        let fallback = SIMD3(Double(spawn.x) + 0.5, Double(spawn.y), Double(spawn.z) + 0.5)
        let position =
            try vector(tags["Pos"], fallback: fallback + SIMD3(0, Self.eyeOffset, 0))
            - SIMD3(0, Self.eyeOffset, 0)
        var velocity = try vector(tags["Motion"], fallback: .zero)
        for axis in 0..<3 where abs(velocity[axis]) > 10 { velocity[axis] = 0 }
        let angles = tags["Rotation"]?.listValue?.compactMap(\.doubleValue) ?? [180, 0]
        guard angles.count == 2, angles.allSatisfy(\.isFinite) else {
            throw WorldStorageError.malformed("invalid player Rotation")
        }
        var inventory = PlayerInventory()
        let entries = tags["Inventory"]?.listValue ?? []
        inventory.slots = InventoryNBT.decode(entries, slotCount: 36)
        inventory.armor = InventoryNBT.decode(entries, slotCount: 4, offset: 100)
        inventory.selectedHotbar = min(8, max(0, Int(tags["SelectedItemSlot"]?.integerValue ?? 0)))
        let bedSpawn: BlockPosition?
        if let x = tags["SpawnX"]?.integerValue, let y = tags["SpawnY"]?.integerValue,
            let z = tags["SpawnZ"]?.integerValue
        {
            bedSpawn = BlockPosition(Int(x), Int(y), Int(z))
        } else {
            bedSpawn = nil
        }
        return SavedPlayer(
            position: position, velocity: velocity,
            yaw: Float((angles[0] - 180) * .pi / 180), pitch: Float(-angles[1] * .pi / 180),
            health: Int(tags["Health"]?.integerValue ?? 20), inventory: inventory,
            dimension: Int8(truncatingIfNeeded: tags["Dimension"]?.integerValue ?? 0), bedSpawn: bedSpawn)
    }

    private func encodePlayer(_ player: SavedPlayer, previous: [String: NBTTag]) throws -> [String: NBTTag] {
        var tags = previous
        tags["Pos"] = .list(
            .double,
            [player.position.x, player.position.y + Self.eyeOffset, player.position.z].map(NBTTag.double))
        tags["Motion"] = .list(
            .double, [player.velocity.x, player.velocity.y, player.velocity.z].map(NBTTag.double))
        tags["Rotation"] = .list(
            .float, [.float(player.yaw * 180 / .pi + 180), .float(-player.pitch * 180 / .pi)])
        tags["Health"] = .short(Int16(clamping: player.health))
        tags["Dimension"] = .int(Int32(player.dimension))
        tags["SpawnX"] = try player.bedSpawn.map { .int(try coordinate($0.x)) }
        tags["SpawnY"] = try player.bedSpawn.map { .int(try coordinate($0.y)) }
        tags["SpawnZ"] = try player.bedSpawn.map { .int(try coordinate($0.z)) }
        tags["Inventory"] = InventoryNBT.encodePlayer(
            player.inventory, previous: tags["Inventory"]?.listValue ?? [])
        tags["SelectedItemSlot"] = .int(Int32(clamping: player.inventory.selectedHotbar))
        let defaults: [String: NBTTag] = [
            "Air": .short(300), "Fire": .short(0), "FallDistance": .float(0),
            "OnGround": .byte(0),
        ]
        for (key, value) in defaults where tags[key] == nil { tags[key] = value }
        return tags
    }

    private static let eyeOffset = Double(Float(1.62))

    private func vector(_ tag: NBTTag?, fallback: SIMD3<Double>) throws -> SIMD3<Double> {
        guard let tag else { return fallback }
        guard let values = tag.listValue?.compactMap(\.doubleValue), values.count == 3,
            values.allSatisfy(\.isFinite)
        else { throw WorldStorageError.malformed("invalid entity vector") }
        return SIMD3(values[0], values[1], values[2])
    }

    private func coordinate(_ value: Int) throws -> Int32 {
        guard let result = Int32(exactly: value) else {
            throw WorldStorageError.malformed("coordinate exceeds signed 32-bit range")
        }
        return result
    }

    private func unpackNibbles(_ tag: NBTTag?, field: String) throws -> [UInt8] {
        guard let bytes = tag?.byteArrayValue, bytes.count == Chunk.volume / 2 else {
            throw WorldStorageError.malformed("invalid chunk \(field) nibble array")
        }
        return bytes.flatMap { [$0 & 15, $0 >> 4] }
    }

    private func packNibbles(_ values: [UInt8]) throws -> [UInt8] {
        guard values.count == Chunk.volume else {
            throw WorldStorageError.malformed("invalid chunk nibble-array length")
        }
        return stride(from: 0, to: values.count, by: 2).map { values[$0] & 15 | (values[$0 + 1] & 15) << 4 }
    }

    private func heightMap(_ chunk: Chunk) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 256)
        for x in 0..<16 {
            for z in 0..<16 {
                var y = 127
                while y > 0
                    && (BlockKind(rawValue: chunk.blockIDs[Chunk.index(x: x, y: y - 1, z: z)])?.lightOpacity
                        ?? 15) == 0
                {
                    y -= 1
                }
                result[z << 4 | x] = UInt8(y)
            }
        }
        return result
    }

}
