import MinecraftCore
import simd

enum BetaVisualMath {
    static let pi = Float(Double.pi)
    static func sine(_ value: Float) -> Float {
        Float(sin(Double(Int(value * 10430.378) & 65535) * .pi * 2 / 65536))
    }
    static func cosine(_ value: Float) -> Float {
        Float(sin(Double(Int(value * 10430.378 + 16384) & 65535) * .pi * 2 / 65536))
    }
}

enum RenderMotion {
    static func thirdPersonPosition(world: BlockWorld, eye: SIMD3<Double>, forward: SIMD3<Float>) -> SIMD3<
        Double
    > {
        let backward = -SIMD3<Double>(forward)
        var distance: Double = 4
        for corner in 0..<8 {
            let offset = SIMD3<Double>(
                Double(Float((corner & 1) * 2 - 1) * 0.1),
                Double(Float((corner >> 1 & 1) * 2 - 1) * 0.1), Double(Float((corner >> 2 & 1) * 2 - 1) * 0.1)
            )
            let start = eye + offset
            let end = eye + backward * 4 + offset + SIMD3(offset.z, 0, 0)
            let direction = end - start
            if let hit = BlockRaycast.hit(
                in: world, origin: start, direction: direction, reach: simd_length(direction))
            {
                distance = min(distance, simd_distance(hit.point, eye))
            }
        }
        return eye + backward * distance
    }

    static func bobbing(player: Player, partial: Float, enabled: Bool) -> simd_float4x4 {
        guard enabled else { return matrix_identity_float4x4 }
        let phase =
            -(player.walkedDistance + (player.walkedDistance - player.previousWalkedDistance) * partial)
        let amplitude = player.previousCameraYaw + (player.cameraYaw - player.previousCameraYaw) * partial
        let tilt = player.previousCameraPitch + (player.cameraPitch - player.previousCameraPitch) * partial
        return bobbing(phase: phase, amplitude: amplitude, tilt: tilt)
    }

    static func bobbing(phase: Float, amplitude: Float, tilt: Float) -> simd_float4x4 {
        let sine = BetaVisualMath.sine(phase * BetaVisualMath.pi)
        let cosine = BetaVisualMath.cosine(phase * BetaVisualMath.pi)
        return HeldItemGeometry.translation(SIMD3(sine * amplitude * 0.5, -abs(cosine * amplitude), 0))
            * HeldItemGeometry.rotation(sine * amplitude * 3, axis: SIMD3(0, 0, 1))
            * HeldItemGeometry.rotation(
                abs(BetaVisualMath.cosine(phase * BetaVisualMath.pi - 0.2) * amplitude) * 5 + tilt,
                axis: SIMD3(1, 0, 0))
    }

    static func hurt(player: Player, partial: Float) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        if player.health <= 0 {
            matrix = HeldItemGeometry.rotation(
                40 - 8000 / (Float(player.deathTime) + partial + 200), axis: SIMD3(0, 0, 1))
        }
        let remaining = Float(player.hurtTime) - partial
        if remaining >= 0, player.maxHurtTime > 0 {
            var progress = remaining / Float(player.maxHurtTime)
            progress *= progress
            progress *= progress
            let roll = -BetaVisualMath.sine(progress * BetaVisualMath.pi) * 14
            matrix *=
                HeldItemGeometry.rotation(-player.attackedAtYaw, axis: SIMD3(0, 1, 0))
                * HeldItemGeometry.rotation(roll, axis: SIMD3(0, 0, 1))
                * HeldItemGeometry.rotation(player.attackedAtYaw, axis: SIMD3(0, 1, 0))
        }
        return matrix
    }

    static func portal(amount: Float, time: Float) -> simd_float4x4 {
        guard amount > 0 else { return matrix_identity_float4x4 }
        var factor = 5 / (amount * amount + 5) - amount * 0.04
        factor *= factor
        let axis = simd_normalize(SIMD3<Float>(0, 1, 1))
        return HeldItemGeometry.rotation(time * 20, axis: axis)
            * simd_float4x4(diagonal: SIMD4(1 / factor, 1, 1, 1))
            * HeldItemGeometry.rotation(-time * 20, axis: axis)
    }

    static func swing(previous: Float, current: Float, partial: Float) -> Float {
        var difference = current - previous
        if difference < 0 { difference += 1 }
        return previous + difference * partial
    }
}
