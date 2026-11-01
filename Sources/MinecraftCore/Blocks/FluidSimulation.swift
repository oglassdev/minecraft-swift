enum FluidSimulation {
    typealias ScheduleHandler = (BlockPosition, inout BlockWorld, inout JavaRandom) -> Void

    final class FlowContext {
        var water = Array(repeating: false, count: 4)
        var lava = Array(repeating: false, count: 4)
    }

    enum TickEvent {
        case schedule(BlockPosition)
        case notify(BlockPosition)
    }

    struct Tick {
        private enum Phase {
            case start, changedSchedule, changedNotify, changedFinish
            case spread, horizontal, flowNotify, flowFinish, done
        }

        private let position: BlockPosition
        private var phase = Phase.start
        private var water = false
        private var increase = 1
        private var level = 0
        private var nextLevel = 0
        private var direction = 0
        private var preferred = Array(repeating: false, count: 4)
        private var flowPosition = BlockPosition(0, 0, 0)
        private var continueHorizontally = false
        private(set) var result = BlockGrowth.Changes()

        init(at position: BlockPosition) { self.position = position }

        mutating func resume(
            world: inout BlockWorld, random: inout JavaRandom, flowContext: FlowContext?
        ) -> TickEvent? {
            while true {
                switch phase {
                case .start:
                    guard let state = world.state(at: position), state.kind == .water || state.kind == .lava
                    else {
                        phase = .done
                        return nil
                    }
                    water = state.kind == .water
                    increase = water || world.dimension == -1 ? 1 : 2
                    level = Int(state.metadata)
                    if level > 0 {
                        var minimum = -100
                        var sources = 0
                        for offset in BlockPosition.horizontal {
                            var neighbor = FluidSimulation.depth(
                                at: position.adding(offset), water: water, world: world)
                            if neighbor < 0 { continue }
                            if neighbor == 0 { sources += 1 }
                            if neighbor >= 8 { neighbor = 0 }
                            if minimum < 0 || neighbor < minimum { minimum = neighbor }
                        }
                        var next = minimum + increase
                        if next >= 8 || minimum < 0 { next = -1 }
                        let above = FluidSimulation.depth(
                            at: position.adding(BlockPosition(0, 1, 0)), water: water, world: world)
                        if above >= 0 { next = above >= 8 ? above : above + 8 }
                        if sources >= 2 && water
                            && world[position.adding(BlockPosition(0, -1, 0))]?.isMaterialSolid == true
                        {
                            next = 0
                        }
                        var settle = true
                        if !water && level < 8 && next < 8 && next > level && random.nextInt(bound: 4) != 0 {
                            next = level
                            settle = false
                        }
                        if next != level {
                            level = next
                            world.setBlock(
                                next < 0 ? nil : BlockState(state.kind, metadata: UInt8(next)), at: position)
                            phase = next >= 0 ? .changedSchedule : .changedFinish
                            return .notify(position)
                        } else if settle {
                            world.setBlock(
                                BlockState(water ? .stillWater : .stillLava, metadata: UInt8(level)),
                                at: position)
                        }
                    } else {
                        world.setBlock(
                            BlockState(water ? .stillWater : .stillLava, metadata: UInt8(level)), at: position
                        )
                    }
                    phase = .spread
                case .changedSchedule:
                    phase = .changedNotify
                    return .schedule(position)
                case .changedNotify:
                    phase = .changedFinish
                    return .notify(position)
                case .changedFinish:
                    result.positions.append(position)
                    phase = .spread
                case .spread:
                    let below = position.adding(BlockPosition(0, -1, 0))
                    if FluidSimulation.canFlow(into: below, water: water, world: world) {
                        continueHorizontally = false
                        return beginFlow(
                            into: below, level: level >= 8 ? level : level + 8, world: &world, random: &random
                        )
                    }
                    guard level >= 0 && (level == 0 || FluidSimulation.blocksFlow(at: below, world: world))
                    else {
                        phase = .done
                        return nil
                    }
                    nextLevel = level >= 8 ? 1 : level + increase
                    guard nextLevel < 8 else {
                        phase = .done
                        return nil
                    }
                    let costs = BlockPosition.horizontal.enumerated().map { index, offset -> Int in
                        let target = position.adding(offset)
                        if FluidSimulation.blocksFlow(at: target, world: world)
                            || FluidSimulation.depth(at: target, water: water, world: world) == 0
                        {
                            return 1000
                        }
                        if !FluidSimulation.blocksFlow(
                            at: target.adding(BlockPosition(0, -1, 0)), world: world)
                        {
                            return 0
                        }
                        return FluidSimulation.pathCost(
                            at: target, distance: 1, from: index, water: water, world: world)
                    }
                    let minimum = costs.min() ?? 1000
                    preferred = costs.map { $0 == minimum }
                    if water { flowContext?.water = preferred } else { flowContext?.lava = preferred }
                    direction = 0
                    phase = .horizontal
                case .horizontal:
                    while direction < 4 {
                        let index = direction
                        direction += 1
                        let selected =
                            flowContext.map { water ? $0.water[index] : $0.lava[index] } ?? preferred[index]
                        if !selected { continue }
                        let target = position.adding(BlockPosition.horizontal[index])
                        if FluidSimulation.canFlow(into: target, water: water, world: world) {
                            continueHorizontally = true
                            return beginFlow(into: target, level: nextLevel, world: &world, random: &random)
                        }
                    }
                    phase = .done
                    return nil
                case .flowNotify:
                    phase = .flowFinish
                    return .notify(flowPosition)
                case .flowFinish:
                    result.positions.append(flowPosition)
                    phase = continueHorizontally ? .horizontal : .done
                case .done:
                    return nil
                }
            }
        }

        private mutating func beginFlow(
            into target: BlockPosition, level: Int, world: inout BlockWorld, random: inout JavaRandom
        ) -> TickEvent {
            FluidSimulation.flow(
                into: target, level: level, water: water, world: &world, random: &random, result: &result)
            flowPosition = target
            phase = .flowNotify
            return .schedule(target)
        }
    }

    static func tick(
        at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom,
        onSchedule: ScheduleHandler? = nil, onNotify: ScheduleHandler? = nil,
        flowContext: FlowContext? = nil
    ) -> BlockGrowth.Changes {
        var tick = Tick(at: p)
        while let event = tick.resume(world: &world, random: &random, flowContext: flowContext) {
            switch event {
            case .schedule(let position): onSchedule?(position, &world, &random)
            case .notify(let position): onNotify?(position, &world, &random)
            }
        }
        return tick.result
    }

    static func mix(at p: BlockPosition, world: inout BlockWorld) -> BlockGrowth.Changes {
        var result = BlockGrowth.Changes()
        guard let state = world.state(at: p), state.kind == .lava || state.kind == .stillLava else {
            return result
        }
        if (BlockPosition.horizontal + [BlockPosition(0, 1, 0)]).contains(where: {
            BlockPlacement.isWater(world[p.adding($0)])
        }) {
            if state.metadata == 0 {
                world[p] = .obsidian
                result.positions = [p]
            } else if state.metadata <= 4 {
                world[p] = .cobblestone
                result.positions = [p]
            }
            result.events = [BlockInteractions.sound("random.fizz", at: p)]
        }
        return result
    }

    private static func depth(at p: BlockPosition, water: Bool, world: BlockWorld) -> Int {
        guard let state = world.state(at: p), sameMaterial(state.kind, water: water) else { return -1 }
        return Int(state.metadata)
    }

    private static func sameMaterial(_ kind: BlockKind, water: Bool) -> Bool {
        water ? BlockPlacement.isWater(kind) : (kind == .lava || kind == .stillLava)
    }

    private static func blocksFlow(at p: BlockPosition, world: BlockWorld) -> Bool {
        guard (0..<128).contains(p.y), world.chunks[p.chunk] != nil else { return true }
        guard let kind = world[p] else { return false }
        if [.woodenDoor, .ironDoor, .standingSign, .ladder, .sugarCane].contains(kind) { return true }
        return kind.isMaterialSolid
    }

    private static func canFlow(into p: BlockPosition, water: Bool, world: BlockWorld) -> Bool {
        if let kind = world[p], sameMaterial(kind, water: water) || kind == .lava || kind == .stillLava {
            return false
        }
        return !blocksFlow(at: p, world: world)
    }

    private static func flow(
        into p: BlockPosition, level: Int, water: Bool, world: inout BlockWorld,
        random: inout JavaRandom, result: inout BlockGrowth.Changes
    ) {
        if let state = world.state(at: p) {
            if water {
                for stack in BlockMining.explosionDrops(for: state, roll: { random.nextInt(bound: $0) }) {
                    for _ in 0..<stack.count {
                        _ = random.nextFloat()
                        let offset = SIMD3(
                            Double(random.nextFloat() * 0.7 + 0.15),
                            Double(random.nextFloat() * 0.7 + 0.15), Double(random.nextFloat() * 0.7 + 0.15))
                        let origin = SIMD3(Double(p.x), Double(p.y), Double(p.z))
                        result.events.append(
                            .dropItem(
                                position: origin + offset,
                                stack: ItemStack(id: stack.id, damage: stack.damage)))
                    }
                }
            } else {
                result.events.append(BlockInteractions.sound("random.fizz", at: p))
            }
        }
        world.setBlock(BlockState(water ? .water : .lava, metadata: UInt8(max(0, level))), at: p)
    }

    private static func pathCost(
        at p: BlockPosition, distance: Int, from: Int, water: Bool, world: BlockWorld
    ) -> Int {
        var cost = 1000
        for (index, offset) in BlockPosition.horizontal.enumerated() where index != (from ^ 1) {
            let target = p.adding(offset)
            if blocksFlow(at: target, world: world) || depth(at: target, water: water, world: world) == 0 {
                continue
            }
            if !blocksFlow(at: target.adding(BlockPosition(0, -1, 0)), world: world) { return distance }
            if distance < 4 {
                cost = min(
                    cost,
                    pathCost(at: target, distance: distance + 1, from: index, water: water, world: world))
            }
        }
        return cost
    }
}
