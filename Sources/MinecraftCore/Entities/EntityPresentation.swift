import Foundation

extension GameEntity {
    mutating func updateLimbSwing() {
        previousLimbSwingAmount = limbSwingAmount
        let delta = position - previousPosition
        let speed = min(Float(sqrt(delta.x * delta.x + delta.z * delta.z)) * 4, 1)
        limbSwingAmount += (speed - limbSwingAmount) * 0.4
        limbSwing += limbSwingAmount
    }

    mutating func updateBodyYaw() {
        guard isLiving else { return }
        let delta = position - previousPosition
        let speed = Float(sqrt(delta.x * delta.x + delta.z * delta.z))
        var target = bodyYawDegrees
        if speed > 0.05 { target = Float(atan2(delta.z, delta.x)) * 180 / BetaMath.pi - 90 }
        let head = (yaw + BetaMath.pi) * 180 / BetaMath.pi
        var difference = Self.wrappedDegrees(target - bodyYawDegrees)
        bodyYawDegrees += difference * 0.3
        difference = Self.wrappedDegrees(head - bodyYawDegrees)
        difference = min(max(difference, -75), 75)
        bodyYawDegrees = head - difference
        if difference * difference > 2500 { bodyYawDegrees += difference * 0.2 }
        while bodyYawDegrees - previousBodyYawDegrees < -180 { previousBodyYawDegrees -= 360 }
        while bodyYawDegrees - previousBodyYawDegrees >= 180 { previousBodyYawDegrees += 360 }
    }

    static func wrappedDegrees(_ degrees: Float) -> Float {
        var result = degrees.truncatingRemainder(dividingBy: 360)
        if result < -180 { result += 360 }
        if result >= 180 { result -= 360 }
        return result
    }

    mutating func updateChickenWings() {
        previousWingRotation = wingRotation
        previousWingSpread = wingSpread
        wingSpread = min(max(Float(Double(wingSpread) + Double(onGround ? -1 : 4) * 0.3), 0), 1)
        if !onGround && wingSpeed < 1 { wingSpeed = 1 }
        wingSpeed = Float(Double(wingSpeed) * 0.9)
        if !onGround && velocity.y < 0 { velocity.y *= 0.6 }
        wingRotation += wingSpeed * 2
    }
}
