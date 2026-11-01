import Foundation

public enum BlockInteractions {
    public static func use(
        hit: BlockHit, holding: ItemStack?, yaw: Float, playerBounds: AxisAlignedBox,
        world: inout BlockWorld, health: Int = 20
    ) -> BlockUseResult {
        var random = JavaRandom(seed: world.seed ^ Int64(truncatingIfNeeded: world.revision))
        let initial = activateOre(at: hit.position, world: &world, random: &random)
        var result = performUse(
            hit: hit, holding: holding, yaw: yaw, playerBounds: playerBounds,
            world: &world, health: health)
        result.events = initial.events + result.events
        result.changedPositions = initial.changedPositions + result.changedPositions
        return result
    }

    static func attack(
        hit: BlockHit, holding: ItemStack?, health: Int, world: inout BlockWorld, random: inout JavaRandom
    ) -> BlockUseResult {
        let p = hit.position
        guard let state = world.state(at: p) else { return .init() }
        switch state.kind {
        case .woodenDoor, .ironDoor, .trapdoor, .lever, .stoneButton, .cake:
            return activate(at: p, holding: holding, world: &world, health: health)
        case .redstoneOre, .litRedstoneOre:
            return activateOre(at: p, world: &world, random: &random)
        case .noteBlock:
            var result = BlockUseResult()
            result.handled = true
            let pitch: UInt8
            if case .note(let current) = world.blockEntity(at: p) {
                pitch = current
            } else {
                pitch = 0
                world.setBlockEntity(.note(pitch: 0), at: p)
            }
            if world[p.adding(BlockPosition(0, 1, 0))] == nil {
                result.events = [noteSound(at: p, pitch: pitch, world: world)]
            }
            return result
        case .tnt where holding?.id == 259:
            world.setBlock(BlockState(.tnt, metadata: 1), at: p)
            var result = BlockUseResult()
            result.handled = true
            result.changedPositions = [p]
            return result
        default: return .init()
        }
    }

    static func activateOre(at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom)
        -> BlockUseResult
    {
        var result = BlockUseResult()
        guard world[p] == .redstoneOre || world[p] == .litRedstoneOre else { return result }
        result.handled = true
        for side in 0..<6 {
            var position = SIMD3(
                Double(p.x) + Double(random.nextFloat()), Double(p.y) + Double(random.nextFloat()),
                Double(p.z) + Double(random.nextFloat()))
            let offsets = [
                BlockPosition(0, 1, 0), BlockPosition(0, -1, 0), BlockPosition(0, 0, 1),
                BlockPosition(0, 0, -1), BlockPosition(1, 0, 0), BlockPosition(-1, 0, 0),
            ]
            let neighbor = world[p.adding(offsets[side])]
            if neighbor?.isOpaque != true && neighbor != .leaves {
                switch side {
                case 0: position.y = Double(p.y) + 1.0625
                case 1: position.y = Double(p.y) - 0.0625
                case 2: position.z = Double(p.z) + 1.0625
                case 3: position.z = Double(p.z) - 0.0625
                case 4: position.x = Double(p.x) + 1.0625
                default: position.x = Double(p.x) - 0.0625
                }
            }
            if position.x < Double(p.x) || position.x > Double(p.x + 1) || position.y < 0
                || position.y > Double(p.y + 1) || position.z < Double(p.z) || position.z > Double(p.z + 1)
            {
                result.events.append(.particle(name: "reddust", position: position))
            }
        }
        if world[p] == .redstoneOre {
            world[p] = .litRedstoneOre
            result.changedPositions = [p]
        }
        return result
    }

    public static func containerDrops(_ tile: BlockEntity, at p: BlockPosition, random: inout JavaRandom)
        -> [BlockEvent]
    {
        var events: [BlockEvent] = []
        if case .jukebox(let record) = tile {
            guard let record else { return [] }
            let spread: Float = 0.7
            let x = Double(random.nextFloat() * spread) + Double(1 - spread) * 0.5
            let y = Double(random.nextFloat() * spread) + Double(1 - spread) * 0.2 + 0.6
            let z = Double(random.nextFloat() * spread) + Double(1 - spread) * 0.5
            return [
                .dropItem(
                    position: SIMD3(Double(p.x) + x, Double(p.y) + y, Double(p.z) + z),
                    stack: ItemStack(id: record))
            ]
        }
        for case var stack? in tile.contents where stack.count > 0 {
            let offset = SIMD3(
                random.nextFloat() * 0.8 + 0.1, random.nextFloat() * 0.8 + 0.1,
                random.nextFloat() * 0.8 + 0.1)
            let position = SIMD3(
                Double(Float(p.x) + offset.x), Double(Float(p.y) + offset.y), Double(Float(p.z) + offset.z))
            while stack.count > 0 {
                let count = min(stack.count, random.nextInt(bound: 21) + 10)
                stack.count -= count
                let velocity = SIMD3(
                    Double(Float(random.nextGaussian()) * 0.05),
                    Double(Float(random.nextGaussian()) * 0.05 + 0.2),
                    Double(Float(random.nextGaussian()) * 0.05))
                events.append(
                    .dropItemMoving(
                        position: position,
                        stack: ItemStack(id: stack.id, count: count, damage: stack.damage), velocity: velocity
                    ))
            }
        }
        return events
    }

