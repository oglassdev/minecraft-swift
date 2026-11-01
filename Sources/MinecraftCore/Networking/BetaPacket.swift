import Foundation

public struct BetaSlot: Sendable, Equatable {
    public var itemID: Int16
    public var count: Int8
    public var damage: Int16

    public init(itemID: Int16, count: Int8 = 1, damage: Int16 = 0) {
        self.itemID = itemID
        self.count = count
        self.damage = damage
    }

    public init(_ stack: ItemStack) {
        itemID = Int16(bitPattern: stack.id)
        count = Int8(clamping: stack.count)
        damage = Int16(bitPattern: stack.damage)
    }

    public var stack: ItemStack? {
        guard itemID >= 0, count > 0 else { return nil }
        return ItemStack(id: UInt16(itemID), count: Int(count), damage: UInt16(bitPattern: damage))
    }
}

public enum BetaMetadataValue: Sendable, Equatable {
    case byte(Int8)
    case short(Int16)
    case int(Int32)
    case float(Float)
    case string(String)
    case item(BetaSlot)
    case position(SIMD3<Int32>)
}

public struct BetaMetadataEntry: Sendable, Equatable {
    public var index: UInt8
    public var value: BetaMetadataValue

    public init(index: UInt8, value: BetaMetadataValue) {
        self.index = index
        self.value = value
    }
}

public struct BetaLocalBlockChange: Sendable, Equatable {
    public var coordinate: UInt16
    public var id: UInt8
    public var metadata: UInt8
    public var x: Int { Int(coordinate >> 12) }
    public var y: Int { Int(coordinate & 255) }
    public var z: Int { Int(coordinate >> 8 & 15) }

    public init(coordinate: UInt16, id: UInt8, metadata: UInt8) {
        self.coordinate = coordinate
        self.id = id
        self.metadata = metadata
    }
}

public struct BetaMapChunk: Sendable, Equatable {
    public let x: Int32
    public let y: Int16
    public let z: Int32
    public let sizeX: Int
    public let sizeY: Int
    public let sizeZ: Int
    /// Original uncompressed layout: block IDs, then packed metadata, block light, and sky light.
    public let data: [UInt8]

    public init(x: Int32, y: Int16, z: Int32, sizeX: Int, sizeY: Int, sizeZ: Int, data: [UInt8]) throws {
        guard [sizeX, sizeY, sizeZ].allSatisfy({ (1...256).contains($0) }),
            data.count == sizeX * sizeY * sizeZ * 5 / 2
        else {
            throw BetaProtocolError.invalid("Invalid map chunk dimensions or data length")
        }
        self.x = x
        self.y = y
        self.z = z
        self.sizeX = sizeX
        self.sizeY = sizeY
        self.sizeZ = sizeZ
        self.data = data
    }

