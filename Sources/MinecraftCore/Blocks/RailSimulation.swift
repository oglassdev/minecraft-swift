enum RailSimulation {
    static func isRail(_ kind: BlockKind?) -> Bool {
        kind == .rail || kind == .poweredRail || kind == .detectorRail
    }

    static func updateTopology(at p: BlockPosition, world: inout BlockWorld, force: Bool) -> [BlockPosition] {
        guard var node = Node(at: p, world: world) else { return [] }
        let north = node.canConnect(at: p.adding(BlockPosition(0, 0, -1)), world: world)
        let south = node.canConnect(at: p.adding(BlockPosition(0, 0, 1)), world: world)
        let west = node.canConnect(at: p.adding(BlockPosition(-1, 0, 0)), world: world)
        let east = node.canConnect(at: p.adding(BlockPosition(1, 0, 0)), world: world)
        var shape = -1
        if (north || south) && !west && !east { shape = 0 }
        if (west || east) && !north && !south { shape = 1 }
        if !node.straightOnly {
            if south && east && !north && !west { shape = 6 }
            if south && west && !north && !east { shape = 7 }
            if north && west && !south && !east { shape = 8 }
            if north && east && !south && !west { shape = 9 }
        }
        if shape == -1 {
            if north || south { shape = 0 }
            if west || east { shape = 1 }
            if !node.straightOnly {
                if BlockPower.isPowered(at: p, in: world) {
                    if south && east { shape = 6 }
                    if west && south { shape = 7 }
                    if east && north { shape = 9 }
                    if north && west { shape = 8 }
                } else {
                    if north && west { shape = 8 }
                    if east && north { shape = 9 }
                    if west && south { shape = 7 }
                    if south && east { shape = 6 }
                }
            }
        }
        shape = raisedShape(shape, at: p, world: world)
        if shape < 0 { shape = 0 }
        node.connections = connections(shape: shape, at: p)
        guard let state = world.state(at: p) else { return [] }
        let metadata = UInt8(shape) | (node.straightOnly ? state.metadata & 8 : 0)
        guard force || state.metadata != metadata else { return [] }
        world.setBlock(BlockState(state.kind, metadata: metadata), at: p)
        var changed = [p]
        for endpoint in node.connections {
            guard var neighbor = Node.near(endpoint, world: world) else { continue }
            neighbor.removeSoftConnections(world: world)
            if neighbor.canConnect(to: node) {
                changed += neighbor.connect(to: node, world: &world)
            }
        }
        return changed
    }

    static func neighborCount(at p: BlockPosition, world: BlockWorld) -> Int {
        BlockPosition.horizontal.filter { Node.near(p.adding($0), world: world) != nil }.count
    }

    static func recalculatePower(around positions: [BlockPosition], world: inout BlockWorld)
        -> [BlockPosition]
    {
        var queue = positions
        var queued = Set(positions)
        var changed: Set<BlockPosition> = []
        var index = 0
        while index < queue.count {
            let p = queue[index]
            index += 1
            queued.remove(p)
            guard updatePower(at: p, world: &world) else { continue }
            changed.insert(p)
            for offset in BlockPosition.horizontal {
                for y in -1...1 {
                    let neighbor = p.adding(BlockPosition(offset.x, y, offset.z))
                    if world[neighbor] == .poweredRail && queued.insert(neighbor).inserted {
                        queue.append(neighbor)
                    }
                }
            }
        }
        return changed.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
    }

    static func updatePower(at p: BlockPosition, world: inout BlockWorld) -> Bool {
        guard let state = world.state(at: p), state.kind == .poweredRail else { return false }
        let powered =
            directlyPowered(at: p, world: world)
            || searchesPower(at: p, metadata: state.metadata, forward: true, distance: 0, world: world)
            || searchesPower(at: p, metadata: state.metadata, forward: false, distance: 0, world: world)
        let metadata = (state.metadata & 7) | (powered ? 8 : 0)
        guard metadata != state.metadata else { return false }
        world.setBlock(BlockState(.poweredRail, metadata: metadata), at: p)
        return true
    }

    private static func searchesPower(
        at p: BlockPosition, metadata: UInt8, forward: Bool, distance: Int, world: BlockWorld
    ) -> Bool {
        if distance >= 8 { return false }
        var target = p
        var shape = Int(metadata & 7)
        var alsoBelow = true
        switch shape {
        case 0: target.z += forward ? 1 : -1
        case 1: target.x += forward ? -1 : 1
        case 2:
            target.x += forward ? -1 : 1
            if !forward {
                target.y += 1
                alsoBelow = false
            }
            shape = 1
        case 3:
            target.x += forward ? -1 : 1
            if forward {
                target.y += 1
                alsoBelow = false
            }
            shape = 1
        case 4:
            target.z += forward ? 1 : -1
            if !forward {
                target.y += 1
                alsoBelow = false
            }
            shape = 0
        case 5:
            target.z += forward ? 1 : -1
            if forward {
                target.y += 1
                alsoBelow = false
            }
            shape = 0
        default: break
        }
        if searchesPower(atNeighbor: target, forward: forward, distance: distance, axis: shape, world: world)
        {
            return true
        }
        return alsoBelow
            && searchesPower(
                atNeighbor: target.adding(BlockPosition(0, -1, 0)), forward: forward,
                distance: distance, axis: shape, world: world)
    }

    private static func searchesPower(
        atNeighbor p: BlockPosition, forward: Bool, distance: Int, axis: Int, world: BlockWorld
    ) -> Bool {
        guard let state = world.state(at: p), state.kind == .poweredRail else { return false }
        let shape = Int(state.metadata & 7)
        if axis == 1 && [0, 4, 5].contains(shape) { return false }
        if axis == 0 && [1, 2, 3].contains(shape) { return false }
        guard state.metadata & 8 != 0 else { return false }
        return directlyPowered(at: p, world: world)
            || searchesPower(
                at: p, metadata: state.metadata, forward: forward, distance: distance + 1, world: world)
    }

    private static func directlyPowered(at p: BlockPosition, world: BlockWorld) -> Bool {
        BlockPower.isPowered(at: p, in: world)
            || BlockPower.isPowered(at: p.adding(BlockPosition(0, 1, 0)), in: world)
    }

    private static func raisedShape(_ shape: Int, at p: BlockPosition, world: BlockWorld) -> Int {
        var result = shape
        if shape == 0 {
            if isRail(world[p.adding(BlockPosition(0, 1, -1))]) { result = 4 }
            if isRail(world[p.adding(BlockPosition(0, 1, 1))]) { result = 5 }
        }
        if shape == 1 {
            if isRail(world[p.adding(BlockPosition(1, 1, 0))]) { result = 2 }
            if isRail(world[p.adding(BlockPosition(-1, 1, 0))]) { result = 3 }
        }
        return result
    }

    private static func connections(shape: Int, at p: BlockPosition) -> [BlockPosition] {
        let offsets: [BlockPosition]
        switch shape {
        case 0: offsets = [BlockPosition(0, 0, -1), BlockPosition(0, 0, 1)]
        case 1: offsets = [BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0)]
        case 2: offsets = [BlockPosition(-1, 0, 0), BlockPosition(1, 1, 0)]
        case 3: offsets = [BlockPosition(-1, 1, 0), BlockPosition(1, 0, 0)]
        case 4: offsets = [BlockPosition(0, 1, -1), BlockPosition(0, 0, 1)]
        case 5: offsets = [BlockPosition(0, 0, -1), BlockPosition(0, 1, 1)]
        case 6: offsets = [BlockPosition(1, 0, 0), BlockPosition(0, 0, 1)]
        case 7: offsets = [BlockPosition(-1, 0, 0), BlockPosition(0, 0, 1)]
        case 8: offsets = [BlockPosition(-1, 0, 0), BlockPosition(0, 0, -1)]
        case 9: offsets = [BlockPosition(1, 0, 0), BlockPosition(0, 0, -1)]
        default: offsets = []
        }
        return offsets.map { p.adding($0) }
    }

    private struct Node {
        let position: BlockPosition
        let straightOnly: Bool
        var connections: [BlockPosition]

        init?(at p: BlockPosition, world: BlockWorld) {
            guard let state = world.state(at: p), isRail(state.kind) else { return nil }
            position = p
            straightOnly = state.kind != .rail
            connections = RailSimulation.connections(
                shape: Int(straightOnly ? state.metadata & 7 : state.metadata), at: p)
        }

        static func near(_ p: BlockPosition, world: BlockWorld) -> Self? {
            Self(at: p, world: world) ?? Self(at: p.adding(BlockPosition(0, 1, 0)), world: world)
                ?? Self(at: p.adding(BlockPosition(0, -1, 0)), world: world)
        }

        mutating func removeSoftConnections(world: BlockWorld) {
            connections = connections.compactMap { endpoint in
                guard let neighbor = Self.near(endpoint, world: world), neighbor.connects(to: position)
                else { return nil }
                return neighbor.position
            }
        }

        func connects(to p: BlockPosition) -> Bool {
            connections.contains { $0.x == p.x && $0.z == p.z }
        }

        func canConnect(to node: Self) -> Bool {
            connects(to: node.position) || connections.count != 2
        }

        func canConnect(at p: BlockPosition, world: BlockWorld) -> Bool {
            guard var neighbor = Self.near(p, world: world) else { return false }
            neighbor.removeSoftConnections(world: world)
            return neighbor.canConnect(to: self)
        }

        mutating func connect(to node: Self, world: inout BlockWorld) -> [BlockPosition] {
            connections.append(node.position)
            let p = position
            let north = connects(to: p.adding(BlockPosition(0, 0, -1)))
            let south = connects(to: p.adding(BlockPosition(0, 0, 1)))
            let west = connects(to: p.adding(BlockPosition(-1, 0, 0)))
            let east = connects(to: p.adding(BlockPosition(1, 0, 0)))
            var shape = -1
            if north || south { shape = 0 }
            if west || east { shape = 1 }
            if !straightOnly {
                if south && east && !north && !west { shape = 6 }
                if south && west && !north && !east { shape = 7 }
                if north && west && !south && !east { shape = 8 }
                if north && east && !south && !west { shape = 9 }
            }
            shape = raisedShape(shape, at: p, world: world)
            if shape < 0 { shape = 0 }
            guard let state = world.state(at: p) else { return [] }
            let metadata = UInt8(shape) | (straightOnly ? state.metadata & 8 : 0)
            guard state.metadata != metadata else { return [] }
            world.setBlock(BlockState(state.kind, metadata: metadata), at: p)
            return [p]
        }
    }
}