    private static func performUse(
        hit: BlockHit, holding: ItemStack?, yaw: Float, playerBounds: AxisAlignedBox,
        world: inout BlockWorld, health: Int = 20
    ) -> BlockUseResult {
        var result = activate(at: hit.position, holding: holding, world: &world, health: health)
        if result.handled { return result }
        guard let holding, holding.count > 0 else { return result }
        result.itemUsed = ![325, 326, 327, 335].contains(holding.id)
        let p = hit.position
        let target = world[p] == .snowLayer ? p : hit.adjacentPosition

        if holding.id == 325 {
            guard let state = world.state(at: p), state.metadata == 0, state.kind.isLiquid else {
                return result
            }
            world.setBlock(nil, at: p)
            result.handled = true
            result.replacement = ItemStack(id: BlockPlacement.isWater(state.kind) ? 326 : 327)
            result.replaceHeldStack = true
            result.changedPositions = [p]
            return result
        }
        if holding.id == 326 || holding.id == 327 {
            guard (0..<128).contains(target.y), world[target]?.isMaterialSolid != true else { return result }
            result.handled = true
            result.replacement = ItemStack(id: 325)
            result.replaceHeldStack = true
            if holding.id == 326 && world.dimension == -1 {
                result.events = [sound("random.fizz", at: target)]
                for _ in 0..<8 {
                    result.events.append(.particle(name: "largesmoke", position: target.center))
                }
                return result
            }
            world.setBlock(BlockState(holding.id == 326 ? .water : .lava), at: target)
            result.changedPositions = [target]
            return result
        }
        if holding.id == 335 {
            result.handled = true
            result.replacement = ItemStack(id: 325)
            result.replaceHeldStack = true
            return result
        }
        if (290...294).contains(holding.id) {
            let state = world[p]
            let above = p.adding(BlockPosition(0, 1, 0))
            if state == .dirt || (state == .grass && hit.face.y != -1 && world[above] == nil) {
                world[p] = .farmland
                result.handled = true
                result.durabilityDamage = 1
                result.changedPositions = [p]
                result.events = [sound("step.gravel", at: p)]
            }
            return result
        }
        if holding.id == 295 {
            let above = p.adding(BlockPosition(0, 1, 0))
            if hit.face.y == 1 && world[p] == .farmland && world[above] == nil {
                world[above] = .wheat
                result.handled = true
                result.consumed = 1
                result.changedPositions = [above]
            }
            return result
        }
        if holding.id == 351 && holding.damage == 15 {
            return applyBoneMeal(at: p, world: &world)
        }
        if holding.id == 259 {
            result.handled = true
            result.durabilityDamage = 1
            if world[target] == nil && (0..<128).contains(target.y) {
                world[target] = .fire
                result.changedPositions = [target]
                result.events = [sound("fire.ignite", at: target)]
            }
            return result
        }
        if holding.id == 324 || holding.id == 330 {
            return placeDoor(
                hit: hit, kind: holding.id == 324 ? .woodenDoor : .ironDoor, yaw: yaw, world: &world)
        }
        if holding.id == 355 { return placeBed(hit: hit, yaw: yaw, world: &world) }
        if holding.id == 323 {
            guard hit.face.y != -1, world[p]?.isMaterialSolid == true,
                BlockPlacement.isReplaceable(world.state(at: target))
            else { return result }
            let metadata =
                hit.face.y == 1
                ? UInt8(Int(floor(yaw * 8 / .pi + 0.5)) & 15)
                : sideNumber(hit.face)
            world.setBlock(
                BlockState(hit.face.y == 1 ? .standingSign : .wallSign, metadata: metadata), at: target)
            world.setBlockEntity(.sign(lines: ["", "", "", ""]), at: target)
            result.handled = true
            result.consumed = 1
            result.changedPositions = [target]
            result.openContainer = target
            return result
        }

        let blockID: UInt16
        switch holding.id {
        case 331: blockID = 55
        case 338: blockID = 83
        case 354: blockID = 92
        case 356: blockID = 93
        default: blockID = holding.id
        }
        guard blockID > 0, blockID <= 96, let kind = BlockKind(rawValue: UInt8(blockID)) else {
            return useInAir(holding: holding, health: health)
        }
        if kind == .slab, hit.face.y == 1, world[p] == .slab,
            world.state(at: p)?.metadata == UInt8(holding.damage & 15)
        {
            let state = BlockState(.doubleSlab, metadata: UInt8(holding.damage & 15))
            guard !BlockCollision.boxes(for: state, at: p).contains(where: { $0.intersects(playerBounds) })
            else { return result }
            world.setBlock(state, at: p)
            result.handled = true
            result.consumed = 1
            result.changedPositions = [p]
            return result
        }
        guard (0..<128).contains(target.y), BlockPlacement.isReplaceable(world.state(at: target)),
            let state = BlockPlacement.placementState(
                kind: kind, damage: holding.damage, face: hit.face, yaw: yaw),
            BlockPlacement.canRemain(state, at: target, in: world),
            !BlockCollision.boxes(for: state, at: target).contains(where: { $0.intersects(playerBounds) })
        else { return result }
        if kind == .chest && !canPlaceChest(at: target, world: world) { return result }
        var placedState = state
        if kind == .piston || kind == .stickyPiston {
            let center = (playerBounds.min + playerBounds.max) / 2
            let eye = playerBounds.min.y + 1.82
            if abs(center.x - Double(target.x)) < 2 && abs(center.z - Double(target.z)) < 2 {
                if eye - Double(target.y) > 2 {
                    placedState.metadata = 1
                } else if Double(target.y) - eye > 0 {
                    placedState.metadata = 0
                }
            }
        }
        world.setBlock(placedState, at: target)
        if let tile = BlockEntity.initial(for: kind) { world.setBlockEntity(tile, at: target) }
        result.handled = true
        result.consumed = 1
        result.changedPositions = [target]
        result.events = [sound(kind == .wood || kind == .planks ? "step.wood" : "step.stone", at: target)]
        return result
    }

