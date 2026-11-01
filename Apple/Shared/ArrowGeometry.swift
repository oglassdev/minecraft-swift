import MinecraftCore
import simd

enum ArrowGeometry {
    static func vertices(
        position: SIMD3<Float>, yaw: Float, pitch: Float, shake: Float, light: UInt8
    ) -> [BlockVertex] {
        let wobble = shake > 0 ? -BetaVisualMath.sine(shake * 3) * shake * Float(Double.pi / 180) : 0
        let heading = simd_float4x4(
            simd_quatf(angle: Float(Double.pi / 2) - yaw, axis: SIMD3(0, 1, 0)))
        let elevation = simd_float4x4(simd_quatf(angle: pitch + wobble, axis: SIMD3(0, 0, 1)))
        let roll = simd_float4x4(simd_quatf(angle: Float(Double.pi / 4), axis: SIMD3(1, 0, 0)))
        let transform = heading * elevation * roll
        let scale: Float = 0.05625
        var result: [BlockVertex] = []
        result.reserveCapacity(36)
        func quad(_ points: [SIMD3<Float>], uv: [SIMD2<Float>], rotation: simd_float4x4) {
            for index in [0, 1, 2, 0, 2, 3] {
                let rotated = rotation * SIMD4(points[index], 1)
                let local = (SIMD3(rotated.x, rotated.y, rotated.z) - SIMD3(4, 0, 0)) * scale
                let point = transform * SIMD4(local, 1)
                result.append(
                    BlockVertex(
                        position: position + SIMD3(point.x, point.y, point.z),
                        color: SIMD3(repeating: 1), uv: uv[index], light: light))
            }
        }
        let capUV: [SIMD2<Float>] = [
            SIMD2(0, 5.0 / 32), SIMD2(5.0 / 32, 5.0 / 32),
            SIMD2(5.0 / 32, 10.0 / 32), SIMD2(0, 10.0 / 32),
        ]
        quad(
            [SIMD3(-7, -2, -2), SIMD3(-7, -2, 2), SIMD3(-7, 2, 2), SIMD3(-7, 2, -2)],
            uv: capUV, rotation: matrix_identity_float4x4)
        quad(
            [SIMD3(-7, 2, -2), SIMD3(-7, 2, 2), SIMD3(-7, -2, 2), SIMD3(-7, -2, -2)],
            uv: capUV, rotation: matrix_identity_float4x4)
        let vaneUV: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(0.5, 5.0 / 32), SIMD2(0, 5.0 / 32),
        ]
        for quarter in 1...4 {
            let rotation = simd_float4x4(
                simd_quatf(angle: Float(quarter) * Float(Double.pi / 2), axis: SIMD3(1, 0, 0)))
            quad(
                [SIMD3(-8, -2, 0), SIMD3(8, -2, 0), SIMD3(8, 2, 0), SIMD3(-8, 2, 0)],
                uv: vaneUV, rotation: rotation)
        }
        return result
    }
}
