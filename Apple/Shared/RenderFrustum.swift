import MinecraftCore
import simd

struct RenderFrustum {
    private let planes: [SIMD4<Float>]

    init(matrix: simd_float4x4) {
        let a = matrix.columns
        let x = SIMD4(a.0.x, a.1.x, a.2.x, a.3.x)
        let y = SIMD4(a.0.y, a.1.y, a.2.y, a.3.y)
        let z = SIMD4(a.0.z, a.1.z, a.2.z, a.3.z)
        let w = SIMD4(a.0.w, a.1.w, a.2.w, a.3.w)
        planes = [w + x, w - x, w + y, w - y, z, w - z]
    }

    func intersects(minimum: SIMD3<Float>, maximum: SIMD3<Float>) -> Bool {
        for plane in planes {
            let corner = SIMD3(
                plane.x >= 0 ? maximum.x : minimum.x,
                plane.y >= 0 ? maximum.y : minimum.y, plane.z >= 0 ? maximum.z : minimum.z)
            if simd_dot(SIMD3(plane.x, plane.y, plane.z), corner) + plane.w < 0 { return false }
        }
        return true
    }

    func contains(chunk: ChunkPosition, origin: SIMD3<Double>) -> Bool {
        let minimum = SIMD3(Float(Double(chunk.x * 16) - origin.x), 0, Float(Double(chunk.z * 16) - origin.z))
        return intersects(minimum: minimum, maximum: minimum + SIMD3(16, 128, 16))
    }
}
