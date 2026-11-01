import MinecraftCore
import simd

struct RenderMotion {
    private var lastPosition: SIMD3<Double>?
    private var walkedDistance: Float = 0
    private var amplitude: Float = 0
    private var tilt: Float = 0

    mutating func update(
        position: SIMD3<Double>, velocity: SIMD3<Double>, onGround: Bool, alive: Bool,
        delta: Float, enabled: Bool
    ) -> simd_float4x4 {
        if let lastPosition {
            let difference = position - lastPosition
            let distance = sqrt(difference.x * difference.x + difference.z * difference.z)
            if distance < 4 { walkedDistance += Float(distance) * 0.6 } else { walkedDistance = 0 }
        }
        lastPosition = position
        let targetAmplitude =
            onGround && alive ? min(0.1, Float(sqrt(velocity.x * velocity.x + velocity.z * velocity.z))) : 0
        let targetTilt = !onGround && alive ? Float(atan(-velocity.y * 0.2)) * 15 : 0
        amplitude += (targetAmplitude - amplitude) * (1 - pow(0.6, delta * 20))
        tilt += (targetTilt - tilt) * (1 - pow(0.2, delta * 20))
        guard enabled else { return matrix_identity_float4x4 }
        let phase = -walkedDistance * .pi
        return HeldItemGeometry.translation(
            SIMD3(sin(phase) * amplitude * 0.5, -abs(cos(phase) * amplitude), 0))
            * HeldItemGeometry.rotation(sin(phase) * amplitude * 3, axis: SIMD3(0, 0, 1))
            * HeldItemGeometry.rotation(abs(cos(phase - 0.2) * amplitude) * 5 + tilt, axis: SIMD3(1, 0, 0))
    }
}
