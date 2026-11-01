public struct ScheduledBlockTick: Equatable, Sendable {
    public let position: BlockPosition
    public let kind: BlockKind
    public let time: Int64
    public let order: Int64

    func precedes(_ other: Self) -> Bool {
        time == other.time ? order < other.order : time < other.time
    }
}

struct ScheduledBlockTickQueue: Sendable {
    struct Cycle {
        private var remaining: Int
        init(count: Int) { remaining = min(count, 1000) }

        mutating func next(in queue: inout ScheduledBlockTickQueue, through time: Int64, force: Bool = false)
            -> ScheduledBlockTick?
        {
            guard remaining > 0, let first = queue.first, force || first.time <= time else {
                remaining = 0
                return nil
            }
            remaining -= 1
            return queue.popFirst()
        }
    }

    private struct Key: Hashable, Sendable {
        let position: BlockPosition
        let kind: BlockKind
    }

    private var heap: [ScheduledBlockTick] = []
    private var keys: Set<Key> = []
    var count: Int { heap.count }
    var first: ScheduledBlockTick? { heap.first }
    var ordered: [ScheduledBlockTick] { heap.sorted { $0.precedes($1) } }
    func beginCycle() -> Cycle { Cycle(count: count) }

    mutating func insert(_ tick: ScheduledBlockTick) {
        guard keys.insert(Key(position: tick.position, kind: tick.kind)).inserted else { return }
        heap.append(tick)
        var child = heap.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            if !heap[child].precedes(heap[parent]) { break }
            heap.swapAt(child, parent)
            child = parent
        }
    }

    mutating func popFirst() -> ScheduledBlockTick? {
        guard let first = heap.first else { return nil }
        keys.remove(Key(position: first.position, kind: first.kind))
        let last = heap.removeLast()
        guard !heap.isEmpty else { return first }
        heap[0] = last
        var parent = 0
        while parent * 2 + 1 < heap.count {
            var child = parent * 2 + 1
            if child + 1 < heap.count && heap[child + 1].precedes(heap[child]) { child += 1 }
            if !heap[child].precedes(heap[parent]) { break }
            heap.swapAt(child, parent)
            parent = child
        }
        return first
    }
}