    public func apply(to world: inout BlockWorld) {
        let startX = Int(x)
        let startY = Int(y)
        let startZ = Int(z)
        let volume = sizeX * sizeY * sizeZ
        let packedLength = volume / 2
        for chunkX in (startX >> 4)...((startX + sizeX - 1) >> 4) {
            for chunkZ in (startZ >> 4)...((startZ + sizeZ - 1) >> 4) {
                let position = ChunkPosition(chunkX, chunkZ)
                var chunk = world.chunks[position] ?? Chunk(position: position)
                if world.dimension == 0 && chunk.temperatures.allSatisfy({ $0 == 0.5 }) {
                    let samples = BetaClimateSource(seed: world.seed).region(x: chunkX * 16, z: chunkZ * 16)
                    for x in 0..<16 {
                        for z in 0..<16 {
                            let sample = samples[x * 16 + z]
                            chunk.setClimate(
                                temperature: sample.temperature, humidity: sample.humidity, x: x, z: z)
                        }
                    }
                }
                if world.dimension == -1 {
                    for x in 0..<16 {
                        for z in 0..<16 { chunk.setClimate(temperature: 1, humidity: 0, x: x, z: z) }
                    }
                }
                let xRange = max(startX, chunkX * 16)..<min(startX + sizeX, chunkX * 16 + 16)
                let zRange = max(startZ, chunkZ * 16)..<min(startZ + sizeZ, chunkZ * 16 + 16)
                let yRange = max(startY, 0)..<max(max(startY, 0), min(startY + sizeY, 128))
                for worldX in xRange {
                    for worldZ in zRange {
                        for worldY in yRange {
                            let index =
                                ((worldX - startX) * sizeZ + worldZ - startZ) * sizeY + worldY - startY
                            let id = data[index]
                            let metadata = nibble(at: index, base: volume)
                            let state = BlockKind(rawValue: id).map { BlockState($0, metadata: metadata) }
                            chunk[worldX & 15, worldY, worldZ & 15] = state
                            let dense = Chunk.index(x: worldX & 15, y: worldY, z: worldZ & 15)
                            chunk.blockLight[dense] = nibble(at: index, base: volume + packedLength)
                            chunk.skyLight[dense] = nibble(at: index, base: volume + packedLength * 2)
                        }
                    }
                }
                world.setChunk(chunk, updateLighting: false)
            }
        }
    }

    private func nibble(at index: Int, base: Int) -> UInt8 {
        let offset = base + index / 2
        guard data.indices.contains(offset) else { return 0 }
        return (data[offset] >> ((index & 1) * 4)) & 15
    }
}

/// The complete vanilla Beta 1.7.3 packet table, protocol 14. Fixed entity positions are in 1/32 blocks.
public enum BetaPacket: Sendable, Equatable {
    case keepAlive
    case login(entityIDOrProtocol: Int32, username: String, seed: Int64, dimension: Int8)
    case handshake(String)
    case chat(String)
    case time(Int64)
    case equipment(entityID: Int32, slot: Int16, itemID: Int16, damage: Int16)
    case spawnPosition(BlockPosition)
    case useEntity(user: Int32, target: Int32, attack: Bool)
    case health(Int16)
    case respawn(Int8)
    case grounded(Bool)
    case playerPosition(x: Double, y: Double, stance: Double, z: Double, onGround: Bool)
    case playerLook(yaw: Float, pitch: Float, onGround: Bool)
    case playerPositionLook(
        x: Double, y: Double, stance: Double, z: Double, yaw: Float, pitch: Float, onGround: Bool)
    case dig(status: UInt8, position: BlockPosition, face: UInt8)
    case place(position: BlockPosition, face: UInt8, item: BetaSlot?)
    case heldItem(Int16)
    case sleep(entityID: Int32, mode: Int8, position: BlockPosition)
    case animation(entityID: Int32, animation: Int8)
    case entityAction(entityID: Int32, action: Int8)
    case namedEntitySpawn(
        entityID: Int32, username: String, position: SIMD3<Int32>, yaw: UInt8, pitch: UInt8, item: Int16)
    case pickupSpawn(entityID: Int32, item: BetaSlot, position: SIMD3<Int32>, velocity: SIMD3<Int8>)
    case collect(itemEntityID: Int32, collectorID: Int32)
    case objectSpawn(
        entityID: Int32, type: Int8, position: SIMD3<Int32>, data: Int32, velocity: SIMD3<Int16>?)
    case mobSpawn(
        entityID: Int32, type: UInt8, position: SIMD3<Int32>, yaw: UInt8, pitch: UInt8,
        metadata: [BetaMetadataEntry])
    case painting(entityID: Int32, title: String, position: BlockPosition, direction: Int32)
    case vehicleInput(strafe: Float, forward: Float, lookX: Float, lookY: Float, jump: Bool, sneak: Bool)
    case entityVelocity(entityID: Int32, velocity: SIMD3<Int16>)
    case destroyEntity(Int32)
    case entity(Int32)
    case relativeMove(entityID: Int32, delta: SIMD3<Int8>)
    case entityLook(entityID: Int32, yaw: UInt8, pitch: UInt8)
    case relativeMoveLook(entityID: Int32, delta: SIMD3<Int8>, yaw: UInt8, pitch: UInt8)
    case teleport(entityID: Int32, position: SIMD3<Int32>, yaw: UInt8, pitch: UInt8)
    case entityStatus(entityID: Int32, status: Int8)
    case attachEntity(entityID: Int32, vehicleID: Int32)
    case metadata(entityID: Int32, values: [BetaMetadataEntry])
    case preChunk(x: Int32, z: Int32, load: Bool)
    case mapChunk(BetaMapChunk)
    case multiBlockChange(chunkX: Int32, chunkZ: Int32, changes: [BetaLocalBlockChange])
    case blockChange(position: BlockPosition, id: UInt8, metadata: UInt8)
    case blockAction(position: BlockPosition, instrument: UInt8, pitch: UInt8)
    case explosion(position: SIMD3<Double>, power: Float, blocks: [SIMD3<Int8>])
    case soundEffect(effect: Int32, position: BlockPosition, data: Int32)
    case gameState(Int8)
    case weatherEntity(entityID: Int32, type: Int8, position: SIMD3<Int32>)
    case openWindow(id: Int8, type: Int8, title: String, slots: Int8)
    case closeWindow(Int8)
    case windowClick(
        window: Int8, slot: Int16, button: Int8, transaction: Int16, shift: Bool, item: BetaSlot?)
    case setSlot(window: Int8, slot: Int16, item: BetaSlot?)
    case windowItems(window: Int8, items: [BetaSlot?])
    case windowProperty(window: Int8, property: Int16, value: Int16)
    case transaction(window: Int8, id: Int16, accepted: Bool)
    case updateSign(position: BlockPosition, lines: [String])
    case mapData(itemID: Int16, mapID: Int16, bytes: [UInt8])
    case statistic(id: Int32, amount: Int8)
    case disconnect(String)

