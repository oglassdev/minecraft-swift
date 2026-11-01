import Foundation

public enum EntityCollision {
    public static func boxes(
        moving mover: GameEntity?, among bodies: [GameEntity], intersecting bounds: AxisAlignedBox
    ) -> [AxisAlignedBox] {
        boxes(
            movingID: mover?.id, vehicle: mover?.kind == "boat" || mover?.kind == "minecart",
            among: bodies, intersecting: bounds)
    }

    static func boxes(
        movingID: Int64?, vehicle: Bool, among bodies: borrowing [GameEntity],
        intersecting bounds: AxisAlignedBox
    ) -> [AxisAlignedBox] {
        var result: [AxisAlignedBox] = []
        for index in bodies.indices
        where bodies[index].id != movingID && bodies[index].kind != "lightningBolt"
            && (vehicle || bodies[index].kind == "boat")
            && (bodies[index].health > 0 || (bodies[index].isLiving && bodies[index].deathTicks <= 20))
        {
            let box = bodies[index].bounds
            guard box.intersects(bounds) else { continue }
            if bodies[index].kind == "boat" { result.append(box) }
            if vehicle { result.append(box) }
        }
        return result
    }

    static func push(receiver: inout GameEntity, other: inout GameEntity, mayMount: Bool = true) {
        guard receiver.riderID != other.id, other.riderID != receiver.id else { return }
        let delta = other.position - receiver.position
        if receiver.kind == "minecart" {
            if mayMount && other.isLiving && other.kind != "player" && receiver.metadata == 0
                && receiver.velocity.x * receiver.velocity.x + receiver.velocity.z * receiver.velocity.z
                    > 0.01
                && receiver.riderID == nil
            {
                receiver.riderID = other.id
            }
            let square = delta.x * delta.x + delta.z * delta.z
            guard square >= Double(Float(0.0001)) else { return }
            let distance = Double(Float(sqrt(square)))
            let impulse =
                SIMD3(delta.x, 0, delta.z) / distance * min(1 / distance, 1) * Double(Float(0.1)) * 0.5
            if other.kind == "minecart" {
                let alignment = delta.x * other.velocity.z + delta.z * other.previousPosition.x
                guard alignment * alignment <= 5 else { return }
                if other.metadata == 2 && receiver.metadata != 2 {
                    receiver.velocity.x *= Double(Float(0.2))
                    receiver.velocity.z *= Double(Float(0.2))
                    receiver.velocity += SIMD3(other.velocity.x, 0, other.velocity.z) - impulse
                    other.velocity.x *= Double(Float(0.7))
                    other.velocity.z *= Double(Float(0.7))
                } else if other.metadata != 2 && receiver.metadata == 2 {
                    other.velocity.x *= Double(Float(0.2))
                    other.velocity.z *= Double(Float(0.2))
                    other.velocity += SIMD3(receiver.velocity.x, 0, receiver.velocity.z) + impulse
                    receiver.velocity.x *= Double(Float(0.7))
                    receiver.velocity.z *= Double(Float(0.7))
                } else {
                    let average = SIMD3(
                        (receiver.velocity.x + other.velocity.x) / 2, 0,
                        (receiver.velocity.z + other.velocity.z) / 2)
                    receiver.velocity.x *= Double(Float(0.2))
                    receiver.velocity.z *= Double(Float(0.2))
                    receiver.velocity += average - impulse
                    other.velocity.x *= Double(Float(0.2))
                    other.velocity.z *= Double(Float(0.2))
                    other.velocity += average + impulse
                }
            } else {
                receiver.velocity -= impulse
                other.velocity += impulse / 4
            }
        } else {
            let maximum = max(abs(delta.x), abs(delta.z))
            guard maximum >= Double(Float(0.01)) else { return }
            let distance = Double(Float(sqrt(maximum)))
            let impulse = SIMD3(delta.x, 0, delta.z) / distance * min(1 / distance, 1) * Double(Float(0.05))
            receiver.velocity -= impulse
            other.velocity += impulse
        }
    }
}

extension EntitySimulation {
    public func collisionBoxes(for entityID: Int64? = nil, intersecting bounds: AxisAlignedBox)
        -> [AxisAlignedBox]
    {
        EntityCollision.boxes(
            moving: entityID.flatMap { id in entities.first { $0.id == id } }, among: entities,
            intersecting: bounds)
    }

    public mutating func applyPlayerCollisions(player: inout Player) {
        var actor = GameEntity(id: 0, kind: "player", position: player.position, velocity: player.velocity)
        let nearby = player.bounds.expanded(by: SIMD3(Double(Float(0.2)), 0, Double(Float(0.2))))
        for index in contactCandidates(in: nearby)
        where entities[index].bounds.intersects(nearby)
            && (entities[index].isLiving || ["boat", "minecart"].contains(entities[index].kind))
            && (entities[index].health > 0
                || (entities[index].isLiving && entities[index].deathTicks <= 20))
        {
            let before = actor.velocity
            let mounted = ridingEntityID(for: actor.id) != nil
            EntityCollision.push(receiver: &entities[index], other: &actor, mayMount: !mounted)
            refreshSpatialBody(at: index)
            player.addVelocity(actor.velocity - before)
        }
    }

    mutating func applyEntityContacts(_ actor: inout GameEntity, player: inout Player) {
        let nearby = actor.bounds.expanded(by: SIMD3(Double(Float(0.2)), 0, Double(Float(0.2))))
        let onlyKind = ["boat", "minecart"].contains(actor.kind) ? actor.kind : nil
        for index in contactCandidates(in: nearby)
        where entities[index].id != actor.id && entities[index].bounds.intersects(nearby)
            && (entities[index].isLiving || ["boat", "minecart"].contains(entities[index].kind))
            && (entities[index].health > 0
                || (entities[index].isLiving && entities[index].deathTicks <= 20))
            && (onlyKind == nil || entities[index].kind == onlyKind)
        {
            let mounted = ridingEntityID(for: actor.id) != nil
            EntityCollision.push(receiver: &entities[index], other: &actor, mayMount: !mounted)
            refreshSpatialBody(at: index)
        }
        if actor.isLiving
            && actor.bounds.intersects(
                player.bounds.expanded(by: SIMD3(Double(Float(0.2)), 0, Double(Float(0.2)))))
        {
            var body = GameEntity(id: 0, kind: "player", position: player.position, velocity: player.velocity)
            let before = body.velocity
            EntityCollision.push(receiver: &body, other: &actor)
            player.addVelocity(body.velocity - before)
        }
    }
}
