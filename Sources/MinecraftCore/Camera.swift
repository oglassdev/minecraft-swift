import Foundation

public struct MovementInput: Sendable {
    public var forward: Float
    public var right: Float
    public var up: Float
    public var fast: Bool

    public init(forward: Float = 0, right: Float = 0, up: Float = 0, fast: Bool = false) {
        self.forward = forward
        self.right = right
        self.up = up
        self.fast = fast
    }
}

/// A free-flight camera for exploring the renderer before player physics exists.
public struct Camera: Sendable {
    public private(set) var position: SIMD3<Float>
    public private(set) var yaw: Float
    public private(set) var pitch: Float

    public init(
        position: SIMD3<Float> = SIMD3(14, 10, 20),
        yaw: Float = -0.62,
        pitch: Float = -0.3
    ) {
        self.position = position
        self.yaw = yaw
        self.pitch = min(max(pitch, -Self.pitchLimit), Self.pitchLimit)
    }

    private static let pitchLimit: Float = .pi / 2 - 0.01

    public var forward: SIMD3<Float> {
        SIMD3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
    }

    public mutating func look(horizontal: Float, vertical: Float) {
        yaw = (yaw + horizontal).remainder(dividingBy: 2 * .pi)
        pitch = min(max(pitch + vertical, -Self.pitchLimit), Self.pitchLimit)
    }

    public mutating func setPosition(_ position: SIMD3<Float>) { self.position = position }

    public mutating func move(_ input: MovementInput, deltaTime: Float) {
        let right = SIMD3<Float>(cos(yaw), 0, sin(yaw))
        var direction = forward * input.forward + right * input.right
        direction.y += input.up
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        if length > 1 { direction /= length }
        position += direction * (input.fast ? 15 : 5) * max(deltaTime, 0)
    }
}
