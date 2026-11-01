import Foundation

enum BlockEntityNBT {
    static func decode(_ entries: [NBTTag], chunk: ChunkPosition) -> [BlockPosition: BlockEntity] {
        var result: [BlockPosition: BlockEntity] = [:]
        for entry in entries {
            guard let fields = entry.compoundValue, let position = position(fields), position.chunk == chunk,
                let entity = decode(fields)
            else { continue }
            result[position] = entity
        }
        return result
    }

    static func encode(_ entities: [BlockPosition: BlockEntity], previous: [NBTTag]) -> NBTTag {
        var old: [BlockPosition: [String: NBTTag]] = [:]
        var entries: [NBTTag] = []
        for entry in previous {
            guard let fields = entry.compoundValue, let position = position(fields) else {
                entries.append(entry)
                continue
            }
            old[position] = fields
            if decode(fields) == nil && entities[position] == nil { entries.append(entry) }
        }
        for position in entities.keys.sorted(by: {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }) {
            guard let entity = entities[position] else { continue }
            var fields = encode(entity, previous: old[position] ?? [:])
            fields["x"] = .int(Int32(clamping: position.x))
            fields["y"] = .int(Int32(clamping: position.y))
            fields["z"] = .int(Int32(clamping: position.z))
            entries.append(.compound(fields))
        }
        return .list(entries.isEmpty ? .byte : .compound, entries)
    }

    private static func position(_ fields: [String: NBTTag]) -> BlockPosition? {
        guard let x = fields["x"]?.integerValue, let y = fields["y"]?.integerValue,
            let z = fields["z"]?.integerValue
        else { return nil }
        return BlockPosition(Int(x), Int(y), Int(z))
    }

    private static func decode(_ fields: [String: NBTTag]) -> BlockEntity? {
        let items = fields["Items"]?.listValue ?? []
        switch fields["id"]?.stringValue {
        case "Chest": return .chest(slots: InventoryNBT.decode(items, slotCount: 27))
        case "Trap": return .dispenser(slots: InventoryNBT.decode(items, slotCount: 9))
        case "Furnace":
            let slots = InventoryNBT.decode(items, slotCount: 3)
            return .furnace(
                FurnaceState(
                    input: slots[0], fuel: slots[1], output: slots[2],
                    burnTicksRemaining: Int(fields["BurnTime"]?.integerValue ?? 0),
                    cookTicks: Int(fields["CookTime"]?.integerValue ?? 0)))
        case "Sign": return .sign(lines: (1...4).map { fields["Text\($0)"]?.stringValue ?? "" })
        case "MobSpawner":
            return .spawner(
                mobID: fields["EntityId"]?.stringValue ?? "Pig",
                delay: Int(fields["Delay"]?.integerValue ?? 20))
        case "Music": return .note(pitch: UInt8(clamping: min(24, fields["note"]?.integerValue ?? 0)))
        case "RecordPlayer":
            let id = fields["Record"]?.integerValue ?? 0
            return .jukebox(record: id > 0 ? UInt16(truncatingIfNeeded: id) : nil)
        case "Piston":
            let id = UInt8(truncatingIfNeeded: fields["blockId"]?.integerValue ?? 0)
            guard let kind = BlockKind(rawValue: id) else { return nil }
            return .piston(
                PistonState(
                    block: BlockState(
                        kind, metadata: UInt8(truncatingIfNeeded: fields["blockData"]?.integerValue ?? 0)),
                    facing: UInt8(truncatingIfNeeded: fields["facing"]?.integerValue ?? 0),
                    extending: (fields["extending"]?.integerValue ?? 0) != 0,
                    isSource: false, progress: Float(fields["progress"]?.doubleValue ?? 0)))
        default: return nil
        }
    }

    private static func encode(_ entity: BlockEntity, previous: [String: NBTTag]) -> [String: NBTTag] {
        var fields = previous
        switch entity {
        case .chest(let slots):
            fields["id"] = .string("Chest")
            fields["Items"] = InventoryNBT.encode(slots, previous: fields["Items"]?.listValue ?? [])
        case .dispenser(let slots):
            fields["id"] = .string("Trap")
            fields["Items"] = InventoryNBT.encode(slots, previous: fields["Items"]?.listValue ?? [])
        case .furnace(let state):
            fields["id"] = .string("Furnace")
            fields["Items"] = InventoryNBT.encode(
                [state.input, state.fuel, state.output],
                previous: fields["Items"]?.listValue ?? [])
            fields["BurnTime"] = .short(Int16(clamping: state.burnTicksRemaining))
            fields["CookTime"] = .short(Int16(clamping: state.cookTicks))
        case .sign(let lines):
            fields["id"] = .string("Sign")
            for index in 0..<4 {
                fields["Text\(index + 1)"] = .string(lines.indices.contains(index) ? lines[index] : "")
            }
        case .spawner(let mobID, let delay):
            fields["id"] = .string("MobSpawner")
            fields["EntityId"] = .string(mobID)
            fields["Delay"] = .short(Int16(clamping: delay))
        case .note(let pitch):
            fields["id"] = .string("Music")
            fields["note"] = .byte(Int8(clamping: min(24, pitch)))
        case .jukebox(let record):
            fields["id"] = .string("RecordPlayer")
            fields["Record"] = record.map { .int(Int32($0)) }
        case .piston(let state):
            fields["id"] = .string("Piston")
            fields["blockId"] = .int(Int32(state.block.kind.rawValue))
            fields["blockData"] = .int(Int32(state.block.metadata))
            fields["facing"] = .int(Int32(state.facing))
            fields["progress"] = .float(state.previousProgress)
            fields["extending"] = .byte(state.extending ? 1 : 0)
        }
        return fields
    }
}
