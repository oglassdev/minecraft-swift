import Foundation

enum EntityNBT {
    static func decode(_ entries: [NBTTag], nextID: inout Int64) -> (
        entities: [GameEntity], entries: [NBTTag]
    ) {
        var entities: [GameEntity] = []
        var retained: [NBTTag] = []
        for entry in entries {
            guard nextID > 0 && nextID < Int64.max else {
                retained.append(entry)
                continue
            }
            guard var fields = entry.compoundValue else {
                retained.append(entry)
                continue
            }
            let storedID = fields["SwiftEntityID"]?.integerValue
            let id = storedID.flatMap { $0 > 0 && $0 < Int64.max - 1 ? $0 : nil } ?? nextID
            guard let entity = decode(fields, id: id) else {
                retained.append(entry)
                continue
            }
            nextID = max(nextID, id + 1)
            fields["SwiftEntityID"] = .long(id)
            entities.append(entity)
            retained.append(.compound(fields))
        }
        return (entities, retained)
    }

    static func encode(_ entities: [GameEntity], previous: [NBTTag]) -> NBTTag {
        var old: [Int64: [String: NBTTag]] = [:]
        var entries: [NBTTag] = []
        for entry in previous {
            guard let fields = entry.compoundValue, decode(fields, id: 0) != nil else {
                entries.append(entry)
                continue
            }
            if let id = fields["SwiftEntityID"]?.integerValue { old[id] = fields }
        }
        for entity in entities.sorted(by: { $0.id < $1.id }) {
            guard let vanillaID = vanillaIDs[entity.kind] else { continue }
            var fields = old[entity.id] ?? [:]
            fields["id"] = .string(vanillaID)
            fields["SwiftEntityID"] = .long(entity.id)
            fields["Pos"] = doubles(entity.position + SIMD3(0, offset(entity), 0))
            fields["Motion"] = doubles(entity.velocity)
            fields["Rotation"] = .list(
                .float, [.float(entity.yaw * 180 / .pi + 180), .float(-entity.pitch * 180 / .pi)])
            fields["Air"] = .short(Int16(clamping: entity.air))
            fields["Fire"] = .short(Int16(clamping: entity.fireTicks))
            fields["OnGround"] = .byte(entity.onGround ? 1 : 0)
            fields["FallDistance"] = .float(entity.fallDistance)
            fields["SwiftAge"] = .int(Int32(clamping: entity.ageTicks))
            fields["SwiftPickupDelay"] = .int(Int32(clamping: entity.pickupDelay))
            fields["SwiftMetadata"] = .byte(Int8(bitPattern: entity.metadata))
            fields["SwiftRiderID"] = entity.riderID.map(NBTTag.long)
            fields["SwiftLastDamage"] = .int(Int32(clamping: entity.lastDamage))
            fields["SwiftLootDropped"] = .byte(entity.lootDropped ? 1 : 0)
            if entity.isLiving {
                fields["Health"] = .short(Int16(clamping: entity.health))
                fields["HurtTime"] = .short(Int16(clamping: entity.hurtTicks))
                fields["AttackTime"] = .short(Int16(clamping: entity.attackCooldown))
                fields["DeathTime"] = .short(Int16(clamping: entity.deathTicks))
            }
            switch entity.kind {
            case "painting":
                guard let anchor = entity.paintingAnchor else { continue }
                fields["Dir"] = .byte(Int8(bitPattern: entity.paintingFacing))
                fields["Motive"] = .string(entity.paintingMotive ?? "Kebab")
                fields["TileX"] = .int(Int32(clamping: anchor.x))
                fields["TileY"] = .int(Int32(clamping: anchor.y))
                fields["TileZ"] = .int(Int32(clamping: anchor.z))
            case "item":
                guard let stack = entity.itemStack else { continue }
                fields["Item"] = InventoryNBT.encodeStack(
                    stack, previous: fields["Item"]?.compoundValue ?? [:])
                fields["Health"] = .short(Int16(clamping: entity.health))
                fields["Age"] = .short(Int16(truncatingIfNeeded: entity.ageTicks))
            case "primedTnt": fields["Fuse"] = .byte(Int8(truncatingIfNeeded: entity.fuseTicks))
            case "fallingSand":
                fields["Tile"] = .byte(
                    Int8(bitPattern: entity.fallingBlock?.kind.rawValue ?? BlockKind.sand.rawValue))
                fields["SwiftBlockData"] = .byte(Int8(bitPattern: entity.fallingBlock?.metadata ?? 0))
            case "minecart":
                fields["Type"] = .int(Int32(entity.metadata))
                if entity.metadata == 1 {
                    fields["Items"] = InventoryNBT.encode(
                        entity.contents,
                        previous: fields["Items"]?.listValue ?? [])
                } else if entity.metadata == 2 {
                    fields["PushX"] = .double(entity.pushDirection.x)
                    fields["PushZ"] = .double(entity.pushDirection.y)
                    fields["Fuel"] = .short(Int16(truncatingIfNeeded: entity.fuelTicks))
                }
            case "pig": fields["Saddle"] = .byte(Int8(entity.metadata & 1))
            case "sheep":
                fields["Color"] = .byte(Int8(entity.metadata & 15))
                fields["Sheared"] = .byte(entity.metadata & 16 == 0 ? 0 : 1)
            case "wolf":
                fields["Angry"] = .byte(entity.angerTicks > 0 || entity.metadata & 2 != 0 ? 1 : 0)
                fields["Sitting"] = .byte(Int8(entity.metadata & 1))
                fields["Owner"] = .string(entity.owner ?? "")
            case "pigZombie": fields["Anger"] = .short(Int16(clamping: entity.angerTicks))
            case "creeper": fields["powered"] = .byte(Int8(entity.metadata & 1))
            case "slime":
                fields["Size"] = .int(Int32(max(1, Int((entity.width / Double(Float(0.6))).rounded())) - 1))
            case "arrow", "snowball":
                fields["inGround"] = .byte(entity.inGround ? 1 : 0)
                fields["inData"] = .byte(Int8(bitPattern: entity.stuckState?.metadata ?? entity.metadata))
                fields["shake"] = .byte(Int8(clamping: entity.pickupDelay))
                fields["SwiftInGroundAge"] = .int(Int32(clamping: entity.ticksInGround))
                fields["SwiftProjectileOwner"] = entity.projectileOwner.map(NBTTag.long)
                fields["xTile"] = .short(Int16(truncatingIfNeeded: entity.stuckBlock?.x ?? -1))
                fields["yTile"] = .short(Int16(truncatingIfNeeded: entity.stuckBlock?.y ?? -1))
                fields["zTile"] = .short(Int16(truncatingIfNeeded: entity.stuckBlock?.z ?? -1))
                fields["inTile"] = .byte(Int8(bitPattern: entity.stuckState?.kind.rawValue ?? 0))
                fields["player"] = .byte(entity.projectileOwner == 0 ? 1 : 0)
            default: break
            }
            entries.append(.compound(fields))
        }
        return .list(entries.isEmpty ? .byte : .compound, entries)
    }

