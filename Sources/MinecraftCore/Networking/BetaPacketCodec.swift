import Foundation

/// Frames the unlength-prefixed TCP packet stream used by protocol 14.
public struct BetaPacketCodec: Sendable {
    public static let protocolVersion: Int32 = 14
    private var buffer: [UInt8] = []
    private let maximumBufferedBytes: Int

    public init(maximumBufferedBytes: Int = 64 * 1024 * 1024) {
        self.maximumBufferedBytes = maximumBufferedBytes
    }

    public mutating func reset() { buffer.removeAll(keepingCapacity: true) }

    public mutating func append(_ data: Data) throws -> [BetaPacket] {
        guard data.count <= maximumBufferedBytes - buffer.count else {
            throw BetaProtocolError.invalid("Incoming Beta packet exceeds the buffer limit")
        }
        buffer.append(contentsOf: data)
        var packets: [BetaPacket] = []
        var consumed = 0
        while consumed < buffer.count {
            var reader = BetaWireReader(bytes: buffer, offset: consumed)
            do {
                packets.append(try Self.decode(&reader))
                consumed = reader.offset
            } catch BetaWireIncomplete.moreBytes {
                break
            }
        }
        if consumed > 0 { buffer.removeFirst(consumed) }
        return packets
    }

    public static func encode(_ packet: BetaPacket) throws -> Data {
        var w = BetaWireWriter()
        w.number(packet.id)
        switch packet {
        case .keepAlive: break
        case .login(let id, let name, let seed, let dimension):
            w.number(id)
            try w.string(name, maximum: 16)
            w.number(seed)
            w.number(dimension)
        case .handshake(let text): try w.string(text, maximum: 32)
        case .chat(let text): try w.string(text, maximum: 119)
        case .time(let time): w.number(time)
        case .equipment(let entity, let slot, let item, let damage):
            w.number(entity)
            w.number(slot)
            w.number(item)
            w.number(damage)
        case .spawnPosition(let position): try w.position(position, y: .int32)
        case .useEntity(let user, let target, let attack):
            w.number(user)
            w.number(target)
            w.boolean(attack)
        case .health(let health): w.number(health)
        case .respawn(let dimension): w.number(dimension)
        case .grounded(let grounded): w.boolean(grounded)
        case .playerPosition(let x, let y, let stance, let z, let grounded):
            w.double(x)
            w.double(y)
            w.double(stance)
            w.double(z)
            w.boolean(grounded)
        case .playerLook(let yaw, let pitch, let grounded):
            w.float(yaw)
            w.float(pitch)
            w.boolean(grounded)
        case .playerPositionLook(let x, let y, let stance, let z, let yaw, let pitch, let grounded):
            w.double(x)
            w.double(y)
            w.double(stance)
            w.double(z)
            w.float(yaw)
            w.float(pitch)
            w.boolean(grounded)
        case .dig(let status, let position, let face):
            w.number(status)
            try w.position(position, y: .unsignedByte)
            w.number(face)
        case .place(let position, let face, let item):
            try w.position(position, y: .unsignedByte)
            w.number(face)
            w.slot(item)
        case .heldItem(let slot): w.number(slot)
        case .sleep(let entity, let mode, let position):
            w.number(entity)
            w.number(mode)
            try w.position(position, y: .signedByte)
        case .animation(let entity, let animation):
            w.number(entity)
            w.number(animation)
        case .entityAction(let entity, let action):
            w.number(entity)
            w.number(action)
        case .namedEntitySpawn(let entity, let name, let position, let yaw, let pitch, let item):
            w.number(entity)
            try w.string(name, maximum: 16)
            w.vector(position)
            w.number(yaw)
            w.number(pitch)
            w.number(item)
        case .pickupSpawn(let entity, let item, let position, let velocity):
            w.number(entity)
            w.requiredSlot(item)
            w.vector(position)
            w.vector(velocity)
        case .collect(let item, let collector):
            w.number(item)
            w.number(collector)
        case .objectSpawn(let entity, let type, let position, let data, let velocity):
            w.number(entity)
            w.number(type)
            w.vector(position)
            w.number(data)
            if data > 0 { w.vector(velocity ?? .zero) }
        case .mobSpawn(let entity, let type, let position, let yaw, let pitch, let metadata):
            w.number(entity)
            w.number(type)
            w.vector(position)
            w.number(yaw)
            w.number(pitch)
            try w.metadata(metadata)
        case .painting(let entity, let title, let position, let direction):
            w.number(entity)
            try w.string(title, maximum: 13)
            try w.position(position, y: .int32)
            w.number(direction)
        case .vehicleInput(let strafe, let forward, let lookX, let lookY, let jump, let sneak):
            w.float(strafe)
            w.float(forward)
            w.float(lookX)
            w.float(lookY)
            w.boolean(jump)
            w.boolean(sneak)
        case .entityVelocity(let entity, let velocity):
            w.number(entity)
            w.vector(velocity)
        case .destroyEntity(let entity), .entity(let entity): w.number(entity)
        case .relativeMove(let entity, let delta):
            w.number(entity)
            w.vector(delta)
        case .entityLook(let entity, let yaw, let pitch):
            w.number(entity)
            w.number(yaw)
            w.number(pitch)
        case .relativeMoveLook(let entity, let delta, let yaw, let pitch):
            w.number(entity)
            w.vector(delta)
            w.number(yaw)
            w.number(pitch)
        case .teleport(let entity, let position, let yaw, let pitch):
            w.number(entity)
            w.vector(position)
            w.number(yaw)
            w.number(pitch)
        case .entityStatus(let entity, let status):
            w.number(entity)
            w.number(status)
        case .attachEntity(let entity, let vehicle):
            w.number(entity)
            w.number(vehicle)
        case .metadata(let entity, let values):
            w.number(entity)
            try w.metadata(values)
        case .preChunk(let x, let z, let load):
            w.number(x)
            w.number(z)
            w.boolean(load)
        case .mapChunk(let chunk):
            let compressed = try NBTCompression.zlib.compress(Data(chunk.data))
            w.number(chunk.x)
            w.number(chunk.y)
            w.number(chunk.z)
            w.number(UInt8(chunk.sizeX - 1))
            w.number(UInt8(chunk.sizeY - 1))
            w.number(UInt8(chunk.sizeZ - 1))
            w.number(Int32(compressed.count))
            w.bytes.append(contentsOf: compressed)
        case .multiBlockChange(let x, let z, let changes):
            guard changes.count <= Int(UInt16.max) else {
                throw BetaProtocolError.invalid("Too many block changes")
            }
            w.number(x)
            w.number(z)
            w.number(UInt16(changes.count))
            for change in changes { w.number(change.coordinate) }
            for change in changes { w.number(change.id) }
            for change in changes { w.number(change.metadata) }
        case .blockChange(let position, let id, let metadata):
            try w.position(position, y: .unsignedByte)
            w.number(id)
            w.number(metadata)
        case .blockAction(let position, let instrument, let pitch):
            try w.position(position, y: .short)
            w.number(instrument)
            w.number(pitch)
        case .explosion(let position, let power, let blocks):
            guard blocks.count <= 1_000_000 else {
                throw BetaProtocolError.invalid("Too many explosion blocks")
            }
            w.double(position.x)
            w.double(position.y)
            w.double(position.z)
            w.float(power)
            w.number(Int32(blocks.count))
            for block in blocks { w.vector(block) }
        case .soundEffect(let effect, let position, let data):
            w.number(effect)
            try w.position(position, y: .signedByte)
            w.number(data)
        case .gameState(let reason): w.number(reason)
        case .weatherEntity(let entity, let type, let position):
            w.number(entity)
            w.number(type)
            w.vector(position)
        case .openWindow(let id, let type, let title, let slots):
            w.number(id)
            w.number(type)
            try w.modifiedUTF(title)
            w.number(slots)
        case .closeWindow(let id): w.number(id)
        case .windowClick(let window, let slot, let button, let transaction, let shift, let item):
            w.number(window)
            w.number(slot)
            w.number(button)
            w.number(transaction)
            w.boolean(shift)
            w.slot(item)
        case .setSlot(let window, let slot, let item):
            w.number(window)
            w.number(slot)
            w.slot(item)
        case .windowItems(let window, let items):
            guard items.count <= Int(Int16.max) else {
                throw BetaProtocolError.invalid("Too many inventory slots")
            }
            w.number(window)
            w.number(Int16(items.count))
            for item in items { w.slot(item) }
        case .windowProperty(let window, let property, let value):
            w.number(window)
            w.number(property)
            w.number(value)
        case .transaction(let window, let id, let accepted):
            w.number(window)
            w.number(id)
            w.boolean(accepted)
        case .updateSign(let position, let lines):
            guard lines.count == 4 else { throw BetaProtocolError.invalid("Signs need exactly four lines") }
            try w.position(position, y: .short)
            for line in lines { try w.string(line, maximum: 15) }
        case .mapData(let item, let map, let bytes):
            guard bytes.count <= 255 else { throw BetaProtocolError.invalid("Map update exceeds 255 bytes") }
            w.number(item)
            w.number(map)
            w.number(UInt8(bytes.count))
            w.bytes.append(contentsOf: bytes)
        case .statistic(let id, let amount):
            w.number(id)
            w.number(amount)
        case .disconnect(let reason): try w.string(reason, maximum: 100)
        }
        return Data(w.bytes)
    }

