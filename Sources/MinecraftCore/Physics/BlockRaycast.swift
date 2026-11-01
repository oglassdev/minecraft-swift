import Foundation

public struct BlockHit: Equatable, Sendable {
    public let position: BlockPosition
    public let face: BlockPosition
    public let distance: Double
    public let point: SIMD3<Double>

    public var adjacentPosition: BlockPosition {
        BlockPosition(position.x + face.x, position.y + face.y, position.z + face.z)
    }
}

public enum BlockRaycast {
    public static func hit(
        in world: BlockWorld,
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        reach: Double = 5,
        includeLiquids: Bool = false,
        collidableOnly: Bool = false
    ) -> BlockHit? {
        guard origin.x.isFinite, origin.y.isFinite, origin.z.isFinite,
            direction.x.isFinite, direction.y.isFinite, direction.z.isFinite,
            reach.isFinite, reach >= 0
        else { return nil }
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        guard length > 0, length.isFinite else { return nil }
        let direction = direction / length
        var cell = SIMD3(Int(floor(origin.x)), Int(floor(origin.y)), Int(floor(origin.z)))
        var next = SIMD3<Double>(repeating: .infinity)
        var interval = SIMD3<Double>(repeating: .infinity)
        var step = SIMD3<Int>.zero
        for axis in 0..<3 where direction[axis] != 0 {
            step[axis] = direction[axis] > 0 ? 1 : -1
            let boundary = Double(cell[axis] + (step[axis] > 0 ? 1 : 0))
            next[axis] = (boundary - origin[axis]) / direction[axis]
            interval[axis] = abs(1 / direction[axis])
        }
        var traveled: Double = 0
        while traveled <= reach {
            let position = BlockPosition(cell.x, cell.y, cell.z)
            if let state = world.state(at: position),
                !state.kind.isLiquid || (includeLiquids && state.metadata == 0),
                !collidableOnly || !BlockCollision.boxes(for: state, at: position, in: world).isEmpty
            {
                let nearest = BlockCollision.selectionBoxes(for: state, at: position, in: world)
                    .compactMap { $0.rayIntersection(origin: origin, direction: direction, reach: reach) }
                    .min { $0.distance < $1.distance }
                if let nearest {
                    return BlockHit(
                        position: position, face: nearest.face, distance: nearest.distance,
                        point: origin + direction * nearest.distance)
                }
            }
            let axis: Int
            if next.x < next.y && next.x < next.z {
                axis = 0
            } else if next.y < next.z {
                axis = 1
            } else {
                axis = 2
            }
            traveled = next[axis]
            cell[axis] += step[axis]
            next[axis] += interval[axis]
        }
        return nil
    }
}
