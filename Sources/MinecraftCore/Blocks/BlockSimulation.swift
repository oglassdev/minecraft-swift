import Foundation

public struct BlockSimulation: Sendable {
    private struct TickKey: Hashable, Sendable {
        let position: BlockPosition
        let kind: BlockKind
    }

    private struct ScheduledTick: Sendable {
        let key: TickKey
        let time: Int64
        let order: UInt64
    }

    private var random: JavaRandom
    private var updateLCG: Int32
    private var pending: [TickKey: ScheduledTick] = [:]
    private var nextOrder: UInt64 = 0
    private var knownChunks: Set<ChunkPosition> = []
    private var currentTime: Int64 = 0
    private var weather: WorldWeather?
    private var poweredDevices: Set<BlockPosition> = []
    private var pressurePlates: Set<BlockPosition> = []
    private var torchBurnouts: [BlockPosition: [Int64]] = [:]
    private var knownRails: [BlockPosition: BlockKind] = [:]

    public init(seed: Int64) {
        random = JavaRandom(seed: seed)
        updateLCG = random.nextInt()
    }

    public mutating func attack(
        hit: BlockHit, holding: ItemStack?, health: Int, world: inout BlockWorld, time: Int64
    ) -> BlockUseResult {
        currentTime = time
        var result = BlockInteractions.attack(
            hit: hit, holding: holding, health: health, world: &world, random: &random)
        for p in result.changedPositions { result.events += blockChanged(at: p, world: &world, time: time) }
        return result
    }

    public mutating func stepped(
        at p: BlockPosition, world: inout BlockWorld, time: Int64, position: SIMD3<Double>? = nil
    ) -> [BlockEvent] {
        currentTime = time
        let below = p.adding(BlockPosition(0, -1, 0))
        guard let kind = world[below] == .fence ? .fence : world[p] else { return [] }
        var events: [BlockEvent] = []
        let soundKind = world[p.adding(BlockPosition(0, 1, 0))] == .snowLayer ? .snowLayer : kind
        if !kind.isLiquid || soundKind == .snowLayer {
            events.append(BlockSounds.step(for: soundKind, at: position ?? p.center))
        }
        if kind == .redstoneOre || kind == .litRedstoneOre {
            let changes = BlockInteractions.activateOre(at: p, world: &world, random: &random)
            events += changes.events
            for changed in changes.changedPositions {
                events += blockChanged(at: changed, world: &world, time: time)
            }
        } else if kind == .farmland && random.nextInt(bound: 4) == 0 {
            world[p] = .dirt
            events += blockChanged(at: p, world: &world, time: time)
        }
        return events
    }

    public mutating func containerDrops(_ tile: BlockEntity, at p: BlockPosition) -> [BlockEvent] {
        BlockInteractions.containerDrops(tile, at: p, random: &random)
    }