    private static func decode(_ r: inout BetaWireReader) throws -> BetaPacket {
        let id: UInt8 = try r.number()
        switch id {
        case 0: return .keepAlive
        case 1:
            return try .login(
                entityIDOrProtocol: r.number(), username: r.string(maximum: 16), seed: r.number(),
                dimension: r.number())
        case 2: return try .handshake(r.string(maximum: 32))
        case 3: return try .chat(r.string(maximum: 119))
        case 4: return try .time(r.number())
        case 5:
            return try .equipment(
                entityID: r.number(), slot: r.number(), itemID: r.number(), damage: r.number())
        case 6: return try .spawnPosition(r.position(y: .int32))
        case 7: return try .useEntity(user: r.number(), target: r.number(), attack: r.boolean())
        case 8: return try .health(r.number())
        case 9: return try .respawn(r.number())
        case 10: return try .grounded(r.boolean())
        case 11:
            return try .playerPosition(
                x: r.double(), y: r.double(), stance: r.double(), z: r.double(), onGround: r.boolean())
        case 12: return try .playerLook(yaw: r.float(), pitch: r.float(), onGround: r.boolean())
        case 13:
            return try .playerPositionLook(
                x: r.double(), y: r.double(), stance: r.double(), z: r.double(), yaw: r.float(),
                pitch: r.float(), onGround: r.boolean())
        case 14: return try .dig(status: r.number(), position: r.position(y: .unsignedByte), face: r.number())
        case 15: return try .place(position: r.position(y: .unsignedByte), face: r.number(), item: r.slot())
        case 16: return try .heldItem(r.number())
        case 17:
            return try .sleep(entityID: r.number(), mode: r.number(), position: r.position(y: .signedByte))
        case 18: return try .animation(entityID: r.number(), animation: r.number())
        case 19: return try .entityAction(entityID: r.number(), action: r.number())
        case 20:
            return try .namedEntitySpawn(
                entityID: r.number(), username: r.string(maximum: 16), position: r.vector(), yaw: r.number(),
                pitch: r.number(), item: r.number())
        case 21:
            return try .pickupSpawn(
                entityID: r.number(), item: r.requiredSlot(), position: r.vector(), velocity: r.vector())
        case 22: return try .collect(itemEntityID: r.number(), collectorID: r.number())
        case 23:
            let entity: Int32 = try r.number()
            let type: Int8 = try r.number()
            let position: SIMD3<Int32> = try r.vector()
            let data: Int32 = try r.number()
            return .objectSpawn(
                entityID: entity, type: type, position: position, data: data,
                velocity: data > 0 ? try r.vector() : nil)
        case 24:
            return try .mobSpawn(
                entityID: r.number(), type: r.number(), position: r.vector(), yaw: r.number(),
                pitch: r.number(), metadata: r.metadata())
        case 25:
            return try .painting(
                entityID: r.number(), title: r.string(maximum: 13), position: r.position(y: .int32),
                direction: r.number())
        case 27:
            return try .vehicleInput(
                strafe: r.float(), forward: r.float(), lookX: r.float(), lookY: r.float(), jump: r.boolean(),
                sneak: r.boolean())
        case 28: return try .entityVelocity(entityID: r.number(), velocity: r.vector())
        case 29: return try .destroyEntity(r.number())
        case 30: return try .entity(r.number())
        case 31: return try .relativeMove(entityID: r.number(), delta: r.vector())
        case 32: return try .entityLook(entityID: r.number(), yaw: r.number(), pitch: r.number())
        case 33:
            return try .relativeMoveLook(
                entityID: r.number(), delta: r.vector(), yaw: r.number(), pitch: r.number())
        case 34:
            return try .teleport(
                entityID: r.number(), position: r.vector(), yaw: r.number(), pitch: r.number())
        case 38: return try .entityStatus(entityID: r.number(), status: r.number())
        case 39: return try .attachEntity(entityID: r.number(), vehicleID: r.number())
        case 40: return try .metadata(entityID: r.number(), values: r.metadata())
        case 50: return try .preChunk(x: r.number(), z: r.number(), load: r.boolean())
        case 51:
            let x: Int32 = try r.number()
            let y: Int16 = try r.number()
            let z: Int32 = try r.number()
            let sizeX = Int(try r.byte()) + 1
            let sizeY = Int(try r.byte()) + 1
            let sizeZ = Int(try r.byte()) + 1
            let count: Int32 = try r.number()
            guard (0...64 * 1024 * 1024).contains(count) else {
                throw BetaProtocolError.invalid("Invalid compressed chunk length")
            }
            let compressed = try r.readBytes(Int(count))
            let data: Data
            do { data = try NBTCompression.zlib.decompress(Data(compressed)) } catch {
                throw BetaProtocolError.compressedData
            }
            return try .mapChunk(
                BetaMapChunk(x: x, y: y, z: z, sizeX: sizeX, sizeY: sizeY, sizeZ: sizeZ, data: Array(data)))
        case 52:
            let x: Int32 = try r.number()
            let z: Int32 = try r.number()
            let count: UInt16 = try r.number()
            var coordinates: [UInt16] = []
            for _ in 0..<count { coordinates.append(try r.number()) }
            let ids = try r.readBytes(Int(count))
            let metadata = try r.readBytes(Int(count))
            return .multiBlockChange(
                chunkX: x, chunkZ: z,
                changes: coordinates.indices.map {
                    BetaLocalBlockChange(coordinate: coordinates[$0], id: ids[$0], metadata: metadata[$0])
                })
        case 53:
            return try .blockChange(
                position: r.position(y: .unsignedByte), id: r.number(), metadata: r.number())
        case 54:
            return try .blockAction(
                position: r.position(y: .short), instrument: r.number(), pitch: r.number())
        case 60:
            let position = try SIMD3<Double>(r.double(), r.double(), r.double())
            let power = try r.float()
            let count: Int32 = try r.number()
            guard (0...1_000_000).contains(count) else {
                throw BetaProtocolError.invalid("Invalid explosion block count")
            }
            var blocks: [SIMD3<Int8>] = []
            for _ in 0..<count { blocks.append(try r.vector()) }
            return .explosion(position: position, power: power, blocks: blocks)
        case 61:
            return try .soundEffect(
                effect: r.number(), position: r.position(y: .signedByte), data: r.number())
        case 70: return try .gameState(r.number())
        case 71: return try .weatherEntity(entityID: r.number(), type: r.number(), position: r.vector())
        case 100:
            return try .openWindow(
                id: r.number(), type: r.number(), title: r.modifiedUTF(), slots: r.number())
        case 101: return try .closeWindow(r.number())
        case 102:
            return try .windowClick(
                window: r.number(), slot: r.number(), button: r.number(), transaction: r.number(),
                shift: r.boolean(), item: r.slot())
        case 103: return try .setSlot(window: r.number(), slot: r.number(), item: r.slot())
        case 104:
            let window: Int8 = try r.number()
            let count: Int16 = try r.number()
            guard count >= 0 else { throw BetaProtocolError.invalid("Negative inventory slot count") }
            var items: [BetaSlot?] = []
            for _ in 0..<count { items.append(try r.slot()) }
            return .windowItems(window: window, items: items)
        case 105: return try .windowProperty(window: r.number(), property: r.number(), value: r.number())
        case 106: return try .transaction(window: r.number(), id: r.number(), accepted: r.boolean())
        case 130:
            let position = try r.position(y: .short)
            var lines: [String] = []
            for _ in 0..<4 { lines.append(try r.string(maximum: 15)) }
            return .updateSign(position: position, lines: lines)
        case 131:
            let item: Int16 = try r.number()
            let map: Int16 = try r.number()
            let count: UInt8 = try r.number()
            return try .mapData(itemID: item, mapID: map, bytes: r.readBytes(Int(count)))
        case 200: return try .statistic(id: r.number(), amount: r.number())
        case 255: return try .disconnect(r.string(maximum: 100))
        default: throw BetaProtocolError.unknownPacket(id)
        }
    }
}