    public static func useInAir(holding: ItemStack?, health: Int) -> BlockUseResult {
        var result = BlockUseResult()
        guard let holding, holding.count > 0, let definition = holding.definition,
            definition.foodHealing > 0
        else { return result }
        result.handled = true
        result.healthRestored = definition.foodHealing
        if holding.id == 282 {
            result.replacement = ItemStack(id: 281)
            result.replaceHeldStack = true
        } else {
            result.consumed = 1
        }
        return result
    }

    public static func didBreak(
        _ state: BlockState, at p: BlockPosition, holding: ItemStack?, world: inout BlockWorld
    ) -> [BlockEvent] {
        if state.kind == .tnt && (holding?.id == 259 || state.metadata & 1 != 0) {
            return [
                .spawnEntity(kind: "PrimedTnt", position: p.center - SIMD3(0, Double(Float(0.98)) / 2, 0)),
                sound("random.fuse", at: p),
            ]
        }
        if state.kind == .ice {
            let below = world[p.adding(BlockPosition(0, -1, 0))]
            if below?.isMaterialSolid == true || below?.isLiquid == true { world[p] = .water }
        }
        return []
    }

    private static func activate(
        at p: BlockPosition, holding: ItemStack?, world: inout BlockWorld, health: Int
    ) -> BlockUseResult {
        var result = BlockUseResult()
        guard let state = world.state(at: p) else { return result }
        switch state.kind {
        case .craftingTable, .furnace, .burningFurnace, .dispenser:
            if world.blockEntity(at: p) == nil, let tile = BlockEntity.initial(for: state.kind) {
                world.setBlockEntity(tile, at: p)
            }
            result.handled = true
            result.openContainer = p
        case .chest:
            result.handled = true
            let chests = [p] + BlockPosition.horizontal.map { p.adding($0) }.filter { world[$0] == .chest }
            guard !chests.contains(where: { world[$0.adding(BlockPosition(0, 1, 0))]?.isNormalCube == true })
            else { break }
            if world.blockEntity(at: p) == nil { world.setBlockEntity(.initial(for: .chest), at: p) }
            result.openContainer = p
        case .woodenDoor, .ironDoor:
            result.handled = true
            guard state.kind == .woodenDoor else { break }
            let lower = state.metadata & 8 == 0 ? p : p.adding(BlockPosition(0, -1, 0))
            guard let bottom = world.state(at: lower), bottom.kind == .woodenDoor else { break }
            let data = bottom.metadata ^ 4
            world.setBlock(BlockState(.woodenDoor, metadata: data), at: lower)
            let upper = lower.adding(BlockPosition(0, 1, 0))
            if world[upper] == .woodenDoor {
                world.setBlock(BlockState(.woodenDoor, metadata: data | 8), at: upper)
            }
            result.changedPositions = [lower, upper]
            result.events = [sound("random.door_open", at: lower)]
        case .trapdoor:
            result.handled = true
            world.setBlock(BlockState(.trapdoor, metadata: state.metadata ^ 4), at: p)
            result.changedPositions = [p]
            result.events = [sound("random.door_open", at: p)]
        case .lever, .stoneButton:
            result.handled = true
            guard state.kind != .stoneButton || state.metadata & 8 == 0 else { break }
            world.setBlock(BlockState(state.kind, metadata: state.metadata ^ 8), at: p)
            result.changedPositions = [p]
            result.events = [sound("random.click", at: p)]
        case .repeaterOff, .repeaterOn:
            result.handled = true
            world.setBlock(
                BlockState(state.kind, metadata: ((state.metadata + 4) & 12) | (state.metadata & 3)), at: p)
            result.changedPositions = [p]
        case .bed:
            result.handled = true
            let head = state.metadata & 8 != 0 ? p : p.adding(BlockPlacement.bedDirection(state.metadata))
            if world.dimension == -1 {
                let direction = BlockPlacement.bedDirection(state.metadata)
                let foot = head.adding(BlockPosition(-direction.x, 0, -direction.z))
                world.setBlock(nil, at: head)
                world.setBlock(nil, at: foot)
                result.changedPositions = [head, foot]
                result.events = [.explosion(position: head.center, power: 5)]
            } else {
                result.sleepAt = head
            }
        case .cake:
            result.handled = true
            guard health < 20 else { break }
            result.healthRestored = 3
            world.setBlock(state.metadata >= 5 ? nil : BlockState(.cake, metadata: state.metadata + 1), at: p)
            result.changedPositions = [p]
        case .noteBlock:
            result.handled = true
            let pitch: UInt8
            if case .note(let current) = world.blockEntity(at: p) {
                pitch = (current + 1) % 25
            } else {
                pitch = 1
            }
            world.setBlockEntity(.note(pitch: pitch), at: p)
            if world[p.adding(BlockPosition(0, 1, 0))] == nil {
                result.events = [noteSound(at: p, pitch: pitch, world: world)]
            }
        case .jukebox:
            let record: UInt16?
            if case .jukebox(let current) = world.blockEntity(at: p) {
                record = current
            } else {
                record = nil
            }
            if let record {
                result.handled = true
                result.events = [
                    .dropItem(position: p.center + SIMD3(0, 0.7, 0), stack: ItemStack(id: record))
                ]
                world.setBlockEntity(.jukebox(record: nil), at: p)
                world.setBlock(BlockState(.jukebox), at: p)
            } else if let holding, holding.id == 2256 || holding.id == 2257 {
                result.handled = true
                result.consumed = 1
                world.setBlockEntity(.jukebox(record: holding.id), at: p)
                world.setBlock(BlockState(.jukebox, metadata: 1), at: p)
                result.events = [sound(holding.id == 2256 ? "records.13" : "records.cat", at: p)]
            }
        default: break
        }
        return result
    }