    @discardableResult
    public mutating func blockChanged(at p: BlockPosition, world: inout BlockWorld, time: Int64)
        -> [BlockEvent]
    {
        currentTime = time
        var events: [BlockEvent] = []
        if world[p] == nil { markLeaves(near: p, world: &world) }
        var queue = [p] + BlockPosition.neighbors.map { p.adding($0) }
        var visited: Set<BlockPosition> = []
        while let position = queue.popLast(), visited.count < 4096 {
            guard visited.insert(position).inserted, let state = world.state(at: position) else { continue }
            if state.kind == .fire && world[position.adding(BlockPosition(0, -1, 0))] == .obsidian {
                let portal = PortalFormation.form(at: position, world: &world)
                if !portal.isEmpty {
                    queue += portal
                    continue
                }
            }
            if position != p && state.kind == .farmland,
                world[position.adding(BlockPosition(0, 1, 0))]?.isMaterialSolid == true
            {
                world[position] = .dirt
                queue += BlockPosition.neighbors.map { position.adding($0) }
                continue
            }
            if !BlockPlacement.canRemain(state, at: position, in: world)
                || (position != p && !BlockGrowth.hasRequiredLight(state, at: position, world: world))
            {
                events += remove(at: position, world: &world)
                queue += BlockPosition.neighbors.map { position.adding($0) }
                continue
            }
            if RailSimulation.isRail(state.kind), knownRails[position] != state.kind {
                knownRails[position] = state.kind
                queue += RailSimulation.updateTopology(at: position, world: &world, force: true)
            }
            if state.kind.isLiquid {
                let mixed = FluidSimulation.mix(at: position, world: &world)
                events += mixed.events
                if !mixed.positions.isEmpty {
                    queue += BlockPosition.neighbors.map { position.adding($0) }
                    continue
                }
                let flowing: BlockKind = BlockPlacement.isWater(state.kind) ? .water : .lava
                if state.kind != flowing {
                    world.setBlock(BlockState(flowing, metadata: state.metadata), at: position)
                }
                schedule(position, kind: flowing, after: flowing == .water ? 5 : 30)
            } else {
                scheduleIfNeeded(position, state: state)
            }
            if world.blockEntity(at: position) == nil, let tile = BlockEntity.initial(for: state) {
                world.setBlockEntity(tile, at: position)
            }
        }
        let power = updatePower(around: [p] + Array(visited), world: &world)
        events += power.events
        for changed in power.positions { events += blockChanged(at: changed, world: &world, time: time) }
        return events
    }

    public mutating func tick(
        world: inout BlockWorld, players: [SIMD3<Double>], time: Int64, entities: [GameEntity] = [],
        weather: WorldWeather? = nil
    ) -> [BlockEvent] {
        currentTime = time
        self.weather = weather
        var events: [BlockEvent] = []
        discoverChunks(world: &world)
        for p in pressurePlates {
            guard let state = world.state(at: p),
                [.stonePressurePlate, .woodenPressurePlate, .detectorRail].contains(state.kind)
            else {
                pressurePlates.remove(p)
                continue
            }
            let occupied = state.kind == .detectorRail ? state.metadata & 8 != 0 : state.metadata != 0
            if !occupied {
                let changes = sensePressurePlate(
                    at: p, state: state, world: &world, players: players, entities: entities)
                events += changes.events
                for changed in changes.positions {
                    events += blockChanged(at: changed, world: &world, time: time)
                }
            }
        }
        let due = pending.values.filter { $0.time <= time }.sorted {
            $0.time == $1.time ? $0.order < $1.order : $0.time < $1.time
        }.prefix(1000)
        for tick in due {
            pending.removeValue(forKey: tick.key)
            let p = tick.key.position
            let loaded = (((p.x - 8) >> 4)...((p.x + 8) >> 4)).allSatisfy { x in
                (((p.z - 8) >> 4)...((p.z + 8) >> 4)).allSatisfy { z in
                    world.chunks[ChunkPosition(x, z)] != nil
                }
            }
            guard loaded else { continue }
            guard let state = world.state(at: p), state.kind == tick.key.kind else { continue }
            var changes = BlockGrowth.Changes()
            switch state.kind {
            case .water, .lava: changes = FluidSimulation.tick(at: p, world: &world, random: &random)
            case .sand, .gravel: changes = falling(at: p, state: state, world: &world)
            case .fire: changes = FireSimulation.tick(at: p, world: &world, random: &random, weather: weather)
            case .stonePressurePlate, .woodenPressurePlate, .detectorRail:
                changes = sensePressurePlate(
                    at: p, state: state, world: &world, players: players, entities: entities)
            case .stoneButton: changes = releaseButton(at: p, state: state, world: &world)
            case .litRedstoneOre:
                world[p] = .redstoneOre
                changes.positions = [p]
            case .redstoneTorch, .redstoneTorchOff, .repeaterOff, .repeaterOn:
                changes = powerTick(at: p, state: state, world: &world)
            case .dispenser: changes.events = dispense(at: p, world: &world)
            default: break
            }
            events += changes.events
            for changed in changes.positions {
                events += blockChanged(at: changed, world: &world, time: time)
            }
        }
        for chunk in world.chunks.keys.sorted(by: { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }) {
            let active =
                players.isEmpty
                || players.contains {
                    abs(Int(floor($0.x / 16)) - chunk.x) <= 9 && abs(Int(floor($0.z / 16)) - chunk.z) <= 9
                }
            guard active else { continue }
            for _ in 0..<80 {
                updateLCG = updateLCG &* 3 &+ 1_013_904_223
                let bits = updateLCG >> 2
                let p = BlockPosition(
                    chunk.x * 16 + Int(bits & 15), Int((bits >> 16) & 127),
                    chunk.z * 16 + Int((bits >> 8) & 15))
                guard let state = world.state(at: p) else { continue }
                let changes: BlockGrowth.Changes
                switch state.kind {
                case .water, .lava:
                    changes = FluidSimulation.tick(at: p, world: &world, random: &random)
                case .fire:
                    changes = FireSimulation.tick(at: p, world: &world, random: &random, weather: weather)
                case .redstoneTorch, .redstoneTorchOff:
                    changes = powerTick(at: p, state: state, world: &world)
                case .stonePressurePlate, .woodenPressurePlate, .detectorRail:
                    let occupied = state.kind == .detectorRail ? state.metadata & 8 != 0 : state.metadata != 0
                    changes =
                        occupied
                        ? sensePressurePlate(
                            at: p, state: state, world: &world, players: players, entities: entities)
                        : .init()
                case .stoneButton:
                    changes = releaseButton(at: p, state: state, world: &world)
                default:
                    changes = BlockGrowth.randomTick(
                        at: p, world: &world, random: &random, time: time, weather: weather)
                }
                events += changes.events
                for changed in changes.positions {
                    events += blockChanged(at: changed, world: &world, time: time)
                }
            }
        }
        events += tickAnimations(world: &world, time: time)
        events += tickTiles(world: &world, players: players, entities: entities)
        return events
    }