    public var id: UInt8 {
        switch self {
        case .keepAlive: 0
        case .login: 1
        case .handshake: 2
        case .chat: 3
        case .time: 4
        case .equipment: 5
        case .spawnPosition: 6
        case .useEntity: 7
        case .health: 8
        case .respawn: 9
        case .grounded: 10
        case .playerPosition: 11
        case .playerLook: 12
        case .playerPositionLook: 13
        case .dig: 14
        case .place: 15
        case .heldItem: 16
        case .sleep: 17
        case .animation: 18
        case .entityAction: 19
        case .namedEntitySpawn: 20
        case .pickupSpawn: 21
        case .collect: 22
        case .objectSpawn: 23
        case .mobSpawn: 24
        case .painting: 25
        case .vehicleInput: 27
        case .entityVelocity: 28
        case .destroyEntity: 29
        case .entity: 30
        case .relativeMove: 31
        case .entityLook: 32
        case .relativeMoveLook: 33
        case .teleport: 34
        case .entityStatus: 38
        case .attachEntity: 39
        case .metadata: 40
        case .preChunk: 50
        case .mapChunk: 51
        case .multiBlockChange: 52
        case .blockChange: 53
        case .blockAction: 54
        case .explosion: 60
        case .soundEffect: 61
        case .gameState: 70
        case .weatherEntity: 71
        case .openWindow: 100
        case .closeWindow: 101
        case .windowClick: 102
        case .setSlot: 103
        case .windowItems: 104
        case .windowProperty: 105
        case .transaction: 106
        case .updateSign: 130
        case .mapData: 131
        case .statistic: 200
        case .disconnect: 255
        }
    }
}

public enum BetaProtocolError: Error, LocalizedError, Equatable {
    case unknownPacket(UInt8)
    case invalid(String)
    case compressedData

    public var errorDescription: String? {
        switch self {
        case .unknownPacket(let id): "Unknown Beta packet: \(id)"
        case .invalid(let message): message
        case .compressedData: "Invalid compressed map chunk"
        }
    }
}
