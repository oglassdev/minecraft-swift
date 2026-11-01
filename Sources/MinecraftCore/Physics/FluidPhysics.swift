import Foundation

public enum FluidPhysics {
    public static func flow(in world: BlockWorld, at position: BlockPosition) -> SIMD3<Double> {
        guard let state = world.state(at: position), state.kind.isLiquid else { return .zero }
        let water = state.kind.rawValue == 8 || state.kind.rawValue == 9
        let level = depth(state)
        var result = SIMD3<Double>.zero
        var besideWall = false
        for offset in [
            BlockPosition(-1, 0, 0), BlockPosition(0, 0, -1), BlockPosition(1, 0, 0), BlockPosition(0, 0, 1),
        ] {
            let neighbor = BlockPosition(position.x + offset.x, position.y, position.z + offset.z)
            let neighborState = world.state(at: neighbor)
            let neighborLevel = matchingDepth(neighborState, water: water)
            var difference = 0
            if neighborLevel < 0 {
                if neighborState?.kind.isSolid != true,
                    let below = world.state(at: BlockPosition(neighbor.x, neighbor.y - 1, neighbor.z))
                {
                    let belowLevel = matchingDepth(below, water: water)
                    if belowLevel >= 0 { difference = belowLevel - (level - 8) }
                }
            } else {
                difference = neighborLevel - level
            }
            result += SIMD3(Double(offset.x * difference), 0, Double(offset.z * difference))
            if neighborState?.kind.isSolid == true && neighborState?.kind != .ice
                || (world[BlockPosition(neighbor.x, neighbor.y + 1, neighbor.z)]?.isSolid == true
                    && world[BlockPosition(neighbor.x, neighbor.y + 1, neighbor.z)] != .ice)
            {
                besideWall = true
            }
        }
        if state.metadata >= 8 && besideWall { result = normalized(result) + SIMD3(0, -6, 0) }
        return normalized(result)
    }

    static func waterContact(in world: BlockWorld, bounds: AxisAlignedBox) -> (
        touching: Bool, acceleration: SIMD3<Double>
    ) {
        guard floor(bounds.min.x) <= floor(bounds.max.x), floor(bounds.min.y) <= floor(bounds.max.y),
            floor(bounds.min.z) <= floor(bounds.max.z)
        else { return (false, .zero) }
        var touching = false
        var totalFlow = SIMD3<Double>.zero
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in Int(floor(bounds.min.y))...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    let position = BlockPosition(x, y, z)
                    guard let state = world.state(at: position), matchingDepth(state, water: true) >= 0 else {
                        continue
                    }
                    touching = true
                    totalFlow += flow(in: world, at: position)
                }
            }
        }
        return (touching, normalized(totalFlow) * 0.014)
    }

    private static func depth(_ state: BlockState) -> Int { state.metadata >= 8 ? 0 : Int(state.metadata) }

    private static func matchingDepth(_ state: BlockState?, water: Bool) -> Int {
        guard let state else { return -1 }
        let id = state.kind.rawValue
        guard water ? (id == 8 || id == 9) : (id == 10 || id == 11) else { return -1 }
        return depth(state)
    }

    private static func normalized(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        return length < 0.0001 ? .zero : vector / length
    }
}
