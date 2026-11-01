import MinecraftCore
import simd

enum EntityDecorationGeometry {
    static func painting(entity: GameEntity, position: SIMD3<Float>, world: BlockWorld) -> [BlockVertex] {
        guard let motive = BetaPainting.motive(named: entity.paintingMotive ?? "Kebab") else { return [] }
        let angle = Float(entity.paintingFacing) * .pi / 2
        let center = position + SIMD3(0, Float(motive.pixelHeight) / 32, 0)
        var vertices: [BlockVertex] = []
        for x in 0..<motive.pixelWidth / 16 {
            for y in 0..<motive.pixelHeight / 16 {
                let lowX = -Float(motive.pixelWidth) / 2 + Float(x * 16)
                let highX = lowX + 16
                let lowY = -Float(motive.pixelHeight) / 2 + Float(y * 16)
                let highY = lowY + 16
                let u0 = Float(motive.textureX + motive.pixelWidth - (x + 1) * 16) / 256
                let u1 = u0 + 1 / 16
                let v0 = Float(motive.textureY + motive.pixelHeight - (y + 1) * 16) / 256
                let v1 = v0 + 1 / 16
                let offset = EntityModelPart.rotate(
                    SIMD3((lowX + highX) / 32, (lowY + highY) / 32, 0), by: SIMD3(0, angle, 0))
                let samplePosition =
                    entity.position + SIMD3(0, Double(motive.pixelHeight) / 32, 0) + SIMD3<Double>(offset)
                let sample = world.light(
                    at: BlockPosition(
                        Int(floor(samplePosition.x)), Int(floor(samplePosition.y)),
                        Int(floor(samplePosition.z))))
                let light = sample.sky << 4 | sample.block
                func quad(_ points: [SIMD3<Float>], _ uv: [SIMD2<Float>], shade: Float = 1) {
                    vertices += [0, 1, 2, 0, 2, 3].map {
                        BlockVertex(
                            position: center
                                + EntityModelPart.rotate(points[$0] / 16, by: SIMD3(0, angle, 0)),
                            color: SIMD3(repeating: shade), uv: uv[$0], light: light)
                    }
                }
                quad(
                    [
                        SIMD3(highX, lowY, -0.5), SIMD3(lowX, lowY, -0.5), SIMD3(lowX, highY, -0.5),
                        SIMD3(highX, highY, -0.5),
                    ],
                    [SIMD2(u0, v1), SIMD2(u1, v1), SIMD2(u1, v0), SIMD2(u0, v0)])
                quad(
                    [
                        SIMD3(highX, highY, 0.5), SIMD3(lowX, highY, 0.5), SIMD3(lowX, lowY, 0.5),
                        SIMD3(highX, lowY, 0.5),
                    ],
                    [SIMD2(0.75, 0), SIMD2(0.8125, 0), SIMD2(0.8125, 0.0625), SIMD2(0.75, 0.0625)], shade: 0.8
                )
                for vertical in [lowY, highY] {
                    quad(
                        [
                            SIMD3(highX, vertical, -0.5), SIMD3(lowX, vertical, -0.5),
                            SIMD3(lowX, vertical, 0.5), SIMD3(highX, vertical, 0.5),
                        ],
                        [
                            SIMD2(0.75, 0.001953125), SIMD2(0.8125, 0.001953125), SIMD2(0.8125, 0.001953125),
                            SIMD2(0.75, 0.001953125),
                        ], shade: 0.7)
                }
                for horizontal in [lowX, highX] {
                    quad(
                        [
                            SIMD3(horizontal, highY, 0.5), SIMD3(horizontal, lowY, 0.5),
                            SIMD3(horizontal, lowY, -0.5), SIMD3(horizontal, highY, -0.5),
                        ],
                        [
                            SIMD2(0.7519531, 0), SIMD2(0.7519531, 0.0625), SIMD2(0.7519531, 0.0625),
                            SIMD2(0.7519531, 0),
                        ], shade: 0.7)
                }
            }
        }
        return vertices
    }

    static func fishingLine(from hook: SIMD3<Float>, to hand: SIMD3<Float>, camera: Camera) -> [BlockVertex] {
        let start = hook + SIMD3(0, 0.25, 0)
        let difference = hand - start
        let right = simd_normalize(simd_cross(camera.forward, SIMD3(0, 1, 0))) * 0.002
        var vertices: [BlockVertex] = []
        for segment in 0..<16 {
            let a = Float(segment) / 16
            let b = Float(segment + 1) / 16
            let low = start + SIMD3(difference.x * a, difference.y * (a * a + a) / 2, difference.z * a)
            let high = start + SIMD3(difference.x * b, difference.y * (b * b + b) / 2, difference.z * b)
            let points = [low - right, low + right, high + right, high - right]
            vertices += [0, 1, 2, 0, 2, 3].map {
                BlockVertex(position: points[$0], color: .zero, textureWeight: 0)
            }
        }
        return vertices
    }
}
