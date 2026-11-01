enum PistonSimulation {
    private static let fragile: Set<UInt8> = [
        6, 8, 9, 10, 11, 18, 26, 30, 31, 32, 37, 38, 39, 40, 50, 51, 55, 59,
        64, 65, 69, 70, 71, 72, 75, 76, 77, 78, 81, 83, 86, 91, 92, 93, 94,
    ]
    private static let containers: Set<UInt8> = [23, 25, 52, 54, 61, 62, 63, 68, 84]

    static func update(
        at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom
    ) -> BlockGrowth.Changes {
        guard let state = world.state(at: p), state.kind == .piston || state.kind == .stickyPiston,
            state.metadata != 7, state.metadata & 7 < 6
        else { return .init() }
        let powered = BlockPower.pistonInput(at: p, facing: Int(state.metadata & 7), world: world)
        if powered && state.metadata & 8 == 0 {
            return applyAction(
                at: p, extending: true, facing: state.metadata & 7, world: &world, random: &random)
        }
        if !powered && state.metadata & 8 != 0 {
            return applyAction(
                at: p, extending: false, facing: state.metadata & 7, world: &world, random: &random)
        }
        return .init()
    }

    static func applyAction(
        at p: BlockPosition, extending: Bool, facing: UInt8,
        world: inout BlockWorld, random: inout JavaRandom
    ) -> BlockGrowth.Changes {
        var result = BlockGrowth.Changes()
        guard let base = world.state(at: p), base.kind == .piston || base.kind == .stickyPiston,
            facing < 6
        else { return result }
        let direction = BlockPower.directions[Int(facing)]
        let front = p.adding(direction)
        if extending {
            guard let line = pushLine(from: front, direction: direction, world: world) else { return result }
            if let last = line.last, let state = world.state(at: last), fragile.contains(state.kind.rawValue)
            {
                result.events += BlockDrops.destroy(state, at: last, random: &random)
            }
            var destination = line.last ?? front
            while destination != p {
                let source = destination.adding(BlockPosition(-direction.x, -direction.y, -direction.z))
                let moved: BlockState
                if source == p {
                    moved = BlockState(.pistonHead, metadata: facing | (base.kind == .stickyPiston ? 8 : 0))
                } else {
                    guard let state = world.state(at: source) else { break }
                    moved = state
                }
                world.setBlock(BlockState(.movingPiston, metadata: moved.metadata), at: destination)
                world.setBlockEntity(
                    .piston(PistonState(block: moved, facing: facing, extending: true)), at: destination)
                result.positions.append(destination)
                destination = source
            }
            world.setBlock(BlockState(base.kind, metadata: facing | 8), at: p)
            result.positions.append(p)
            result.events.append(pistonSound("tile.piston.out", at: p, random: &random, range: 0.25))
        } else {
            finishMoving(at: front, world: &world)
            world.setBlock(BlockState(.movingPiston, metadata: facing), at: p)
            world.setBlockEntity(
                .piston(
                    PistonState(
                        block: BlockState(base.kind, metadata: facing), facing: facing,
                        extending: false, isSource: true)), at: p)
            result.positions.append(p)
            if base.kind == .stickyPiston {
                let source = front.adding(direction)
                var block = world.state(at: source)
                var finishedExtendingBlock = false
                if case .piston(let moving) = world.blockEntity(at: source),
                    block?.kind == .movingPiston, moving.facing == facing, moving.extending
                {
                    finishMoving(at: source, world: &world)
                    block = moving.block
                    finishedExtendingBlock = true
                    result.positions.append(source)
                }
                if !finishedExtendingBlock, let block, !fragile.contains(block.kind.rawValue),
                    canPush(block, at: source, world: world)
                {
                    world.setBlock(nil, at: source)
                    world.setBlock(BlockState(.movingPiston, metadata: block.metadata), at: front)
                    world.setBlockEntity(
                        .piston(PistonState(block: block, facing: facing, extending: false)), at: front)
                    result.positions += [source, front]
                } else if !finishedExtendingBlock {
                    world.setBlock(nil, at: front)
                    result.positions.append(front)
                }
            } else {
                world.setBlock(nil, at: front)
                result.positions.append(front)
            }
            result.events.append(pistonSound("tile.piston.in", at: p, random: &random, range: 0.15))
        }
        return result
    }

    static func tick(at p: BlockPosition, world: inout BlockWorld) -> BlockGrowth.Changes {
        var result = BlockGrowth.Changes()
        guard world[p] == .movingPiston, case .piston(var state) = world.blockEntity(at: p) else {
            return result
        }
        state.previousProgress = state.progress
        if state.previousProgress >= 1 {
            if let bounds = displacementBounds(for: state, at: p, progress: 1) {
                result.events = [.displace(bounds: bounds, delta: SIMD3<Double>(state.direction) * 0.25)]
            }
            finishMoving(at: p, world: &world)
            result.positions = [p]
        } else {
            state.progress = min(1, state.progress + 0.5)
            if state.extending,
                let bounds = displacementBounds(for: state, at: p, progress: state.progress)
            {
                let distance = Double(state.progress - state.previousProgress) + 0.0625
                result.events = [.displace(bounds: bounds, delta: SIMD3<Double>(state.direction) * distance)]
            }
            world.setBlockEntity(.piston(state), at: p)
        }
        return result
    }

    @discardableResult
    static func finishMoving(at p: BlockPosition, world: inout BlockWorld) -> BlockState? {
        guard case .piston(let state) = world.blockEntity(at: p) else { return nil }
        world.setBlockEntity(nil, at: p)
        if world[p] == .movingPiston { world.setBlock(state.block, at: p) }
        return state.block
    }

    private static func pushLine(
        from front: BlockPosition, direction: BlockPosition, world: BlockWorld
    ) -> [BlockPosition]? {
        var line: [BlockPosition] = []
        var target = front
        for count in 0..<13 {
            guard target.y > 0, target.y < 127, world.chunks[target.chunk] != nil else { return nil }
            line.append(target)
            guard let state = world.state(at: target) else { return line }
            guard canPush(state, at: target, world: world) else { return nil }
            if fragile.contains(state.kind.rawValue) { return line }
            if count == 12 { return nil }
            target = target.adding(direction)
        }
        return nil
    }

    private static func canPush(_ state: BlockState, at p: BlockPosition, world: BlockWorld) -> Bool {
        if state.kind == .obsidian || BlockMining.hardness(of: state.kind) < 0 { return false }
        if state.kind == .piston || state.kind == .stickyPiston { return state.metadata & 8 == 0 }
        if [.pistonHead, .movingPiston, .portal].contains(state.kind) { return false }
        return !containers.contains(state.kind.rawValue) && world.blockEntity(at: p) == nil
    }

    private static func displacementBounds(
        for state: PistonState, at p: BlockPosition, progress: Float
    ) -> AxisAlignedBox? {
        guard let first = state.storedCollisionBounds(at: p) else { return nil }
        let distance = state.extending ? 1 - progress : progress - 1
        return first.offset(by: -SIMD3<Double>(state.direction) * Double(distance))
    }

    private static func pistonSound(
        _ name: String, at p: BlockPosition, random: inout JavaRandom, range: Float
    ) -> BlockEvent {
        .sound(name: name, position: p.center, volume: 0.5, pitch: random.nextFloat() * range + 0.6)
    }
}