private enum BetaWireIncomplete: Error { case moreBytes }
private enum BetaWireY { case int32, short, unsignedByte, signedByte }

private struct BetaWireReader {
    let bytes: [UInt8]
    var offset: Int

    mutating func number<T: FixedWidthInteger>() throws -> T {
        let size = MemoryLayout<T>.size
        guard bytes.count - offset >= size else { throw BetaWireIncomplete.moreBytes }
        var value: T.Magnitude = 0
        for byte in bytes[offset..<offset + size] { value = value << 8 | T.Magnitude(byte) }
        offset += size
        return T(truncatingIfNeeded: value)
    }

    mutating func byte() throws -> UInt8 { try number() }
    mutating func boolean() throws -> Bool { try byte() != 0 }
    mutating func float() throws -> Float { try Float(bitPattern: number()) }
    mutating func double() throws -> Double { try Double(bitPattern: number()) }

    mutating func vector<T: FixedWidthInteger & SIMDScalar>() throws -> SIMD3<T> {
        try SIMD3(number(), number(), number())
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard count >= 0 else { throw BetaProtocolError.invalid("Negative byte count") }
        guard bytes.count - offset >= count else { throw BetaWireIncomplete.moreBytes }
        let result = Array(bytes[offset..<offset + count])
        offset += count
        return result
    }

