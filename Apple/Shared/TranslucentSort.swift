import simd

enum TranslucentSort {
    static func needsUpdate(from previous: SIMD3<Double>, to current: SIMD3<Double>) -> Bool {
        simd_distance_squared(previous, current) > 16
    }

    static func indices(centers: [SIMD3<Float>], camera: SIMD3<Float>) -> [UInt32] {
        let order = centers.indices.sorted { a, b in
            let da = simd_distance_squared(centers[a], camera)
            let db = simd_distance_squared(centers[b], camera)
            return da == db ? a < b : da > db
        }
        return order.flatMap { face in (0..<6).map { UInt32(face * 6 + $0) } }
    }
}