    private static func placeDoor(hit: BlockHit, kind: BlockKind, yaw: Float, world: inout BlockWorld)
        -> BlockUseResult
    {
        var result = BlockUseResult()
        let p = hit.adjacentPosition
        let upper = p.adding(BlockPosition(0, 1, 0))
        guard hit.face.y == 1, p.y < 127, world[hit.position]?.isNormalCube == true,
            BlockPlacement.isReplaceable(world.state(at: p)),
            BlockPlacement.isReplaceable(world.state(at: upper))
        else { return result }
        var orientation = Int(floor(yaw * 2 / .pi - 0.5)) & 3
        let side = BlockPlacement.bedDirection(UInt8(orientation))
        let left = p.adding(BlockPosition(-side.x, 0, -side.z))
        let right = p.adding(side)
        let leftSolid =
            (world[left]?.isNormalCube == true ? 1 : 0)
            + (world[left.adding(BlockPosition(0, 1, 0))]?.isNormalCube == true ? 1 : 0)
        let rightSolid =
            (world[right]?.isNormalCube == true ? 1 : 0)
            + (world[right.adding(BlockPosition(0, 1, 0))]?.isNormalCube == true ? 1 : 0)
        let leftDoor = world[left] == kind || world[left.adding(BlockPosition(0, 1, 0))] == kind
        let rightDoor = world[right] == kind || world[right.adding(BlockPosition(0, 1, 0))] == kind
        if leftDoor && !rightDoor || rightSolid > leftSolid { orientation = ((orientation - 1) & 3) + 4 }
        world.setBlock(BlockState(kind, metadata: UInt8(orientation)), at: p)
        world.setBlock(BlockState(kind, metadata: UInt8(orientation) | 8), at: upper)
        result.handled = true
        result.itemUsed = true
        result.consumed = 1
        result.changedPositions = [p, upper]
        return result
    }