    mutating func string(maximum: Int) throws -> String {
        let count: Int16 = try number()
        guard count >= 0, count <= maximum else {
            throw BetaProtocolError.invalid("Invalid Java string length")
        }
        guard bytes.count - offset >= Int(count) * 2 else { throw BetaWireIncomplete.moreBytes }
        var units: [UInt16] = []
        for _ in 0..<count { units.append(try number()) }
        return String(decoding: units, as: UTF16.self)
    }

    mutating func modifiedUTF() throws -> String {
        let count: UInt16 = try number()
        let data = try readBytes(Int(count))
        var units: [UInt16] = []
        var index = 0
        while index < data.count {
            let first = data[index]
            index += 1
            if first & 0x80 == 0 {
                units.append(UInt16(first))
                continue
            }
            if first & 0xE0 == 0xC0, index < data.count, data[index] & 0xC0 == 0x80 {
                units.append(UInt16(first & 31) << 6 | UInt16(data[index] & 63))
                index += 1
            } else if first & 0xF0 == 0xE0, index + 1 < data.count,
                data[index] & 0xC0 == 0x80, data[index + 1] & 0xC0 == 0x80
            {
                units.append(
                    UInt16(first & 15) << 12 | UInt16(data[index] & 63) << 6 | UInt16(data[index + 1] & 63))
                index += 2
            } else {
                throw BetaProtocolError.invalid("Invalid Java modified UTF-8")
            }
        }
        return String(decoding: units, as: UTF16.self)
    }

