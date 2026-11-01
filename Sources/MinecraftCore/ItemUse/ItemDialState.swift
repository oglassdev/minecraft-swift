import Foundation

public struct ItemDialState: Sendable {
    public private(set) var angle: Double = 0
    private var velocity: Double = 0

    public init() {}

    public mutating func tickCompass(
        position: SIMD3<Double>, yaw: Float, spawn: BlockPosition,
        dimension: Int8, random: inout JavaRandom
    ) {
        let originalYaw = yaw * 180 / Float(Double.pi) + 180
        var target =
            Double(originalYaw - 90) * .pi / 180
            - atan2(Double(spawn.z) - position.z, Double(spawn.x) - position.x)
        if dimension == -1 { target = random.nextDouble() * Double(Float(Double.pi)) * 2 }
        tick(target: target)
    }

    public mutating func tickClock(celestialAngle: Float, dimension: Int8, random: inout JavaRandom) {
        var target = Double(-celestialAngle * Float(Double.pi) * 2)
        if dimension == -1 { target = random.nextDouble() * Double(Float(Double.pi)) * 2 }
        tick(target: target)
    }

    private mutating func tick(target: Double) {
        var difference = target - angle
        while difference < -.pi { difference += .pi * 2 }
        while difference >= .pi { difference -= .pi * 2 }
        difference = min(1, max(-1, difference))
        velocity = (velocity + difference * 0.1) * 0.8
        angle += velocity
    }
}