    private static func decode(_ fields: [String: NBTTag], id: Int64) -> GameEntity? {
        guard let vanillaID = fields["id"]?.stringValue,
            let kind = vanillaIDs.first(where: { $0.value == vanillaID })?.key,
            let savedPosition = vector(fields["Pos"])
        else { return nil }
        var entity = GameEntity(id: id, kind: kind, position: savedPosition)
        entity.position.y -= offset(entity)
        entity.previousPosition = entity.position
        entity.velocity = vector(fields["Motion"]) ?? .zero
        for axis in 0..<3 where abs(entity.velocity[axis]) > 10 { entity.velocity[axis] = 0 }
        let angles = fields["Rotation"]?.listValue?.compactMap(\.doubleValue)
        if let angles, angles.count == 2, angles.allSatisfy(\.isFinite) {
            entity.yaw = Float((angles[0] - 180) * .pi / 180)
            entity.pitch = Float(-angles[1] * .pi / 180)
        }
        entity.onGround = (fields["OnGround"]?.integerValue ?? 0) != 0
        entity.air = Int(fields["Air"]?.integerValue ?? 300)
        entity.fireTicks = Int(fields["Fire"]?.integerValue ?? 0)
        entity.fallDistance = Float(fields["FallDistance"]?.doubleValue ?? 0)
        entity.ageTicks = Int(fields["SwiftAge"]?.integerValue ?? 0)
        entity.pickupDelay = Int(fields["SwiftPickupDelay"]?.integerValue ?? 0)
        entity.metadata = UInt8(truncatingIfNeeded: fields["SwiftMetadata"]?.integerValue ?? 0)
        entity.riderID = fields["SwiftRiderID"]?.integerValue
        entity.lastDamage = Int(fields["SwiftLastDamage"]?.integerValue ?? 0)
        if entity.isLiving {
            entity.health = Int(fields["Health"]?.integerValue ?? 10)
            entity.hurtTicks = Int(fields["HurtTime"]?.integerValue ?? 0)
            entity.attackCooldown = Int(fields["AttackTime"]?.integerValue ?? 0)
            entity.deathTicks = Int(fields["DeathTime"]?.integerValue ?? 0)
        }
        entity.lootDropped =
            (fields["SwiftLootDropped"]?.integerValue ?? (entity.deathTicks > 0 ? 1 : 0)) != 0
        switch kind {
        case "painting":
            let anchor = BlockPosition(
                Int(fields["TileX"]?.integerValue ?? 0),
                Int(fields["TileY"]?.integerValue ?? 0), Int(fields["TileZ"]?.integerValue ?? 0))
            let motion = entity.velocity
            BetaPainting.configure(
                &entity, anchor: anchor,
                direction: UInt8(truncatingIfNeeded: fields["Dir"]?.integerValue ?? 0),
                motive: fields["Motive"]?.stringValue ?? "Kebab")
            entity.velocity = motion
        case "item":
            guard let item = fields["Item"], let stack = InventoryNBT.stack(item) else { return nil }
            entity.itemStack = stack
            entity.health = Int(UInt8(truncatingIfNeeded: fields["Health"]?.integerValue ?? 5))
            entity.ageTicks = Int(fields["Age"]?.integerValue ?? 0)
        case "primedTnt": entity.fuseTicks = Int(fields["Fuse"]?.integerValue ?? 80)
        case "fallingSand":
            let block = UInt8(truncatingIfNeeded: fields["Tile"]?.integerValue ?? 12)
            entity.fallingBlock = BlockKind(rawValue: block).map {
                BlockState(
                    $0, metadata: UInt8(truncatingIfNeeded: fields["SwiftBlockData"]?.integerValue ?? 0))
            }
        case "minecart":
            entity.metadata = UInt8(truncatingIfNeeded: fields["Type"]?.integerValue ?? 0)
            if entity.metadata == 1 {
                entity.contents = InventoryNBT.decode(fields["Items"]?.listValue ?? [], slotCount: 27)
            } else if entity.metadata == 2 {
                entity.pushDirection = SIMD2(
                    fields["PushX"]?.doubleValue ?? 0, fields["PushZ"]?.doubleValue ?? 0)
                entity.fuelTicks = Int(fields["Fuel"]?.integerValue ?? 0)
            }
        case "pig": entity.metadata = (fields["Saddle"]?.integerValue ?? 0) == 0 ? 0 : 1
        case "sheep":
            entity.metadata = UInt8(truncatingIfNeeded: fields["Color"]?.integerValue ?? 0) & 15
            if (fields["Sheared"]?.integerValue ?? 0) != 0 { entity.metadata |= 16 }
        case "wolf":
            entity.metadata = (fields["Sitting"]?.integerValue ?? 0) == 0 ? 0 : 1
            if (fields["Angry"]?.integerValue ?? 0) != 0 {
                entity.metadata |= 2
                entity.angerTicks = 400
            }
            if let owner = fields["Owner"]?.stringValue, !owner.isEmpty {
                entity.owner = owner
                entity.metadata |= 4
            }
        case "pigZombie": entity.angerTicks = Int(fields["Anger"]?.integerValue ?? 0)
        case "creeper": entity.metadata = (fields["powered"]?.integerValue ?? 0) == 0 ? 0 : 1
        case "slime":
            let size = Int(min(127, max(0, fields["Size"]?.integerValue ?? 0))) + 1
            entity.metadata = UInt8(size)
            entity.width = Double(Float(size) * Float(0.6))
            entity.height = entity.width
        case "arrow", "snowball":
            entity.inGround = (fields["inGround"]?.integerValue ?? 0) != 0
            entity.metadata = UInt8(truncatingIfNeeded: fields["inData"]?.integerValue ?? 0)
            entity.pickupDelay = Int(fields["shake"]?.integerValue ?? 0)
            entity.ticksInGround = Int(fields["SwiftInGroundAge"]?.integerValue ?? 0)
            entity.projectileOwner =
                fields["SwiftProjectileOwner"]?.integerValue
                ?? ((fields["player"]?.integerValue ?? 0) == 0 ? nil : 0)
            if let x = fields["xTile"]?.integerValue, let y = fields["yTile"]?.integerValue,
                let z = fields["zTile"]?.integerValue, y >= 0
            {
                entity.stuckBlock = BlockPosition(Int(x), Int(y), Int(z))
            }
            if let block = fields["inTile"]?.integerValue,
                let kind = BlockKind(rawValue: UInt8(truncatingIfNeeded: block)), kind != .air
            {
                entity.stuckState = BlockState(kind, metadata: entity.metadata)
            }
        default: break
        }
        return entity
    }