    mutating func slot() throws -> BetaSlot? {
        let id: Int16 = try number()
        return id < 0 ? nil : try BetaSlot(itemID: id, count: number(), damage: number())
    }

    mutating func requiredSlot() throws -> BetaSlot {
        try BetaSlot(itemID: number(), count: number(), damage: number())
    }

    mutating func position(y: BetaWireY) throws -> BlockPosition {
        let x: Int32 = try number()
        let height: Int
        switch y {
        case .int32:
            let value: Int32 = try number()
            height = Int(value)
        case .short:
            let value: Int16 = try number()
            height = Int(value)
        case .unsignedByte: height = Int(try byte())
        case .signedByte:
            let value: Int8 = try number()
            height = Int(value)
        }
        let z: Int32 = try number()
        return BlockPosition(Int(x), height, Int(z))
    }

    mutating func metadata() throws -> [BetaMetadataEntry] {
        var entries: [BetaMetadataEntry] = []
        while true {
            let header = try byte()
            if header == 127 { return entries }
            guard entries.count < 32 else {
                throw BetaProtocolError.invalid("Too many entity metadata entries")
            }
            let value: BetaMetadataValue
            switch header >> 5 {
            case 0: value = try .byte(number())
            case 1: value = try .short(number())
            case 2: value = try .int(number())
            case 3: value = try .float(float())
            case 4: value = try .string(string(maximum: 64))
            case 5: value = try .item(requiredSlot())
            case 6: value = try .position(vector())
            default: throw BetaProtocolError.invalid("Invalid entity metadata type")
            }
            entries.append(BetaMetadataEntry(index: header & 31, value: value))
        }
    }
}

