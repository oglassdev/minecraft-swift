import Foundation

public struct BlockSimulation: Sendable {
    private var random: JavaRandom
    private var defaultTickState: WorldTickState
    private var pending = ScheduledBlockTickQueue()
    private var nextOrder: Int64 = 0
    public var scheduledTicks: [ScheduledBlockTick] { pending.ordered }
    private var knownChunks: Set<ChunkPosition> = []
    private var currentTime: Int64 = 0
    private var weather: WorldWeather?
    private var poweredDevices: Set<BlockPosition> = []
    private var pressurePlates: Set<BlockPosition> = []
    private var torchBurnouts: [BlockPosition: [Int64]] = [:]
    private var knownRails: [BlockPosition: BlockKind] = [:]
    private var containerRandoms: [BlockKind: JavaRandom] = [:]
    private var wireUpdates = BlockPower.WireUpdates()

    private enum NotificationContinuation: Sendable {
        case wireHook(BlockPosition, stage: Int, removedMetadata: UInt8?)
        case wireNearby(BlockPosition)
        case wireCalculate(BlockPosition, previousMetadata: UInt8?)
    }

    private typealias Notifications = BlockNotificationStack<NotificationContinuation>

    private static let randomTickKinds: [Bool] = {
        var kinds = [Bool](repeating: false, count: 256)
        for id in [
            2, 6, 8, 10, 11, 18, 28, 31, 32, 37, 38, 39, 40, 50, 51, 59, 60, 70, 72, 74,
            75, 76, 77, 78, 79, 80, 81, 83, 86, 91, 92, 95,
        ] { kinds[id] = true }
        return kinds
    }()

