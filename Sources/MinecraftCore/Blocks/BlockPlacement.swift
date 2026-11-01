import Foundation

public enum BlockPlacement {
    public static func isReplaceable(_ state: BlockState?) -> Bool {
        guard let state else { return true }
        switch state.kind {
        case .air, .water, .stillWater, .lava, .stillLava, .fire, .snowLayer: return true
        default: return false
        }
    }

    public static func canRemain(_ state: BlockState, at p: BlockPosition, in world: BlockWorld) -> Bool {
        let below = p.adding(BlockPosition(0, -1, 0))
        switch state.kind {
        case .sapling, .tallGrass, .dandelion, .rose:
            return [.grass, .dirt, .farmland].contains(world[below])
        case .deadBush: return world[below] == .sand
        case .brownMushroom, .redMushroom: return world[below]?.isOpaque == true || world[below] == .leaves
        case .wheat: return world[below] == .farmland
        case .sugarCane:
            if world[below] == .sugarCane { return true }
            guard world[below] == .grass || world[below] == .dirt else { return false }
            return BlockPosition.horizontal.contains { isWater(world[below.adding($0)]) }
        case .cactus:
            guard world[below] == .sand || world[below] == .cactus else { return false }
            return !BlockPosition.horizontal.contains { world[p.adding($0)]?.isMaterialSolid == true }
        case .rail, .poweredRail, .detectorRail:
            guard world[below]?.isNormalCube == true else { return false }
            let shape = state.kind == .rail ? state.metadata : state.metadata & 7
            let support: BlockPosition
            switch shape {
            case 2: support = BlockPosition(1, 0, 0)
            case 3: support = BlockPosition(-1, 0, 0)
            case 4: support = BlockPosition(0, 0, -1)
            case 5: support = BlockPosition(0, 0, 1)
            default: return true
            }
            return world[p.adding(support)]?.isNormalCube == true
        case .redstoneWire, .stonePressurePlate, .woodenPressurePlate, .repeaterOff, .repeaterOn, .cake:
            return world[below]?.isNormalCube == true
        case .torch, .redstoneTorch, .redstoneTorchOff, .lever, .stoneButton:
            let support: BlockPosition
            switch state.metadata & 7 {
            case 1: support = BlockPosition(-1, 0, 0)
            case 2: support = BlockPosition(1, 0, 0)
            case 3: support = BlockPosition(0, 0, -1)
            case 4: support = BlockPosition(0, 0, 1)
            default: support = BlockPosition(0, -1, 0)
            }
            return world[p.adding(support)]?.isNormalCube == true
                || (state.kind != .lever && state.kind != .stoneButton && (state.metadata & 7) == 5
                    && world[p.adding(support)] == .fence)
        case .ladder, .wallSign:
            let support: BlockPosition
            switch state.metadata {
            case 2: support = BlockPosition(0, 0, 1)
            case 3: support = BlockPosition(0, 0, -1)
            case 4: support = BlockPosition(1, 0, 0)
            default: support = BlockPosition(-1, 0, 0)
            }
            return state.kind == .ladder
                ? world[p.adding(support)]?.isNormalCube == true
                : world[p.adding(support)]?.isMaterialSolid == true
        case .standingSign: return world[below]?.isMaterialSolid == true
        case .woodenDoor, .ironDoor:
            if state.metadata & 8 != 0 { return world[below] == state.kind }
            return world[below]?.isNormalCube == true && world[p.adding(BlockPosition(0, 1, 0))] == state.kind
        case .trapdoor:
            let support = [
                BlockPosition(0, 0, 1), BlockPosition(0, 0, -1),
                BlockPosition(1, 0, 0), BlockPosition(-1, 0, 0),
            ][Int(state.metadata & 3)]
            return world[p.adding(support)]?.isNormalCube == true
        case .bed:
            let direction = bedDirection(state.metadata)
            let other = p.adding(
                state.metadata & 8 == 0 ? direction : BlockPosition(-direction.x, 0, -direction.z))
            return world[below]?.isNormalCube == true && world[other] == .bed
        case .pistonHead:
            let facing = Int(state.metadata & 7)
            guard facing < 6 else { return false }
            let direction = BlockPower.directions[facing]
            let base = world.state(at: p.adding(BlockPosition(-direction.x, -direction.y, -direction.z)))
            return (base?.kind == .piston || base?.kind == .stickyPiston) && (base?.metadata ?? 0) & 8 != 0
        case .piston, .stickyPiston:
            guard state.metadata & 8 != 0 else { return true }
            let facing = Int(state.metadata & 7)
            guard facing < 6 else { return false }
            let head = p.adding(BlockPower.directions[facing])
            if world[head] == .pistonHead { return true }
            if case .piston(let moving) = world.blockEntity(at: head) {
                return moving.block.kind == .pistonHead && moving.facing == facing
            }
            return false
        case .portal: return PortalFormation.isValid(at: p, world: world)
        case .snowLayer:
            return (world[below]?.isOpaque == true || world[below] == .leaves)
                && world[below]?.isMaterialSolid == true
        case .fire:
            return world[below]?.isNormalCube == true
                || BlockPosition.neighbors.contains {
                    BlockGrowth.isFlammable(world[p.adding($0)])
                }
        default: return true
        }
    }