    public mutating func applyPistonAction(
        at p: BlockPosition, event: UInt8, parameter: UInt8,
        world: inout BlockWorld, time: Int64
    ) -> [BlockEvent] {
        currentTime = time
        guard event <= 1 else { return [] }
        return PistonSimulation.applyAction(
            at: p, extending: event == 0, facing: parameter & 7, world: &world, random: &random
        ).events
    }

    public mutating func tickAnimations(
        world: inout BlockWorld, time: Int64, notifyNeighbors: Bool = true
    ) -> [BlockEvent] {
        currentTime = time
        let positions = world.chunks.values.flatMap { chunk in
            chunk.blockEntities.compactMap { position, tile -> BlockPosition? in
                if case .piston = tile { return position }
                return nil
            }
        }.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        var events: [BlockEvent] = []
        for p in positions {
            let changes = PistonSimulation.tick(at: p, world: &world)
            events += changes.events
            if notifyNeighbors {
                for changed in changes.positions {
                    events += blockChanged(at: changed, world: &world, time: time)
                }
            }
        }
        return events
    }

    private func releaseButton(at p: BlockPosition, state: BlockState, world: inout BlockWorld)
        -> BlockGrowth.Changes
    {
        guard state.metadata & 8 != 0 else { return .init() }
        world.setBlock(BlockState(.stoneButton, metadata: state.metadata & 7), at: p)
        return .init(positions: [p], events: [BlockInteractions.sound("random.click", at: p, pitch: 0.5)])
    }