    private static func doubles(_ vector: SIMD3<Double>) -> NBTTag {
        .list(.double, [.double(vector.x), .double(vector.y), .double(vector.z)])
    }

    private static func vector(_ value: NBTTag?) -> SIMD3<Double>? {
        guard let values = value?.listValue?.compactMap(\.doubleValue), values.count == 3,
            values.allSatisfy({ $0.isFinite && abs($0) < Double(Int32.max) })
        else { return nil }
        return SIMD3(values[0], values[1], values[2])
    }

    private static func offset(_ entity: GameEntity) -> Double {
        switch entity.kind {
        case "item", "primedTnt", "fallingSand", "minecart", "boat", "painting":
            Double(Float(entity.height) / 2)
        default: 0
        }
    }

    private static let vanillaIDs: [String: String] = [
        "arrow": "Arrow", "snowball": "Snowball", "item": "Item", "creeper": "Creeper",
        "skeleton": "Skeleton", "spider": "Spider", "zombie": "Zombie", "slime": "Slime",
        "ghast": "Ghast", "pigZombie": "PigZombie", "pig": "Pig", "sheep": "Sheep", "cow": "Cow",
        "chicken": "Chicken", "squid": "Squid", "wolf": "Wolf", "primedTnt": "PrimedTnt",
        "fallingSand": "FallingSand", "minecart": "Minecart", "boat": "Boat", "painting": "Painting",
    ]
}