    static func isWater(_ kind: BlockKind?) -> Bool { kind == .water || kind == .stillWater }

    static func bedDirection(_ metadata: UInt8) -> BlockPosition {
        [
            BlockPosition(0, 0, 1), BlockPosition(-1, 0, 0), BlockPosition(0, 0, -1),
            BlockPosition(1, 0, 0),
        ][Int(metadata & 3)]
    }

    static func quadrant(yaw: Float) -> UInt8 {
        UInt8((Int(floor(yaw * 2 / .pi + 0.5)) + 2) & 3)
    }

    static func resolvedPlacement(
        kind: BlockKind, damage: UInt16, face: BlockPosition, yaw: Float, at p: BlockPosition,
        world: BlockWorld
    ) -> BlockState? {
        let state = placementState(kind: kind, damage: damage, face: face, yaw: yaw)
        if let state, canRemain(state, at: p, in: world) { return state }
        let fallback: [UInt8]
        switch kind {
        case .torch, .redstoneTorch, .redstoneTorchOff: fallback = [1, 2, 3, 4, 5]
        case .ladder: fallback = [2, 3, 4, 5]
        default: return nil
        }
        return fallback.map { BlockState(kind, metadata: $0) }.first { canRemain($0, at: p, in: world) }
    }

    static func placementState(kind: BlockKind, damage: UInt16, face: BlockPosition, yaw: Float)
        -> BlockState?
    {
        var metadata: UInt8 = [6, 17, 18, 35, 44].contains(kind.rawValue) ? UInt8(damage & 15) : 0
        let quadrant = quadrant(yaw: yaw)
        switch kind {
        case .woodenStairs, .cobblestoneStairs: metadata = [2, 1, 3, 0][Int(quadrant)]
        case .furnace, .burningFurnace, .dispenser: metadata = [2, 5, 3, 4][Int(quadrant)]
        case .leaves: metadata |= 8
        case .pumpkin, .jackOLantern: metadata = quadrant
        case .piston, .stickyPiston: metadata = [2, 5, 3, 4][Int(quadrant)]
        case .repeaterOff, .repeaterOn: metadata = (quadrant + 2) & 3
        case .torch, .redstoneTorch, .redstoneTorchOff, .lever, .stoneButton:
            if face.x == 1 {
                metadata = 1
            } else if face.x == -1 {
                metadata = 2
            } else if face.z == 1 {
                metadata = 3
            } else if face.z == -1 {
                metadata = 4
            } else if face.y == 1 && kind != .stoneButton {
                metadata = 5
            } else {
                return nil
            }
        case .ladder, .wallSign:
            if face.z == -1 {
                metadata = 2
            } else if face.z == 1 {
                metadata = 3
            } else if face.x == -1 {
                metadata = 4
            } else if face.x == 1 {
                metadata = 5
            } else {
                return nil
            }
        case .trapdoor:
            if face.z == -1 {
                metadata = 0
            } else if face.z == 1 {
                metadata = 1
            } else if face.x == -1 {
                metadata = 2
            } else if face.x == 1 {
                metadata = 3
            } else {
                return nil
            }
        default: break
        }
        return BlockState(kind, metadata: metadata)
    }
}