    private mutating func sensePressurePlate(
        at p: BlockPosition, state: BlockState, world: inout BlockWorld,
        players: [SIMD3<Double>], entities: [GameEntity]
    ) -> BlockGrowth.Changes {
        var changes = BlockGrowth.Changes()
        let sensor = AxisAlignedBox(
            min: p.center - SIMD3(0.375, 0.5, 0.375), max: p.center + SIMD3(0.375, -0.25, 0.375))
        let playerInside =
            state.kind != .detectorRail
            && players.contains {
                AxisAlignedBox(min: $0 - SIMD3(0.3, 0, 0.3), max: $0 + SIMD3(0.3, 1.8, 0.3)).intersects(
                    sensor)
            }
        let entityInside = entities.contains {
            guard $0.health > 0, $0.bounds.intersects(sensor) else { return false }
            if state.kind == .detectorRail { return $0.kind == "minecart" }
            return state.kind == .woodenPressurePlate || $0.isLiving
        }
        let occupied = playerInside || entityInside
        let wasOccupied = state.kind == .detectorRail ? state.metadata & 8 != 0 : state.metadata != 0
        if occupied != wasOccupied {
            let metadata: UInt8
            if state.kind == .detectorRail {
                metadata = occupied ? state.metadata | 8 : state.metadata & 7
            } else {
                metadata = occupied ? 1 : 0
                changes.events = [
                    .sound(
                        name: "random.click", position: p.center + SIMD3(0, -0.4, 0), volume: 0.3,
                        pitch: occupied ? 0.6 : 0.5)
                ]
            }
            world.setBlock(BlockState(state.kind, metadata: metadata), at: p)
            changes.positions = [p]
        }
        if occupied { schedule(p, kind: state.kind, after: 20) }
        return changes
    }

    private mutating func schedule(_ p: BlockPosition, kind: BlockKind, after delay: Int64) {
        let key = TickKey(position: p, kind: kind)
        guard pending[key] == nil else { return }
        pending[key] = ScheduledTick(key: key, time: currentTime + delay, order: nextOrder)
        nextOrder &+= 1
    }

    private mutating func scheduleIfNeeded(_ p: BlockPosition, state: BlockState) {
        switch state.kind {
        case .water: schedule(p, kind: state.kind, after: 5)
        case .lava: schedule(p, kind: state.kind, after: 30)
        case .sand, .gravel: schedule(p, kind: state.kind, after: 3)
        case .fire: schedule(p, kind: state.kind, after: 40)
        case .stonePressurePlate,
            .woodenPressurePlate where state.metadata != 0:
            schedule(p, kind: state.kind, after: 20)
        case .detectorRail where state.metadata & 8 != 0: schedule(p, kind: state.kind, after: 20)
        case .stoneButton where state.metadata & 8 != 0: schedule(p, kind: state.kind, after: 20)
        case .litRedstoneOre: schedule(p, kind: state.kind, after: 30)
        default: break
        }
    }

    private mutating func discoverChunks(world: inout BlockWorld) {
        knownChunks.formIntersection(Set(world.chunks.keys))
        let added = world.chunks.keys.filter { !knownChunks.contains($0) }.sorted {
            $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x
        }
        for chunk in added {
            knownChunks.insert(chunk)
            var states: [(BlockPosition, BlockState)] = []
            world.forEachBlock(in: chunk) { states.append(($0, $1)) }
            for (p, state) in states {
                if RailSimulation.isRail(state.kind) { knownRails[p] = state.kind }
                if [.stonePressurePlate, .woodenPressurePlate, .detectorRail].contains(state.kind) {
                    pressurePlates.insert(p)
                }
                if world.blockEntity(at: p) == nil, let tile = BlockEntity.initial(for: state) {
                    world.setBlockEntity(tile, at: p)
                }
            }
        }
    }

