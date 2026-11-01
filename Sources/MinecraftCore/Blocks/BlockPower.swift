public enum BlockPower {
    static let directions = [
        BlockPosition(0, -1, 0), BlockPosition(0, 1, 0), BlockPosition(0, 0, -1),
        BlockPosition(0, 0, 1), BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
    ]

    public static func isPowered(at p: BlockPosition, in world: BlockWorld, includeWire: Bool = true) -> Bool
    {
        directions.enumerated().contains { side, offset in
            transmits(at: p.adding(offset), side: side, in: world, includeWire: includeWire)
        }
    }

    static func transmits(at p: BlockPosition, side: Int, in world: BlockWorld, includeWire: Bool = true)
        -> Bool
    {
        guard let state = world.state(at: p) else { return false }
        if state.kind.isNormalCube {
            return directions.enumerated().contains { direction, offset in
                guard let neighbor = world.state(at: p.adding(offset)) else { return false }
                return emits(
                    neighbor, at: p.adding(offset), side: direction, strong: true,
                    world: world, includeWire: includeWire)
            }
        }
        return emits(state, at: p, side: side, strong: false, world: world, includeWire: includeWire)
    }

    static func repeaterInput(at p: BlockPosition, state: BlockState, world: BlockWorld) -> Bool {
        let offsets = [
            BlockPosition(0, 0, 1), BlockPosition(-1, 0, 0),
            BlockPosition(0, 0, -1), BlockPosition(1, 0, 0),
        ]
        let side = [3, 4, 2, 5][Int(state.metadata & 3)]
        let input = p.adding(offsets[Int(state.metadata & 3)])
        return transmits(at: input, side: side, in: world)
            || (world[input] == .redstoneWire && (world.state(at: input)?.metadata ?? 0) > 0)
    }

    static func torchInput(at p: BlockPosition, state: BlockState, world: BlockWorld) -> Bool {
        let offset: BlockPosition
        let side: Int
        switch state.metadata & 7 {
        case 1:
            offset = BlockPosition(-1, 0, 0)
            side = 4
        case 2:
            offset = BlockPosition(1, 0, 0)
            side = 5
        case 3:
            offset = BlockPosition(0, 0, -1)
            side = 2
        case 4:
            offset = BlockPosition(0, 0, 1)
            side = 3
        default:
            offset = BlockPosition(0, -1, 0)
            side = 0
        }
        return transmits(at: p.adding(offset), side: side, in: world)
    }

    static func pistonInput(at p: BlockPosition, facing: Int, world: BlockWorld) -> Bool {
        for (side, offset) in directions.enumerated() where side != facing {
            if transmits(at: p.adding(offset), side: side, in: world) { return true }
        }
        if transmits(at: p, side: 0, in: world) { return true }
        let above = p.adding(BlockPosition(0, 1, 0))
        for side in [1, 2, 3, 4, 5] {
            if transmits(at: above.adding(directions[side]), side: side, in: world) { return true }
        }
        return false
    }

    private static func emits(
        _ state: BlockState, at p: BlockPosition, side: Int, strong: Bool,
        world: BlockWorld, includeWire: Bool
    ) -> Bool {
        let data = state.metadata
        switch state.kind {
        case .lever, .stoneButton:
            guard data & 8 != 0 else { return false }
            if !strong { return true }
            switch data & 7 {
            case 1: return side == 5
            case 2: return side == 4
            case 3: return side == 3
            case 4: return side == 2
            default: return side == 1
            }
        case .stonePressurePlate, .woodenPressurePlate:
            return data > 0 && (!strong || side == 1)
        case .detectorRail: return data & 8 != 0 && (!strong || side == 1)
        case .redstoneTorch:
            if strong && side != 0 { return false }
            switch data {
            case 5: return side != 1
            case 3: return side != 3
            case 4: return side != 2
            case 1: return side != 5
            case 2: return side != 4
            default: return true
            }
        case .repeaterOn:
            return side == [3, 4, 2, 5][Int(data & 3)]
        case .redstoneWire:
            guard includeWire, data > 0 else { return false }
            if side == 1 { return true }
            let connected = wireConnections(at: p, world: world)
            let west = connected[0]
            let east = connected[1]
            let north = connected[2]
            let south = connected[3]
            if !west && !east && !north && !south { return (2...5).contains(side) }
            if side == 2 { return north && !west && !east }
            if side == 3 { return south && !west && !east }
            if side == 4 { return west && !north && !south }
            return side == 5 && east && !north && !south
        default: return false
        }
    }

    private static func wireConnections(at p: BlockPosition, world: BlockWorld) -> [Bool] {
        BlockPosition.horizontal.enumerated().map { index, offset in
            let neighbor = p.adding(offset)
            if connects(at: neighbor, side: [1, 3, 2, 0][index], world: world) { return true }
            if world[neighbor]?.isNormalCube != true
                && connects(at: neighbor.adding(BlockPosition(0, -1, 0)), side: -1, world: world)
            {
                return true
            }
            return world[p.adding(BlockPosition(0, 1, 0))]?.isNormalCube != true
                && world[neighbor]?.isNormalCube == true
                && connects(at: neighbor.adding(BlockPosition(0, 1, 0)), side: -1, world: world)
        }
    }

    private static func connects(at p: BlockPosition, side: Int, world: BlockWorld) -> Bool {
        guard let state = world.state(at: p) else { return false }
        switch state.kind {
        case .redstoneWire, .lever, .stoneButton, .stonePressurePlate, .woodenPressurePlate,
            .redstoneTorch, .redstoneTorchOff, .detectorRail:
            return true
        case .repeaterOff, .repeaterOn: return side == [2, 3, 0, 1][Int(state.metadata & 3)]
        default: return false
        }
    }
}

extension BlockKind {
    /// Attachment and power rules use normal cubes, independently of opaque rendering.
    public var isNormalCube: Bool { Self.normalCubes.contains(rawValue) }
    public var isMaterialSolid: Bool { Self.solidMaterials.contains(rawValue) }

    public var isMaterialFlammable: Bool {
        [5, 17, 18, 25, 26, 35, 46, 47, 53, 54, 58, 63, 64, 68, 72, 84, 85, 95, 96].contains(rawValue)
    }

    var noteInstrument: String {
        switch rawValue {
        case 1, 4, 7, 14, 15, 16, 21, 22, 23, 24, 43, 44, 45, 48, 49, 52, 56, 61, 62,
            67, 70, 73, 74, 87, 89:
            return "note.bd"
        case 12, 13, 88: return "note.snare"
        case 20: return "note.hat"
        case 5, 17, 25, 47, 53, 54, 58, 63, 64, 68, 72, 84, 85, 95, 96:
            return "note.bassattack"
        default: return "note.harp"
        }
    }

    private static let normalCubes: Set<UInt8> = [
        1, 2, 3, 4, 5, 7, 12, 13, 14, 15, 16, 17, 19, 21, 22, 23, 24, 25, 35, 41, 42, 43, 45, 47, 48, 49, 52,
        54, 56, 57, 58, 61, 62, 73, 74, 80, 82, 84, 86, 87, 88, 89, 91, 95,
    ]
    private static let solidMaterials: Set<UInt8> = [
        1, 2, 3, 4, 5, 7, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 29, 30, 33, 34, 35, 36,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 52, 53, 54, 56, 57, 58, 60, 61, 62, 63, 64, 67, 68, 70, 71, 72,
        73, 74, 79, 80, 81, 82, 84, 85, 86, 87, 88, 89, 91, 92, 95, 96,
    ]
}
