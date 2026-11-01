public struct BetaChunkSet: Sendable {
    private var buckets = Array(repeating: [ChunkPosition](), count: 16)
    public private(set) var count = 0

    public init() {}

    public var elements: [ChunkPosition] { buckets.flatMap { $0 } }

    @discardableResult
    public mutating func insert(_ position: ChunkPosition) -> Bool {
        let index = Int(Self.hash(position)) & (buckets.count - 1)
        guard !buckets[index].contains(position) else { return false }
        buckets[index].insert(position, at: 0)
        count += 1
        if count > buckets.count * 3 / 4 {
            var expanded = Array(repeating: [ChunkPosition](), count: buckets.count * 2)
            for bucket in buckets {
                for value in bucket {
                    expanded[Int(Self.hash(value)) & (expanded.count - 1)].insert(value, at: 0)
                }
            }
            buckets = expanded
        }
        return true
    }

    public mutating func removeAll(keepingCapacity: Bool = true) {
        buckets = Array(repeating: [], count: keepingCapacity ? buckets.count : 16)
        count = 0
    }

    private static func hash(_ position: ChunkPosition) -> UInt32 {
        var hash =
            (position.x < 0 ? UInt32(0x8000_0000) : 0)
            | (UInt32(truncatingIfNeeded: position.x) & 32767) << 16
            | (position.z < 0 ? 32768 : 0) | (UInt32(truncatingIfNeeded: position.z) & 32767)
        hash ^= (hash >> 20) ^ (hash >> 12)
        return hash ^ (hash >> 7) ^ (hash >> 4)
    }
}