    private mutating func updatePower(around positions: [BlockPosition], world: inout BlockWorld)
        -> BlockGrowth.Changes
    {
        var result = BlockGrowth.Changes()
        var nearby: Set<BlockPosition> = []
        for p in positions {
            for x in -1...1 {
                for y in -2...2 {
                    for z in -1...1 { nearby.insert(p.adding(BlockPosition(x, y, z))) }
                }
            }
        }
        let wires = BlockPower.recalculateWires(
            around: nearby.filter { world[$0] == .redstoneWire }, world: &world)
        result.positions += wires
        for wire in wires {
            nearby.insert(wire)
            for offset in BlockPosition.neighbors { nearby.insert(wire.adding(offset)) }
        }
        result.positions += RailSimulation.recalculatePower(
            around: nearby.filter { world[$0] == .poweredRail }, world: &world)
        for p in nearby.sorted(by: { a, b in
            if a.x != b.x { return a.x < b.x }
            if a.y != b.y { return a.y < b.y }
            return a.z < b.z
        }) {
            guard let state = world.state(at: p) else {
                knownRails.removeValue(forKey: p)
                poweredDevices.remove(p)
                continue
            }
            switch state.kind {
            case .rail:
                if RailSimulation.neighborCount(at: p, world: world) == 3 {
                    result.positions += RailSimulation.updateTopology(at: p, world: &world, force: false)
                }
            case .redstoneTorch, .redstoneTorchOff:
                let input = BlockPower.torchInput(at: p, state: state, world: world)
                if input == (state.kind == .redstoneTorch) { schedule(p, kind: state.kind, after: 2) }
            case .repeaterOff, .repeaterOn:
                let input = BlockPower.repeaterInput(at: p, state: state, world: world)
                if input != (state.kind == .repeaterOn) {
                    schedule(p, kind: state.kind, after: Int64(((state.metadata & 12) >> 2) + 1) * 2)
                }
            case .piston, .stickyPiston:
                let piston = PistonSimulation.update(at: p, world: &world, random: &random)
                result.positions += piston.positions
                result.events += piston.events
            case .woodenDoor, .ironDoor, .trapdoor:
                let lower =
                    state.kind != .trapdoor && state.metadata & 8 != 0 ? p.adding(BlockPosition(0, -1, 0)) : p
                let powered =
                    BlockPower.isPowered(at: lower, in: world)
                    || (state.kind != .trapdoor
                        && BlockPower.isPowered(at: lower.adding(BlockPosition(0, 1, 0)), in: world))
                if powered != poweredDevices.contains(lower), let bottom = world.state(at: lower) {
                    let data = powered ? bottom.metadata | 4 : bottom.metadata & ~4
                    world.setBlock(BlockState(bottom.kind, metadata: data), at: lower)
                    result.positions.append(lower)
                    if bottom.kind != .trapdoor {
                        let upper = lower.adding(BlockPosition(0, 1, 0))
                        if world[upper] == bottom.kind {
                            world.setBlock(BlockState(bottom.kind, metadata: data | 8), at: upper)
                            result.positions.append(upper)
                        }
                    }
                    result.events.append(BlockInteractions.sound("random.door_open", at: lower))
                }
                if powered { poweredDevices.insert(lower) } else { poweredDevices.remove(lower) }
            case .dispenser, .noteBlock:
                let powered =
                    BlockPower.isPowered(at: p, in: world)
                    || (state.kind == .dispenser
                        && BlockPower.isPowered(at: p.adding(BlockPosition(0, 1, 0)), in: world))
                if powered && !poweredDevices.contains(p) {
                    if state.kind == .dispenser {
                        schedule(p, kind: .dispenser, after: 4)
                    } else if case .note(let pitch) = world.blockEntity(at: p),
                        world[p.adding(BlockPosition(0, 1, 0))] == nil
                    {
                        result.events.append(BlockInteractions.noteSound(at: p, pitch: pitch, world: world))
                    }
                }
                if powered { poweredDevices.insert(p) } else { poweredDevices.remove(p) }
            case .tnt:
                if BlockPower.isPowered(at: p, in: world) {
                    world.setBlock(nil, at: p)
                    result.positions.append(p)
                    result.events.append(
                        .spawnEntity(
                            kind: "PrimedTnt", position: p.center - SIMD3(0, Double(Float(0.98)) / 2, 0)))
                }
            case .stonePressurePlate, .woodenPressurePlate, .detectorRail: pressurePlates.insert(p)
            default: break
            }
        }
        return result
    }

