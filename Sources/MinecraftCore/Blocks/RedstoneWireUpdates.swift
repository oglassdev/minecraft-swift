extension BlockPower {
    struct WireChange: Equatable, Sendable {
        let position: BlockPosition
        let level: UInt8
    }

    struct WireUpdateResult: Sendable {
        var levelChanges: [WireChange] = []
        var notifyOrigins: [BlockPosition] = []
        var changedPositions: [BlockPosition] { levelChanges.map(\.position) }
    }

    struct WireUpdates: Sendable {
        private var notifications = WireNotificationSet()

        private enum Frame {
            case calculate(BlockPosition, excluding: BlockPosition)
            case horizontal(BlockPosition, oldLevel: Int, direction: Int)
            case vertical(BlockPosition, oldLevel: Int, direction: Int, neighbor: BlockPosition, y: Int)
            case finishDirection(BlockPosition, oldLevel: Int, direction: Int, lastLevel: Int)
        }

        mutating func update(
            at origin: BlockPosition, world: inout BlockWorld, previousMetadata: UInt8? = nil
        ) -> WireUpdateResult {
            var result = WireUpdateResult()
            guard world[origin] == .redstoneWire || previousMetadata != nil else { return result }
            var removedMetadata = world[origin] == .redstoneWire ? nil : previousMetadata.map(Int.init)
            func metadata(at p: BlockPosition, world: BlockWorld) -> Int {
                if p == origin, let removedMetadata { return removedMetadata }
                return Int(world.state(at: p)?.metadata ?? 0)
            }
            func wireLevel(at p: BlockPosition, world: BlockWorld) -> Int? {
                world[p] == .redstoneWire ? metadata(at: p, world: world) : nil
            }
            let horizontal = [
                BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
                BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
            ]
            var frames: [Frame] = [.calculate(origin, excluding: origin)]
            while let frame = frames.popLast() {
                switch frame {
                case .calculate(let p, let excluded):
                    let oldLevel = metadata(at: p, world: world)
                    var next = 0
                    if BlockPower.isPowered(at: p, in: world, includeWire: false) {
                        next = 15
                    } else {
                        for offset in horizontal {
                            let neighbor = p.adding(offset)
                            if neighbor != excluded, let level = wireLevel(at: neighbor, world: world) {
                                next = max(next, level)
                            }
                            let vertical = neighbor.adding(
                                BlockPosition(
                                    0,
                                    world[neighbor]?.isNormalCube == true ? 1 : -1, 0))
                            if world[neighbor]?.isNormalCube != true
                                || world[p.adding(BlockPosition(0, 1, 0))]?.isNormalCube != true
                            {
                                if vertical != excluded, let level = wireLevel(at: vertical, world: world) {
                                    next = max(next, level)
                                }
                            }
                        }
                        next = max(0, next - 1)
                    }
                    guard oldLevel != next else { continue }
                    if p == origin, removedMetadata != nil {
                        removedMetadata = next
                    } else {
                        world.setBlock(BlockState(.redstoneWire, metadata: UInt8(next)), at: p)
                    }
                    result.levelChanges.append(WireChange(position: p, level: UInt8(next)))
                    frames.append(.horizontal(p, oldLevel: oldLevel, direction: 0))
                case .horizontal(let p, let old, let direction):
                    let neighbor = p.adding(horizontal[direction])
                    let y = p.y + (world[neighbor]?.isNormalCube == true ? 1 : -1)
                    let expected = max(0, metadata(at: p, world: world) - 1)
                    frames.append(.vertical(p, oldLevel: old, direction: direction, neighbor: neighbor, y: y))
                    if let level = wireLevel(at: neighbor, world: world), level != expected {
                        frames.append(.calculate(neighbor, excluding: p))
                    }
                case .vertical(let p, let old, let direction, let neighbor, let y):
                    let vertical = BlockPosition(neighbor.x, y, neighbor.z)
                    let expected = max(0, metadata(at: p, world: world) - 1)
                    frames.append(
                        .finishDirection(p, oldLevel: old, direction: direction, lastLevel: expected))
                    if let level = wireLevel(at: vertical, world: world), level != expected {
                        frames.append(.calculate(vertical, excluding: p))
                    }
                case .finishDirection(let p, let old, let direction, let lastLevel):
                    if direction < 3 {
                        frames.append(.horizontal(p, oldLevel: old, direction: direction + 1))
                    } else if old == 0 || lastLevel == 0 {
                        notifications.insert(p)
                        for offset in [
                            BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
                            BlockPosition(0, -1, 0), BlockPosition(0, 1, 0),
                            BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
                        ] {
                            notifications.insert(p.adding(offset))
                        }
                    }
                }
            }
            result.notifyOrigins = notifications.removeAllKeepingCapacity()
            return result
        }
    }
}

private struct WireNotificationSet: Sendable {
    private var buckets = [[BlockPosition]](repeating: [], count: 16)
    private var count = 0

    mutating func insert(_ position: BlockPosition) {
        let index = Int(Self.hash(position)) & (buckets.count - 1)
        guard !buckets[index].contains(position) else { return }
        buckets[index].insert(position, at: 0)
        count += 1
        if count > buckets.count * 3 / 4 {
            var expanded = [[BlockPosition]](repeating: [], count: buckets.count * 2)
            for bucket in buckets {
                for value in bucket {
                    expanded[Int(Self.hash(value)) & (expanded.count - 1)].insert(value, at: 0)
                }
            }
            buckets = expanded
        }
    }

    mutating func removeAllKeepingCapacity() -> [BlockPosition] {
        let values = buckets.flatMap { $0 }
        for index in buckets.indices { buckets[index].removeAll(keepingCapacity: true) }
        count = 0
        return values
    }

    private static func hash(_ position: BlockPosition) -> UInt32 {
        var hash = UInt32(truncatingIfNeeded: position.x &* 8_976_890 &+ position.y &* 981_131 &+ position.z)
        hash ^= (hash >> 20) ^ (hash >> 12)
        return hash ^ (hash >> 7) ^ (hash >> 4)
    }
}