    public init(seed: Int64) {
        random = JavaRandom(seed: seed)
        let updateLCG = random.nextInt()
        defaultTickState = WorldTickState(random: random, updateLCG: updateLCG, caveSoundCooldown: 12000)
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

    public mutating func containerDrops(_ tile: BlockEntity, at p: BlockPosition, kind: BlockKind? = nil)
        -> [BlockEvent]
    {
        let block: BlockKind
        switch tile {
        case .chest: block = kind ?? .chest
        case .furnace: block = kind ?? .furnace
        case .dispenser: block = kind ?? .dispenser
        default: return BlockInteractions.containerDrops(tile, at: p, random: &random)
        }
        var blockRandom = containerRandoms[block] ?? JavaRandom(seed: Int64.random(in: .min ... .max))
        let events = BlockInteractions.containerDrops(tile, at: p, random: &blockRandom)
        containerRandoms[block] = blockRandom
        return events
    }

    @discardableResult
    public mutating func blockChanged(at p: BlockPosition, world: inout BlockWorld, time: Int64)
        -> [BlockEvent]
    {
        var notifications = Notifications()
        notifications.added(at: p, state: world.state(at: p))
        return drainNotifications(&notifications, world: &world, time: time)
    }

    @discardableResult
    public mutating func blockChanged(
        at p: BlockPosition, previousState: BlockState?, metadataOnly: Bool = false,
        world: inout BlockWorld, time: Int64
    ) -> [BlockEvent] {
        var notifications = Notifications()
        if metadataOnly {
            let state = world.state(at: p)
            pushControlNotifications(at: p, state: state, onto: &notifications)
            notifications.notify(at: p, changedKind: state?.kind ?? .air)
        } else {
            notifications.changed(at: p, previous: previousState, current: world.state(at: p))
        }
        return drainNotifications(&notifications, world: &world, time: time)
    }

    private mutating func drainNotifications(
        _ notifications: inout Notifications, world: inout BlockWorld, time: Int64
    ) -> [BlockEvent] {
        currentTime = time
        var events: [BlockEvent] = []
        while let step = notifications.next() {
            let position: BlockPosition
            let state: BlockState
            let neighbor: Bool
            switch step {
            case .continuation(let continuation):
                continueNotification(continuation, notifications: &notifications, world: &world)
                continue
            case .removed(let p, let old):
                knownRails.removeValue(forKey: p)
                poweredDevices.remove(p)
                pressurePlates.remove(p)
                if old.kind == .redstoneWire {
                    notifications.push(.wireHook(p, stage: 0, removedMetadata: old.metadata))
                } else if old.kind == .redstoneTorch {
                    pushTorchNotifications(at: p, onto: &notifications)
                } else if old.metadata & 8 != 0 {
                    pushControlNotifications(at: p, state: old, onto: &notifications)
                    if old.kind == .lever || old.kind == .stoneButton {
                        notifications.notify(at: p, changedKind: old.kind)
                    }
                }
                continue
            case .added(let p, let added):
                position = p
                state = BlockState(added.kind, metadata: world.state(at: p)?.metadata ?? added.metadata)
                neighbor = false
            case .neighbor(let p, _):
                guard let current = world.state(at: p) else {
                    knownRails.removeValue(forKey: p)
                    poweredDevices.remove(p)
                    pressurePlates.remove(p)
                    continue
                }
                position = p
                state = current
                neighbor = true
            }
            if state.kind == .fire && world[position.adding(BlockPosition(0, -1, 0))] == .obsidian {
                let portal = PortalFormation.form(at: position, world: &world)
                if !portal.isEmpty {
                    for changed in portal.reversed() {
                        notifications.added(at: changed, state: world.state(at: changed))
                    }
                    continue
                }
            }
            if neighbor && state.kind == .farmland,
                world[position.adding(BlockPosition(0, 1, 0))]?.isMaterialSolid == true
            {
                world[position] = .dirt
                notifications.changed(at: position, previous: state, current: BlockState(.dirt))
                continue
            }
            if !BlockPlacement.canRemain(state, at: position, in: world)
                || (neighbor && !BlockGrowth.hasRequiredLight(state, at: position, world: world))
            {
                events += remove(at: position, world: &world)
                notifications.changed(at: position, previous: state, current: nil)
                continue
            }
            if state.kind == .redstoneWire {
                if neighbor {
                    notifications.push(.wireCalculate(position, previousMetadata: nil))
                } else {
                    notifications.push(.wireHook(position, stage: 0, removedMetadata: nil))
                }
                continue
            }
            if RailSimulation.isRail(state.kind), knownRails[position] != state.kind {
                knownRails[position] = state.kind
                for changed in RailSimulation.updateTopology(at: position, world: &world, force: true)
                    .reversed()
                {
                    notifications.notify(at: changed, changedKind: world[changed] ?? .air)
                }
            }
            if state.kind.isLiquid {
                let mixed = FluidSimulation.mix(at: position, world: &world)
                events += mixed.events
                if !mixed.positions.isEmpty {
                    notifications.changed(at: position, previous: state, current: world.state(at: position))
                    continue
                }
                let flowing: BlockKind = BlockPlacement.isWater(state.kind) ? .water : .lava
                if state.kind != flowing && neighbor {
                    world.setBlock(BlockState(flowing, metadata: state.metadata), at: position)
                }
                if world[position] == flowing {
                    schedule(position, kind: flowing, after: flowing == .water ? 5 : 30, world: world)
                }
            } else if !neighbor || state.kind == .sand || state.kind == .gravel {
                scheduleIfNeeded(position, state: state, world: world)
            }
            if world.blockEntity(at: position) == nil, let tile = BlockEntity.initial(for: state) {
                world.setBlockEntity(tile, at: position)
            }
            let power = updatePower(at: position, state: state, world: &world)
            events += power.events
            for changed in power.positions.reversed() {
                notifications.added(at: changed, state: world.state(at: changed))
            }
            if !neighbor {
                switch state.kind {
                case .redstoneTorch: pushTorchNotifications(at: position, onto: &notifications)
                case .repeaterOff, .repeaterOn:
                    for offset in [
                        BlockPosition(1, 0, 0), BlockPosition(-1, 0, 0),
                        BlockPosition(0, 0, 1), BlockPosition(0, 0, -1),
                        BlockPosition(0, -1, 0), BlockPosition(0, 1, 0),
                    ].reversed() {
                        notifications.notify(at: position.adding(offset), changedKind: state.kind)
                    }
                default: pushControlNotifications(at: position, state: state, onto: &notifications)
                }
            }
        }
        return events
    }

    private mutating func continueNotification(
        _ continuation: NotificationContinuation, notifications: inout Notifications,
        world: inout BlockWorld
    ) {
        switch continuation {
        case .wireCalculate(let p, let previousMetadata):
            let result = wireUpdates.update(at: p, world: &world, previousMetadata: previousMetadata)
            for origin in result.notifyOrigins.reversed() {
                notifications.notify(at: origin, changedKind: .redstoneWire)
            }
        case .wireNearby(let p):
            guard world[p] == .redstoneWire else { return }
            for offset in [
                BlockPosition(0, 0, 0), BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
                BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
                BlockPosition(0, -1, 0), BlockPosition(0, 1, 0),
            ].reversed() {
                notifications.notify(at: p.adding(offset), changedKind: .redstoneWire)
            }
        case .wireHook(let p, let stage, let removedMetadata):
            let removed = removedMetadata != nil
            if stage < 11 {
                notifications.push(.wireHook(p, stage: stage + 1, removedMetadata: removedMetadata))
            }
            switch stage {
            case 0 where !removed, 2 where removed:
                notifications.push(.wireCalculate(p, previousMetadata: removedMetadata))
            case 0,
                1 where !removed:
                notifications.notify(at: p.adding(BlockPosition(0, 1, 0)), changedKind: .redstoneWire)
            case 1, 2:
                notifications.notify(at: p.adding(BlockPosition(0, -1, 0)), changedKind: .redstoneWire)
            case 3...6:
                notifications.push(.wireNearby(p.adding(Self.wireHorizontal[stage - 3])))
            case 7...10:
                let neighbor = p.adding(Self.wireHorizontal[stage - 7])
                let y = world[neighbor]?.isNormalCube == true ? 1 : -1
                notifications.push(.wireNearby(neighbor.adding(BlockPosition(0, y, 0))))
            default: break
            }
        }
    }

    private static let wireHorizontal = [
        BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
        BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
    ]

    private func pushTorchNotifications(at p: BlockPosition, onto notifications: inout Notifications) {
        for offset in [
            BlockPosition(0, -1, 0), BlockPosition(0, 1, 0),
            BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
            BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
        ].reversed() {
            notifications.notify(at: p.adding(offset), changedKind: .redstoneTorch)
        }
    }

    private func pushControlNotifications(
        at p: BlockPosition, state: BlockState?, onto notifications: inout Notifications
    ) {
        guard let state else { return }
        let offset: BlockPosition
        switch state.kind {
        case .lever, .stoneButton:
            switch state.metadata & 7 {
            case 1: offset = BlockPosition(-1, 0, 0)
            case 2: offset = BlockPosition(1, 0, 0)
            case 3: offset = BlockPosition(0, 0, -1)
            case 4: offset = BlockPosition(0, 0, 1)
            default: offset = BlockPosition(0, -1, 0)
            }
        case .stonePressurePlate, .woodenPressurePlate, .detectorRail:
            offset = BlockPosition(0, -1, 0)
        default: return
        }
        notifications.notify(at: p.adding(offset), changedKind: state.kind)
    }

    public mutating func tick(
        world: inout BlockWorld, players: [SIMD3<Double>], time: Int64, entities: [GameEntity] = [],
        weather: WorldWeather? = nil
    ) -> [BlockEvent] {
        var tickState = defaultTickState
        tickState.random = random
        var weather = weather ?? WorldWeather(seed: world.seed)
        let events = tick(
            world: &world, players: players, time: time, entities: entities, weather: &weather,
            tickState: &tickState)
        defaultTickState = tickState
        random = tickState.random
        return events
    }

    public mutating func withWorldRandom<Result>(
        _ worldRandom: inout JavaRandom, _ operation: (inout BlockSimulation) throws -> Result
    ) rethrows -> Result {
        swap(&random, &worldRandom)
        defer { swap(&random, &worldRandom) }
        return try operation(&self)
    }

    public mutating func tick(
        world: inout BlockWorld, players: [SIMD3<Double>], time: Int64, entities: [GameEntity] = [],
        weather: inout WorldWeather, tickState: inout WorldTickState, includeBlockEntities: Bool = true
    ) -> [BlockEvent] {
        let savedRandom = random
        random = tickState.random
        defer {
            tickState.random = random
            random = savedRandom
        }
        currentTime = time
        self.weather = weather
        var events: [BlockEvent] = []
        discoverChunks(world: &world)
        var cycle = pending.beginCycle()
        while let tick = cycle.next(in: &pending, through: time) {
            let p = tick.position
            guard Self.scheduledAreaLoaded(at: p, world: world) else { continue }
            guard let state = world.state(at: p), state.kind == tick.kind else { continue }
            var changes = BlockGrowth.Changes()
            var pulseDelay: Int64?
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
                if state.kind == .repeaterOff && !BlockPower.repeaterInput(at: p, state: state, world: world)
                {
                    pulseDelay = Int64(((state.metadata & 12) >> 2) + 1) * 2
                }
                changes = powerTick(at: p, state: state, world: &world)
            case .dispenser: changes.events = dispense(at: p, world: &world)
            default: break
            }
            events += changes.events
            for changed in changes.positions {
                if changed == p {
                    events += blockChanged(at: changed, previousState: state, world: &world, time: time)
                } else {
                    events += blockChanged(at: changed, world: &world, time: time)
                }
            }
            if let pulseDelay { schedule(p, kind: .repeaterOn, after: pulseDelay, world: world) }
        }
        tickState.prepareActiveChunks(players: players)
        for chunk in tickState.activeChunks where world.chunks[chunk] != nil {
            let environment = weather.tickChunk(
                chunk, world: &world, players: players, tickState: &tickState, random: &random)
            events += environment.events
            for changed in environment.positions {
                events += blockChanged(at: changed, world: &world, time: time)
            }
            // Dropped before each tick so block edits never copy the chunk's storage.
            var blockIDs: [UInt8]?
            for _ in 0..<80 {
                let p = tickState.nextPosition(in: chunk)
                if blockIDs == nil { blockIDs = world.chunks[chunk]?.blockIDs }
                guard let id = blockIDs?[Chunk.index(x: p.x & 15, y: p.y, z: p.z & 15)],
                    Self.randomTickKinds[Int(id)]
                else { continue }
                blockIDs = nil
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
                case .litRedstoneOre:
                    world[p] = .redstoneOre
                    changes = .init(positions: [p])
                default:
                    changes = BlockGrowth.randomTick(
                        at: p, world: &world, random: &random, time: time, weather: weather)
                }
                events += changes.events
                for changed in changes.positions {
                    if changed == p {
                        events += blockChanged(at: changed, previousState: state, world: &world, time: time)
                    } else {
                        events += blockChanged(at: changed, world: &world, time: time)
                    }
                }
            }
        }
        if includeBlockEntities {
            events += tickBlockEntities(world: &world, players: players, entities: entities, time: time)
        }
        return events
    }

    public mutating func tickBlockEntities(
        world: inout BlockWorld, players: [SIMD3<Double>], entities: [GameEntity] = [], time: Int64
    ) -> [BlockEvent] {
        currentTime = time
        discoverChunks(world: &world)
        var events: [BlockEvent] = []
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
        if occupied { schedule(p, kind: state.kind, after: 20, world: world) }
        return changes
    }

    public mutating func scheduleUpdate(
        at position: BlockPosition, kind: BlockKind, after delay: Int64, world: BlockWorld, time: Int64
    ) {
        currentTime = time
        schedule(position, kind: kind, after: delay, world: world)
    }

    private mutating func schedule(_ p: BlockPosition, kind: BlockKind, after delay: Int64, world: BlockWorld)
    {
        let tick = ScheduledBlockTick(
            position: p, kind: kind,
            time: kind == .air ? 0 : currentTime &+ delay, order: nextOrder)
        nextOrder &+= 1
        guard Self.scheduledAreaLoaded(at: p, world: world) else { return }
        pending.insert(tick)
    }

    private static func scheduledAreaLoaded(at p: BlockPosition, world: BlockWorld) -> Bool {
        guard p.y + 8 >= 0, p.y - 8 < 128 else { return false }
        return (((p.x - 8) >> 4)...((p.x + 8) >> 4)).allSatisfy { x in
            (((p.z - 8) >> 4)...((p.z + 8) >> 4)).allSatisfy { z in world.chunks[ChunkPosition(x, z)] != nil }
        }
    }

    private mutating func scheduleIfNeeded(_ p: BlockPosition, state: BlockState, world: BlockWorld) {
        let delay: Int64
        switch state.kind {
        case .water: delay = 5
        case .lava, .litRedstoneOre: delay = 30
        case .sand, .gravel: delay = 3
        case .fire: delay = 40
        case .stonePressurePlate, .woodenPressurePlate:
            guard state.metadata != 0 else { return }
            delay = 20
        case .detectorRail where state.metadata & 8 != 0: delay = 20
        case .stoneButton where state.metadata & 8 != 0: delay = 20
        default: return
        }
        schedule(p, kind: state.kind, after: delay, world: world)
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

    private mutating func updatePower(
        at p: BlockPosition, state: BlockState, world: inout BlockWorld
    ) -> BlockGrowth.Changes {
        var result = BlockGrowth.Changes()
        if state.kind == .poweredRail {
            result.positions += RailSimulation.recalculatePower(around: [p], world: &world)
        }
        switch state.kind {
        case .rail:
            if RailSimulation.neighborCount(at: p, world: world) == 3 {
                result.positions += RailSimulation.updateTopology(at: p, world: &world, force: false)
            }
        case .redstoneTorch, .redstoneTorchOff:
            schedule(p, kind: state.kind, after: 2, world: world)
        case .repeaterOff, .repeaterOn:
            let input = BlockPower.repeaterInput(at: p, state: state, world: world)
            if input != (state.kind == .repeaterOn) {
                schedule(
                    p, kind: state.kind, after: Int64(((state.metadata & 12) >> 2) + 1) * 2, world: world)
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
                    schedule(p, kind: .dispenser, after: 4, world: world)
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
        if let tile = world.blockEntity(at: p) { events += containerDrops(tile, at: p, kind: state.kind) }
        events += BlockDrops.destroy(state, at: p, random: &random)
        world.setBlock(nil, at: p)
        _ = BlockInteractions.didRemove(state, at: p, world: &world)
        return events
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