    private mutating func powerTick(at p: BlockPosition, state: BlockState, world: inout BlockWorld)
        -> BlockGrowth.Changes
    {
        var result = BlockGrowth.Changes()
        if state.kind == .redstoneTorch || state.kind == .redstoneTorchOff {
            torchBurnouts[p, default: []].removeAll { currentTime - $0 > 100 }
            let input = BlockPower.torchInput(at: p, state: state, world: world)
            if state.kind == .redstoneTorch && input {
                world.setBlock(BlockState(.redstoneTorchOff, metadata: state.metadata), at: p)
                torchBurnouts[p, default: []].append(currentTime)
                result.positions = [p]
                if (torchBurnouts[p]?.count ?? 0) >= 8 {
                    result.events = [BlockInteractions.sound("random.fizz", at: p)]
                }
            } else if state.kind == .redstoneTorchOff && !input && (torchBurnouts[p]?.count ?? 0) < 8 {
                world.setBlock(BlockState(.redstoneTorch, metadata: state.metadata), at: p)
                result.positions = [p]
            }
        } else {
            let input = BlockPower.repeaterInput(at: p, state: state, world: world)
            if state.kind == .repeaterOn && !input {
                world.setBlock(BlockState(.repeaterOff, metadata: state.metadata), at: p)
                result.positions = [p]
            } else if state.kind == .repeaterOff {
                world.setBlock(BlockState(.repeaterOn, metadata: state.metadata), at: p)
                result.positions = [p]
            }
        }
        return result
    }

