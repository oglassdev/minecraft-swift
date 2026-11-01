import simd

enum BetaLighting {
    private static let first = simd_normalize(SIMD3<Float>(0.2, 1, -0.7))
    private static let second = simd_normalize(SIMD3<Float>(-0.2, 1, 0.7))

    static func shade(normal: SIMD3<Float>) -> Float {
        min(1, 0.4 + 0.6 * (max(0, simd_dot(normal, first)) + max(0, simd_dot(normal, second))))
    }

    static func guiShade(normal: SIMD3<Float>) -> Float {
        let sine = Float(sqrt(3.0) / 2)
        return shade(
            normal: SIMD3(normal.x, -0.5 * normal.y + sine * normal.z, -sine * normal.y - 0.5 * normal.z))
    }

    static func brightness(level: Int, ambient: Float = 0.05) -> Float {
        let darkness = 1 - Float(min(15, max(0, level))) / 15
        return (1 - darkness) / (darkness * 3 + 1) * (1 - ambient) + ambient
    }
}