    private static func placeBed(hit: BlockHit, yaw: Float, world: inout BlockWorld) -> BlockUseResult {
        var result = BlockUseResult()
        let foot = hit.adjacentPosition
        let metadata = BlockPlacement.quadrant(yaw: yaw)
        let head = foot.adding(BlockPlacement.bedDirection(metadata))
        guard hit.face.y == 1, (0..<128).contains(foot.y), world[foot] == nil, world[head] == nil,
            world[foot.adding(BlockPosition(0, -1, 0))]?.isNormalCube == true,
            world[head.adding(BlockPosition(0, -1, 0))]?.isNormalCube == true
        else { return result }
        world.setBlock(BlockState(.bed, metadata: metadata), at: foot)
        world.setBlock(BlockState(.bed, metadata: metadata | 8), at: head)
        result.handled = true
        result.itemUsed = true
        result.consumed = 1
        result.changedPositions = [foot, head]
        return result
    }

    private static func canPlaceChest(at p: BlockPosition, world: BlockWorld) -> Bool {
        let neighbors = BlockPosition.horizontal.map { p.adding($0) }.filter { world[$0] == .chest }
        guard neighbors.count <= 1 else { return false }
        return !neighbors.contains { chest in
            BlockPosition.horizontal.contains { world[chest.adding($0)] == .chest }
        }
    }

    private static func applyBoneMeal(at p: BlockPosition, world: inout BlockWorld) -> BlockUseResult {
        var result = BlockUseResult()
        if world[p] == .wheat {
            world.setBlock(BlockState(.wheat, metadata: 7), at: p)
        } else if world[p] == .sapling {
            var random = JavaRandom(seed: world.seed ^ Int64(truncatingIfNeeded: world.revision))
            let metadata = world.state(at: p)?.metadata ?? 0
            BlockGrowth.growTree(at: p, metadata: metadata, world: &world, random: &random)
        } else if world[p] == .grass {
            var random = JavaRandom(seed: world.seed ^ Int64(truncatingIfNeeded: world.revision))
            for attempt in 0..<128 {
                var target = p.adding(BlockPosition(0, 1, 0))
                var valid = true
                for _ in 0..<(attempt / 16) {
                    target = target.adding(
                        BlockPosition(
                            random.nextInt(bound: 3) - 1,
                            (random.nextInt(bound: 3) - 1) * random.nextInt(bound: 3) / 2,
                            random.nextInt(bound: 3) - 1))
                    if world[target.adding(BlockPosition(0, -1, 0))] != .grass
                        || world[target]?.isNormalCube == true
                    {
                        valid = false
                        break
                    }
                }
                guard valid, world[target] == nil else { continue }
                let kind: BlockKind
                if random.nextInt(bound: 10) != 0 {
                    kind = .tallGrass
                } else {
                    kind = random.nextInt(bound: 3) != 0 ? .dandelion : .rose
                }
                world.setBlock(BlockState(kind, metadata: kind == .tallGrass ? 1 : 0), at: target)
                result.changedPositions.append(target)
            }
        } else {
            return result
        }
        result.handled = true
        result.itemUsed = true
        result.consumed = 1
        result.changedPositions.append(p)
        return result
    }

    static func sound(_ name: String, at p: BlockPosition, pitch: Float = 1) -> BlockEvent {
        .sound(name: name, position: p.center, volume: 1, pitch: pitch)
    }

    static func noteSound(at p: BlockPosition, pitch: UInt8, world: BlockWorld) -> BlockEvent {
        let below = world[p.adding(BlockPosition(0, -1, 0))]
        let name = below?.noteInstrument ?? "note.harp"
        return .sound(name: name, position: p.center, volume: 3, pitch: pow(2, Float(Int(pitch) - 12) / 12))
    }

    private static func sideNumber(_ face: BlockPosition) -> UInt8 {
        if face.z == -1 { return 2 }
        if face.z == 1 { return 3 }
        if face.x == -1 { return 4 }
        return 5
    }
}