    private mutating func dispense(at p: BlockPosition, world: inout BlockWorld) -> [BlockEvent] {
        guard
            BlockPower.isPowered(at: p, in: world)
                || BlockPower.isPowered(at: p.adding(BlockPosition(0, 1, 0)), in: world),
            case .dispenser(var slots) = world.blockEntity(at: p)
        else { return [] }
        var selected: Int?
        var seen = 0
        for index in slots.indices where slots[index]?.isEmpty == false {
            seen += 1
            if random.nextInt(bound: seen) == 0 { selected = index }
        }
        guard let selected, var stack = slots[selected] else {
            return [BlockInteractions.sound("random.click", at: p, pitch: 1.2)]
        }
        let data = Int(world.state(at: p)?.metadata ?? 3)
        let offset = BlockPower.directions[(2...5).contains(data) ? data : 3]
        let direction = SIMD3(Double(offset.x), 0, Double(offset.z))
        let origin = p.center + direction * 0.6
        let event: BlockEvent
        switch stack.id {
        case 262, 332, 344:
            var velocity = direction + SIMD3(0, Double(Float(0.1)), 0)
            let length = Double(
                Float(sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)))
            velocity /= length
            for axis in 0..<3 { velocity[axis] += random.nextGaussian() * Double(Float(0.0075)) * 6 }
            velocity *= Double(Float(1.1))
            let kind: String
            switch stack.id {
            case 262: kind = "Arrow"
            case 332: kind = "Snowball"
            default: kind = "ThrownEgg"
            }
            event = .projectile(kind: kind, position: origin, velocity: velocity)
        default:
            var velocity = direction * (random.nextDouble() * 0.1 + 0.2)
            velocity.y = Double(Float(0.2))
            for axis in 0..<3 { velocity[axis] += random.nextGaussian() * Double(Float(0.0075)) * 6 }
            event = .dropItemMoving(
                position: origin - SIMD3(0, 0.3, 0),
                stack: ItemStack(id: stack.id, damage: stack.damage), velocity: velocity)
        }
        stack.count -= 1
        slots[selected] = stack.count > 0 ? stack : nil
        world.setBlockEntity(.dispenser(slots: slots), at: p)
        return [
            event,
            BlockInteractions.sound(
                [262, 332, 344].contains(stack.id) ? "random.bow" : "random.click", at: p),
        ]
    }

    private mutating func remove(at p: BlockPosition, world: inout BlockWorld) -> [BlockEvent] {
        guard let state = world.state(at: p) else { return [] }
        var events: [BlockEvent] = []
        if let tile = world.blockEntity(at: p) { events += containerDrops(tile, at: p) }
        let drops = BlockMining.explosionDrops(for: state, roll: { random.nextInt(bound: $0) })
        events += drops.map { .dropItem(position: p.center, stack: $0) }
        world.setBlock(nil, at: p)
        return events
    }

    private mutating func markLeaves(near p: BlockPosition, world: inout BlockWorld) {
        for x in -4...4 {
            for y in -4...4 {
                for z in -4...4 {
                    let target = p.adding(BlockPosition(x, y, z))
                    if let state = world.state(at: target), state.kind == .leaves && state.metadata & 8 == 0 {
                        world.setBlock(BlockState(.leaves, metadata: state.metadata | 8), at: target)
                    }
                }
            }
        }
    }

    private func falling(at p: BlockPosition, state: BlockState, world: inout BlockWorld)
        -> BlockGrowth.Changes
    {
        var result = BlockGrowth.Changes()
        func canFall(_ p: BlockPosition) -> Bool {
            let kind = world[p]
            return kind == nil || kind == .fire || kind?.isLiquid == true
        }
        guard canFall(p.adding(BlockPosition(0, -1, 0))) else { return result }
        let loaded = (((p.x - 32) >> 4)...((p.x + 32) >> 4)).allSatisfy { x in
            (((p.z - 32) >> 4)...((p.z + 32) >> 4)).allSatisfy { z in world.chunks[ChunkPosition(x, z)] != nil
            }
        }
        world.setBlock(nil, at: p)
        result.positions.append(p)
        if loaded {
            result.events = [
                .spawnEntity(
                    kind: "FallingSand:\(state.kind.rawValue):\(state.metadata)",
                    position: p.center - SIMD3(0, Double(Float(0.98)) / 2, 0))
            ]
        } else {
            var target = p
            while target.y > 0 && canFall(target.adding(BlockPosition(0, -1, 0))) { target.y -= 1 }
            if target.y > 0 {
                world.setBlock(state, at: target)
                result.positions.append(target)
            }
        }
        return result
    }

    private mutating func tickTiles(world: inout BlockWorld, players: [SIMD3<Double>], entities: [GameEntity])
        -> [BlockEvent]
    {
        var events: [BlockEvent] = []
        var spawnedMobs: [GameEntity] = []
        let positions = world.chunks.values.flatMap { $0.blockEntities.keys }.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        for p in positions {
            guard let tile = world.blockEntity(at: p) else { continue }
            switch tile {
            case .furnace(var state):
                state.tick()
                if BlockEntity.furnace(state) != tile { world.setBlockEntity(.furnace(state), at: p) }
                if let block = world.state(at: p), block.kind == .furnace || block.kind == .burningFurnace {
                    let kind: BlockKind = state.isBurning ? .burningFurnace : .furnace
                    if block.kind != kind {
                        world.setBlock(BlockState(kind, metadata: block.metadata), at: p)
                    }
                }
            case .spawner(let mobID, let delay):
                guard players.contains(where: { distanceSquared($0, p.center) < 256 }) else { continue }
                if delay < 0 {
                    world.setBlockEntity(
                        .spawner(mobID: mobID, delay: 199 + random.nextInt(bound: 600)), at: p)
                } else if delay > 0 {
                    world.setBlockEntity(.spawner(mobID: mobID, delay: delay - 1), at: p)
                } else {
                    var spawned = false
                    let area = AxisAlignedBox(
                        min: p.center - SIMD3(8.5, 4.5, 8.5), max: p.center + SIMD3(8.5, 4.5, 8.5))
                    let kind = GameEntity.canonicalKind(mobID)
                    var population = (entities + spawnedMobs).filter {
                        $0.health > 0 && $0.kind == kind && $0.bounds.intersects(area)
                    }.count
                    for _ in 0..<4 {
                        if population >= 6 {
                            spawned = true
                            break
                        }
                        let target =
                            p.center
                            + SIMD3(
                                (random.nextDouble() - random.nextDouble()) * 4,
                                Double(random.nextInt(bound: 3) - 1) - 0.5,
                                (random.nextDouble() - random.nextDouble()) * 4)
                        _ = random.nextFloat()
                        let cell = BlockPosition(
                            Int(floor(target.x)), Int(floor(target.y)), Int(floor(target.z)))
                        let probe = GameEntity(id: 0, kind: mobID, position: target)
                        guard probe.isLiving, spawnAllowed(probe, at: cell, world: world),
                            BlockCollision.boxes(in: world, intersecting: probe.bounds).isEmpty,
                            !(entities + spawnedMobs).contains(where: {
                                $0.health > 0 && $0.bounds.intersects(probe.bounds)
                            }),
                            !players.contains(where: { player in
                                AxisAlignedBox(
                                    min: player - SIMD3(0.3, 0, 0.3), max: player + SIMD3(0.3, 1.8, 0.3)
                                ).intersects(probe.bounds)
                            })
                        else { continue }
                        events.append(.spawnEntity(kind: mobID, position: target))
                        spawnedMobs.append(probe)
                        population += 1
                        spawned = true
                    }
                    let next = spawned ? 200 + random.nextInt(bound: 600) : 0
                    world.setBlockEntity(.spawner(mobID: mobID, delay: next), at: p)
                }
            default: break
            }
        }
        return events
    }

    private mutating func spawnAllowed(_ entity: GameEntity, at p: BlockPosition, world: BlockWorld) -> Bool {
        guard world.chunks[p.chunk] != nil, (1..<127).contains(p.y) else { return false }
        if entity.kind == "squid" {
            return p.y > 45 && p.y < 63 && BlockPlacement.isWater(world[p])
        }
        if entity.kind == "ghast" { return random.nextInt(bound: 20) == 0 }
        guard world[p] == nil, world[p.adding(BlockPosition(0, -1, 0))]?.isNormalCube == true else {
            return false
        }
        if ["pig", "cow", "sheep", "chicken", "wolf"].contains(entity.kind) {
            return world[p.adding(BlockPosition(0, -1, 0))] == .grass
                && BlockGrowth.light(at: p, world: world, time: currentTime, weather: weather) > 8
        }
        if entity.kind == "slime" {
            let x = Int64(Int32(truncatingIfNeeded: p.chunk.x))
            let z = Int64(Int32(truncatingIfNeeded: p.chunk.z))
            var slimeRandom = JavaRandom(
                seed: (world.seed &+ x &* x &* 4_987_142 &+ x &* 5_947_611
                    &+ z &* z &* 4_392_871 &+ z &* 389_711) ^ 987_234_911)
            return p.y < 16 && random.nextInt(bound: 10) == 0 && slimeRandom.nextInt(bound: 10) == 0
        }
        if ["zombie", "skeleton", "creeper", "spider"].contains(entity.kind) {
            if Int(world.light(at: p).sky) > random.nextInt(bound: 32) { return false }
            return BlockGrowth.light(at: p, world: world, time: currentTime, weather: weather)
                <= random.nextInt(bound: 8)
        }
        return true
    }

    private func distanceSquared(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let difference = a - b
        return difference.x * difference.x + difference.y * difference.y + difference.z * difference.z
    }
}
