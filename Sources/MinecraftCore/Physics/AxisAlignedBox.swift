import Foundation

public struct AxisAlignedBox: Equatable, Sendable {
    public var min: SIMD3<Double>
    public var max: SIMD3<Double>

    public init(min: SIMD3<Double>, max: SIMD3<Double>) {
        self.min = min
        self.max = max
    }

    public func offset(by offset: SIMD3<Double>) -> Self {
        Self(min: min + offset, max: max + offset)
    }

    public func expanded(by amount: SIMD3<Double>) -> Self {
        Self(min: min - amount, max: max + amount)
    }

    public func swept(by movement: SIMD3<Double>) -> Self {
        Self(
            min: SIMD3(
                min.x + Swift.min(movement.x, 0), min.y + Swift.min(movement.y, 0),
                min.z + Swift.min(movement.z, 0)),
            max: SIMD3(
                max.x + Swift.max(movement.x, 0), max.y + Swift.max(movement.y, 0),
                max.z + Swift.max(movement.z, 0))
        )
    }

    public func intersects(_ other: Self) -> Bool {
        other.max.x > min.x && other.min.x < max.x && other.max.y > min.y && other.min.y < max.y
            && other.max.z > min.z && other.min.z < max.z
    }

    public func contains(_ point: SIMD3<Double>) -> Bool {
        point.x > min.x && point.x < max.x && point.y > min.y && point.y < max.y
            && point.z > min.z && point.z < max.z
    }

    /// Clips one axis against this stationary obstacle, after the earlier axes have moved.
    public func clip(_ movement: Double, axis: Int, moving other: Self) -> Double {
        let first = (axis + 1) % 3
        let second = (axis + 2) % 3
        guard other.max[first] > min[first], other.min[first] < max[first],
            other.max[second] > min[second], other.min[second] < max[second]
        else { return movement }
        if movement > 0 && other.max[axis] <= min[axis] {
            return Swift.min(movement, min[axis] - other.max[axis])
        }
        if movement < 0 && other.min[axis] >= max[axis] {
            return Swift.max(movement, max[axis] - other.min[axis])
        }
        return movement
    }

    func rayIntersection(origin: SIMD3<Double>, direction: SIMD3<Double>, reach: Double)
        -> (distance: Double, face: BlockPosition)?
    {
        var near = -Double.infinity
        var far = Double.infinity
        var nearAxis = 0
        var farAxis = 0
        var nearSign = 0
        var farSign = 0
        for axis in 0..<3 {
            if direction[axis] == 0 {
                guard origin[axis] >= min[axis], origin[axis] <= max[axis] else { return nil }
                continue
            }
            let entering = direction[axis] > 0 ? min[axis] : max[axis]
            let exiting = direction[axis] > 0 ? max[axis] : min[axis]
            let start = (entering - origin[axis]) / direction[axis]
            let end = (exiting - origin[axis]) / direction[axis]
            if start > near {
                near = start
                nearAxis = axis
                nearSign = direction[axis] > 0 ? -1 : 1
            }
            if end < far {
                far = end
                farAxis = axis
                farSign = direction[axis] > 0 ? 1 : -1
            }
            if near > far { return nil }
        }
        let distance = near >= 0 ? near : far
        guard distance >= 0, distance <= reach else { return nil }
        let axis = near >= 0 ? nearAxis : farAxis
        let sign = near >= 0 ? nearSign : farSign
        return (distance, BlockPosition(axis == 0 ? sign : 0, axis == 1 ? sign : 0, axis == 2 ? sign : 0))
    }
}