private struct BetaWireWriter {
    var bytes: [UInt8] = []

    mutating func number<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { bytes.append(contentsOf: $0) }
    }

    mutating func boolean(_ value: Bool) { number(UInt8(value ? 1 : 0)) }
    mutating func float(_ value: Float) { number(value.bitPattern) }
    mutating func double(_ value: Double) { number(value.bitPattern) }

    mutating func vector<T: FixedWidthInteger & SIMDScalar>(_ value: SIMD3<T>) {
        number(value.x)
        number(value.y)
        number(value.z)
    }

    mutating func string(_ value: String, maximum: Int) throws {
        let units = Array(value.utf16)
        guard units.count <= min(maximum, Int(Int16.max)) else {
            throw BetaProtocolError.invalid("Java string is too long")
        }
        number(Int16(units.count))
        for unit in units { number(unit) }
    }

    mutating func modifiedUTF(_ value: String) throws {
        var encoded: [UInt8] = []
        for unit in value.utf16 {
            if (1...127).contains(unit) {
                encoded.append(UInt8(unit))
            } else if unit <= 2047 {
                encoded += [UInt8(0xC0 | unit >> 6), UInt8(0x80 | unit & 63)]
            } else {
                encoded += [UInt8(0xE0 | unit >> 12), UInt8(0x80 | unit >> 6 & 63), UInt8(0x80 | unit & 63)]
            }
        }
        guard encoded.count <= Int(UInt16.max) else {
            throw BetaProtocolError.invalid("Modified UTF-8 title is too long")
        }
        number(UInt16(encoded.count))
        bytes += encoded
    }

    mutating func slot(_ value: BetaSlot?) {
        if let value { requiredSlot(value) } else { number(Int16(-1)) }
    }

    mutating func requiredSlot(_ value: BetaSlot) {
        number(value.itemID)
        number(value.count)
        number(value.damage)
    }

    mutating func position(_ value: BlockPosition, y: BetaWireY) throws {
        guard let x = Int32(exactly: value.x), let z = Int32(exactly: value.z) else {
            throw BetaProtocolError.invalid("Block position exceeds protocol coordinates")
        }
        number(x)
        switch y {
        case .int32:
            guard let y = Int32(exactly: value.y) else {
                throw BetaProtocolError.invalid("Invalid Y coordinate")
            }
            number(y)
        case .short:
            guard let y = Int16(exactly: value.y) else {
                throw BetaProtocolError.invalid("Invalid Y coordinate")
            }
            number(y)
        case .unsignedByte:
            guard let y = UInt8(exactly: value.y) else {
                throw BetaProtocolError.invalid("Invalid Y coordinate")
            }
            number(y)
        case .signedByte:
            guard let y = Int8(exactly: value.y) else {
                throw BetaProtocolError.invalid("Invalid Y coordinate")
            }
            number(y)
        }
        number(z)
    }

    mutating func metadata(_ entries: [BetaMetadataEntry]) throws {
        guard entries.count <= 32 else { throw BetaProtocolError.invalid("Too many entity metadata entries") }
        for entry in entries {
            guard entry.index <= 31 else { throw BetaProtocolError.invalid("Invalid entity metadata index") }
            let type: UInt8
            switch entry.value {
            case .byte: type = 0
            case .short: type = 1
            case .int: type = 2
            case .float: type = 3
            case .string: type = 4
            case .item: type = 5
            case .position: type = 6
            }
            let header = type << 5 | entry.index
            guard header != 127 else {
                throw BetaProtocolError.invalid("Metadata header collides with terminator")
            }
            number(header)
            switch entry.value {
            case .byte(let value): number(value)
            case .short(let value): number(value)
            case .int(let value): number(value)
            case .float(let value): float(value)
            case .string(let value): try string(value, maximum: 64)
            case .item(let value): requiredSlot(value)
            case .position(let value): vector(value)
            }
        }
        number(UInt8(127))
    }
}
