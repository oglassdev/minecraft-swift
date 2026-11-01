import MinecraftCore
import simd

/// Geometry is expressed relative to the camera, as in RenderGlobal's display lists.
enum BetaSkyGeometry {
    static func plane(height: Float) -> [BlockVertex] {
        var result: [BlockVertex] = []
        for x in stride(from: -384, through: 384, by: 64) {
            for z in stride(from: -384, through: 384, by: 64) {
                appendQuad(
                    [
                        SIMD3(Float(x), height, Float(z)), SIMD3(Float(x + 64), height, Float(z)),
                        SIMD3(Float(x + 64), height, Float(z + 64)), SIMD3(Float(x), height, Float(z + 64)),
                    ],
                    textured: false, to: &result)
            }
        }
        return result
    }

    static func celestial(moon: Bool) -> [BlockVertex] {
        var result: [BlockVertex] = []
        if moon {
            appendQuad(
                [SIMD3(-20, -100, 20), SIMD3(20, -100, 20), SIMD3(20, -100, -20), SIMD3(-20, -100, -20)],
                uv: [SIMD2(1, 1), SIMD2(0, 1), SIMD2(0, 0), SIMD2(1, 0)], to: &result)
        } else {
            appendQuad(
                [SIMD3(-30, 100, -30), SIMD3(30, 100, -30), SIMD3(30, 100, 30), SIMD3(-30, 100, 30)],
                uv: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)], to: &result)
        }
        return result
    }

    static func sunrise(opacity: Float) -> [BlockVertex] {
        let center = BlockVertex(
            position: SIMD3(0, 100, 0), color: SIMD3(repeating: 1), textureWeight: 0, light: 255)
        let ring = (0...16).map { index -> BlockVertex in
            let angle = Float(index) * BetaVisualMath.pi * 2 / 16
            let sine = BetaVisualMath.sine(angle)
            let cosine = BetaVisualMath.cosine(angle)
            return BlockVertex(
                position: SIMD3(sine * 120, cosine * 120, -cosine * 40 * opacity),
                color: SIMD3(repeating: 1), opacity: 0, textureWeight: 0, light: 255)
        }
        return (0..<16).flatMap { [center, ring[$0], ring[$0 + 1]] }
    }

    static func fastClouds() -> [BlockVertex] {
        var result: [BlockVertex] = []
        for x in stride(from: -256, to: 256, by: 32) {
            for z in stride(from: -256, to: 256, by: 32) {
                let x = Float(x)
                let z = Float(z)
                appendQuad(
                    [SIMD3(x, 0, z + 32), SIMD3(x + 32, 0, z + 32), SIMD3(x + 32, 0, z), SIMD3(x, 0, z)],
                    uv: [SIMD2(x, z + 32), SIMD2(x + 32, z + 32), SIMD2(x + 32, z), SIMD2(x, z)].map {
                        $0 / 2048
                    },
                    to: &result)
            }
        }
        return result
    }

    static func fancyClouds(bottom: Bool, top: Bool) -> [BlockVertex] {
        var result: [BlockVertex] = []
        let epsilon: Float = 1 / 1024
        for patchX in -2...3 {
            for patchZ in -2...3 {
                let x = Float(patchX * 8)
                let z = Float(patchZ * 8)
                let uv = [SIMD2(x, z + 8), SIMD2(x + 8, z + 8), SIMD2(x + 8, z), SIMD2(x, z)].map { $0 / 256 }
                if bottom {
                    appendQuad(
                        [SIMD3(x, 0, z + 8), SIMD3(x + 8, 0, z + 8), SIMD3(x + 8, 0, z), SIMD3(x, 0, z)],
                        uv: uv, shade: 0.7, to: &result)
                }
                if top {
                    appendQuad(
                        [
                            SIMD3(x, 4 - epsilon, z + 8), SIMD3(x + 8, 4 - epsilon, z + 8),
                            SIMD3(x + 8, 4 - epsilon, z), SIMD3(x, 4 - epsilon, z),
                        ], uv: uv, to: &result)
                }
                for face in 0..<4 {
                    let visible = [patchX > -1, patchX <= 1, patchZ > -1, patchZ <= 1][face]
                    guard visible else { continue }
                    for texel in 0..<8 {
                        let i = Float(texel)
                        if face < 2 {
                            let faceX = x + i + (face == 0 ? 0 : 1 - epsilon)
                            let u = (x + i + 0.5) / 256
                            appendQuad(
                                [
                                    SIMD3(faceX, 0, z + 8), SIMD3(faceX, 4, z + 8), SIMD3(faceX, 4, z),
                                    SIMD3(faceX, 0, z),
                                ],
                                uv: [
                                    SIMD2(u, (z + 8) / 256), SIMD2(u, (z + 8) / 256), SIMD2(u, z / 256),
                                    SIMD2(u, z / 256),
                                ],
                                shade: 0.9, to: &result)
                        } else {
                            let faceZ = z + i + (face == 2 ? 0 : 1 - epsilon)
                            let v = (z + i + 0.5) / 256
                            appendQuad(
                                [
                                    SIMD3(x, 4, faceZ), SIMD3(x + 8, 4, faceZ), SIMD3(x + 8, 0, faceZ),
                                    SIMD3(x, 0, faceZ),
                                ],
                                uv: [
                                    SIMD2(x / 256, v), SIMD2((x + 8) / 256, v), SIMD2((x + 8) / 256, v),
                                    SIMD2(x / 256, v),
                                ],
                                shade: 0.8, to: &result)
                        }
                    }
                }
            }
        }
        return result
    }

    struct CloudPlacement {
        let offset: SIMD3<Float>
        let uv: SIMD2<Float>
        let scale: SIMD3<Float>
        let bottom: Bool
        let top: Bool
    }

    static func cloudPlacement(position: SIMD3<Double>, ticks: Int, partial: Float, fancy: Bool)
        -> CloudPlacement
    {
        let drift = Double((Float(ticks) + partial) * 0.03)
        let height = 108 - Float(position.y) + 0.33
        if fancy {
            let x = (position.x + drift) / 12
            let z = position.z / 12 + Double(Float(0.33))
            let floorX = floor(x)
            let floorZ = floor(z)
            return CloudPlacement(
                offset: SIMD3(-Float(x - floorX), height, -Float(z - floorZ)),
                uv: SIMD2(
                    Float(floorX.truncatingRemainder(dividingBy: 256)) / 256,
                    Float(floorZ.truncatingRemainder(dividingBy: 256)) / 256),
                scale: SIMD3(12, 1, 12), bottom: height > -5, top: height <= 5)
        }
        let x = position.x + drift
        let z = position.z
        return CloudPlacement(
            offset: SIMD3(0, height, 0),
            uv: SIMD2(Float(x - floor(x / 2048) * 2048) / 2048, Float(z - floor(z / 2048) * 2048) / 2048),
            scale: SIMD3(repeating: 1), bottom: true, top: false)
    }

    private static func appendQuad(
        _ positions: [SIMD3<Float>],
        uv: [SIMD2<Float>] = [.zero, .zero, .zero, .zero], shade: Float = 1, textured: Bool = true,
        to result: inout [BlockVertex]
    ) {
        result += [0, 1, 2, 0, 2, 3].map {
            BlockVertex(
                position: positions[$0], color: SIMD3(repeating: shade), uv: uv[$0],
                opacity: 1, textureWeight: textured ? 1 : 0, light: 255)
        }
    }
}
