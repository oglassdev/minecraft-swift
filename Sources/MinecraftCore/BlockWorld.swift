public struct BlockPosition: Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var vector: SIMD3<Float> { SIMD3(Float(x), Float(y), Float(z)) }
}

public enum BlockKind: Sendable {
    case grass, dirt, stone, wood, leaves, sand

    public var color: SIMD3<Float> {
        switch self {
        case .grass: SIMD3(0.36, 0.64, 0.24)
        case .dirt: SIMD3(0.48, 0.31, 0.19)
        case .stone: SIMD3(0.56, 0.59, 0.62)
        case .wood: SIMD3(0.42, 0.28, 0.14)
        case .leaves: SIMD3(0.23, 0.48, 0.20)
        case .sand: SIMD3(0.82, 0.75, 0.50)
        }
    }
}

public struct BlockWorld: Sendable {
    public private(set) var blocks: [BlockPosition: BlockKind] = [:]

    public init() {}

    public subscript(position: BlockPosition) -> BlockKind? {
        get { blocks[position] }
        set { blocks[position] = newValue }
    }

    /// A deterministic hand-built scene; this is not Beta terrain generation.
    public static func demo() -> Self {
        var world = Self()
        for x in -16..<16 {
            for z in -16..<16 {
                let hill = max(0, 4 - (abs(x + 5) + abs(z + 5)) / 3)
                for y in -2...hill {
                    let kind: BlockKind
                    if y == hill {
                        kind = .grass
                    } else if y < hill - 1 {
                        kind = .stone
                    } else {
                        kind = .dirt
                    }
                    world[BlockPosition(x, y, z)] = kind
                }
            }
        }
        for (x, z) in [(3, 1), (-7, 4), (5, -8)] {
            for y in 1...4 { world[BlockPosition(x, y, z)] = .wood }
            for dx in -2...2 {
                for dz in -2...2 {
                    for y in 4...6 where abs(dx) + abs(dz) < 4 {
                        let position = BlockPosition(x + dx, y, z + dz)
                        if world[position] == nil { world[position] = .leaves }
                    }
                }
            }
        }
        for x in 5...9 {
            for z in 5...8 { world[BlockPosition(x, 0, z)] = .sand }
        }
        for y in 1...3 { world[BlockPosition(-1, y, 5)] = .stone }
        return world
    }
}
