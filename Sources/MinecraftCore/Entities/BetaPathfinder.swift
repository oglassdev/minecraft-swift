import Foundation

enum BetaPathfinder {
    static func path(
        in world: BlockWorld, entity: GameEntity, toward target: SIMD3<Double>, range: Double = 16
    ) -> [BlockPosition] {
        var search = Search(world: world, entity: entity)
        return search.find(toward: target, range: Float(range))
    }

    static func waypoint(_ point: BlockPosition, for entity: GameEntity) -> SIMD3<Double> {
        let offset = Double(Int(Float(entity.width) + 1)) * 0.5
        return SIMD3(Double(point.x) + offset, Double(point.y), Double(point.z) + offset)
    }

    private final class Node {
        let position: BlockPosition
        var cost: Float = 0
        var estimate: Float = 0
        var score: Float = 0
        var previous: Node?
        var closed = false
        var heapIndex = -1

        init(_ position: BlockPosition) { self.position = position }
        func distance(to other: Node) -> Float {
            let x = Float(other.position.x - position.x)
            let y = Float(other.position.y - position.y)
            let z = Float(other.position.z - position.z)
            return sqrt(x * x + y * y + z * z)
        }
    }

    private struct Search {
        static let offsets = [
            BlockPosition(0, 0, 1), BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0), BlockPosition(0, 0, -1),
        ]

        let world: BlockWorld
        let width: Double
        let origin: SIMD3<Double>
        let volume: BlockPosition
        var nodes: [Int32: Node] = [:]
        var cachedChunk: Chunk?
        var heap: [Node] = []

        init(world: BlockWorld, entity: GameEntity) {
            self.world = world
            width = entity.width
            origin = entity.bounds.min
            volume = BlockPosition(
                Int(floor(Float(entity.width) + 1)), Int(floor(Float(entity.height) + 1)),
                Int(floor(Float(entity.width) + 1)))
        }

        mutating func find(toward target: SIMD3<Double>, range: Float) -> [BlockPosition] {
            let start = node(
                BlockPosition(
                    Int(floor(origin.x)), Int(floor(origin.y)), Int(floor(origin.z))))
            let radius = Double(Float(width) / 2)
            let goal = node(
                BlockPosition(
                    Int(floor(target.x - radius)), Int(floor(target.y)), Int(floor(target.z - radius))))
            start.estimate = start.distance(to: goal)
            start.score = start.estimate
            insert(start)
            var closest = start
            while let current = removeFirst() {
                if current.position == goal.position { return reconstruct(goal) }
                if current.distance(to: goal) < closest.distance(to: goal) { closest = current }
                current.closed = true
                let step =
                    verticalType(
                        BlockPosition(current.position.x, current.position.y + 1, current.position.z)) == 1
                    ? 1 : 0
                for offset in Self.offsets {
                    let position = BlockPosition(
                        current.position.x + offset.x, current.position.y, current.position.z + offset.z)
                    guard let next = safePoint(position, step: step), !next.closed,
                        next.distance(to: goal) < range
                    else { continue }
                    let cost = current.cost + current.distance(to: next)
                    if next.heapIndex < 0 || cost < next.cost {
                        next.previous = current
                        next.cost = cost
                        next.estimate = next.distance(to: goal)
                        let score = next.cost + next.estimate
                        if next.heapIndex >= 0 {
                            let old = next.score
                            next.score = score
                            if score < old { siftUp(next.heapIndex) } else { siftDown(next.heapIndex) }
                        } else {
                            next.score = score
                            insert(next)
                        }
                    }
                }
            }
            return closest === start ? [] : reconstruct(closest)
        }

        mutating func safePoint(_ position: BlockPosition, step: Int) -> Node? {
            var position = position
            var result: Node?
            if verticalType(position) == 1 { result = node(position) }
            if result == nil && step > 0 {
                let raised = BlockPosition(position.x, position.y + step, position.z)
                if verticalType(raised) == 1 {
                    result = node(raised)
                    position = raised
                }
            }
            if result != nil {
                var fallen = 0
                var below = 0
                while position.y > 0 {
                    below = verticalType(BlockPosition(position.x, position.y - 1, position.z))
                    if below != 1 { break }
                    fallen += 1
                    if fallen >= 4 { return nil }
                    position.y -= 1
                    if position.y > 0 { result = node(position) }
                }
                if below == -2 { return nil }
            }
            return result
        }

        mutating func state(at position: BlockPosition) -> BlockState? {
            if cachedChunk?.position != position.chunk { cachedChunk = world.chunks[position.chunk] }
            return cachedChunk?[position.x & 15, position.y, position.z & 15]
        }

        mutating func verticalType(_ position: BlockPosition) -> Int {
            for x in position.x..<(position.x + volume.x) {
                for y in position.y..<(position.y + volume.y) {
                    for z in position.z..<(position.z + volume.z) {
                        guard let state = state(at: BlockPosition(x, y, z)) else { continue }
                        if state.kind == .woodenDoor || state.kind == .ironDoor {
                            if state.metadata & 4 == 0 { return 0 }
                        } else {
                            if state.kind.isSolid { return 0 }
                            if state.kind == .water || state.kind == .stillWater { return -1 }
                            if state.kind == .lava || state.kind == .stillLava { return -2 }
                        }
                    }
                }
            }
            return 1
        }

        mutating func node(_ position: BlockPosition) -> Node {
            let bits =
                (position.y & 255) | ((position.x & 32767) << 8) | ((position.z & 32767) << 24)
                | (position.x < 0 ? Int(Int32.min) : 0) | (position.z < 0 ? 32768 : 0)
            let key = Int32(truncatingIfNeeded: bits)
            if let existing = nodes[key] { return existing }
            let result = Node(position)
            nodes[key] = result
            return result
        }

        func reconstruct(_ goal: Node) -> [BlockPosition] {
            var result: [BlockPosition] = []
            var current: Node? = goal
            while let node = current {
                result.append(node.position)
                current = node.previous
            }
            return result.reversed()
        }

        mutating func insert(_ node: Node) {
            node.heapIndex = heap.count
            heap.append(node)
            siftUp(heap.count - 1)
        }

        mutating func removeFirst() -> Node? {
            guard let first = heap.first else { return nil }
            let last = heap.removeLast()
            if !heap.isEmpty {
                heap[0] = last
                last.heapIndex = 0
                siftDown(0)
            }
            first.heapIndex = -1
            return first
        }

        mutating func siftUp(_ start: Int) {
            var index = start
            let node = heap[index]
            while index > 0 {
                let parent = (index - 1) >> 1
                guard node.score < heap[parent].score else { break }
                heap[index] = heap[parent]
                heap[index].heapIndex = index
                index = parent
            }
            heap[index] = node
            node.heapIndex = index
        }

        mutating func siftDown(_ start: Int) {
            var index = start
            let node = heap[index]
            while index * 2 + 1 < heap.count {
                let left = index * 2 + 1
                let right = left + 1
                let child = right < heap.count && !(heap[left].score < heap[right].score) ? right : left
                guard heap[child].score < node.score else { break }
                heap[index] = heap[child]
                heap[index].heapIndex = index
                index = child
            }
            heap[index] = node
            node.heapIndex = index
        }
    }
}
