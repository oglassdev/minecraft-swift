import Foundation

public enum PlayerDrop {
    public static func velocity(
        yaw: Float, pitch: Float, random: inout JavaRandom, scatter: Bool = false
    ) -> SIMD3<Double> {
        if scatter {
            let speed = random.nextFloat() * 0.5
            let angle = random.nextFloat() * Float(Double.pi) * 2
            return SIMD3(Double(-sine(angle) * speed), Double(Float(0.2)), Double(cosine(angle) * speed))
        }
        let sourceYaw = (yaw * 180 / Float(Double.pi) + 180) / 180 * Float(Double.pi)
        let sourcePitch = (-pitch * 180 / Float(Double.pi)) / 180 * Float(Double.pi)
        var result = SIMD3(
            Double(-sine(sourceYaw) * cosine(sourcePitch) * 0.3),
            Double(-sine(sourcePitch) * 0.3 + 0.1),
            Double(cosine(sourceYaw) * cosine(sourcePitch) * 0.3))
        let angle = random.nextFloat() * Float(Double.pi) * 2
        let spread = Float(0.02) * random.nextFloat()
        result.x += cos(Double(angle)) * Double(spread)
        result.y += Double((random.nextFloat() - random.nextFloat()) * 0.1)
        result.z += sin(Double(angle)) * Double(spread)
        return result
    }

    private static func sine(_ radians: Float) -> Float { sines[Int(radians * 10430.378) & 65535] }
    private static func cosine(_ radians: Float) -> Float { sines[Int(radians * 10430.378 + 16384) & 65535] }
    private static let sines = (0..<65536).map { Float(sin(Double($0) * .pi * 2 / 65536)) }
}
