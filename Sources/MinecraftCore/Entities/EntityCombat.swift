import Foundation

struct LivingTarget {
    var id: Int64
    var kind: String
    var position: SIMD3<Double>
    var feet: SIMD3<Double>
    var eye: SIMD3<Double>
    var bounds: AxisAlignedBox
    var health: Int
}

extension EntitySimulation {
    func livingTarget(id: Int64?, player: Player) -> LivingTarget? {
        guard let id else { return nil }
        if id == 0 {
            return LivingTarget(
                id: 0, kind: "player", position: player.eyePositionDouble, feet: player.position,
                eye: player.eyePositionDouble + SIMD3(0, Double(Float(0.12)), 0), bounds: player.bounds,
                health: player.health)
        }
        guard let entity = entities.first(where: { $0.id == id && $0.isLiving }) else { return nil }
        return LivingTarget(
            id: id, kind: entity.kind, position: entity.position, feet: entity.position,
            eye: entity.eyePosition,
            bounds: entity.bounds, health: entity.health)
    }

    func canSee(_ entity: GameEntity, target: LivingTarget, world: BlockWorld) -> Bool {
        let delta = target.eye - entity.eyePosition
        return BlockRaycast.hit(
            in: world, origin: entity.eyePosition, direction: delta,
            reach: sqrt(EntityMotion.squaredLength(delta))) == nil
    }

    @discardableResult
    mutating func melee(
        _ entity: inout GameEntity, target: LivingTarget, amount: Int, player: inout Player,
        inventory: inout PlayerInventory
    ) -> Bool {
        if target.id == 0 {
            let source: PlayerDamageSource =
                ["wolf", "slime"].contains(entity.kind) ? .environment : .monster
            let accepted = player.damage(amount, source: source, inventory: &inventory)
            if accepted {
                player.knockBack(from: entity.position)
                alertOwnedWolves(against: entity.id, from: player.eyePositionDouble, defending: true)
                queuedEvents.append(
                    .sound(name: "random.hurt", position: player.eyePositionDouble, volume: 1, pitch: 1))
            }
            return accepted
        }
        guard let index = entities.firstIndex(where: { $0.id == target.id }) else { return false }
        return hurtEntity(at: index, amount: amount, sourcePosition: entity.position, sourceID: entity.id)
    }

    mutating func alertOwnedWolves(against targetID: Int64, from position: SIMD3<Double>, defending: Bool) {
        guard let target = entities.first(where: { $0.id == targetID }), target.isLiving, target.health > 0,
            !["creeper", "ghast"].contains(target.kind),
            !(target.kind == "wolf" && target.owner?.caseInsensitiveCompare(localPlayerName) == .orderedSame)
        else { return }
        let area = AxisAlignedBox(min: position - SIMD3(16, 4, 16), max: position + SIMD3(17, 5, 17))
        for index in entities.indices
        where entities[index].kind == "wolf" && entities[index].health > 0
            && entities[index].owner?.caseInsensitiveCompare(localPlayerName) == .orderedSame
            && entities[index].targetEntityID == nil && (defending || entities[index].metadata & 1 == 0)
            && entities[index].bounds.intersects(area)
        {
            entities[index].metadata &= ~1
            entities[index].targetEntityID = targetID
        }
    }

    mutating func retaliate(_ entity: inout GameEntity, index: Int, sourceID: Int64?) {
        guard let sourceID, sourceID != entity.id,
            sourceID == 0 || entities.contains(where: { $0.id == sourceID && $0.isLiving })
        else { return }
        if ["zombie", "skeleton", "creeper", "spider", "pigZombie"].contains(entity.kind) {
            entity.targetEntityID = sourceID
        }
        if entity.kind == "wolf" {
            let ownerHit =
                sourceID == 0 && entity.owner?.caseInsensitiveCompare(localPlayerName) == .orderedSame
            if !ownerHit { entity.targetEntityID = sourceID }
            if sourceID == 0 && entity.owner == nil {
                entity.metadata |= 2
                entity.angerTicks = 400
            }
            if entity.owner == nil {
                let area = AxisAlignedBox(
                    min: entity.position - SIMD3(16, 4, 16), max: entity.position + SIMD3(17, 5, 17))
                for ally in entities.indices
                where ally != index && entities[ally].kind == "wolf" && entities[ally].owner == nil
                    && entities[ally].targetEntityID == nil && entities[ally].bounds.intersects(area)
                {
                    entities[ally].targetEntityID = sourceID
                    if sourceID == 0 {
                        entities[ally].metadata |= 2
                        entities[ally].angerTicks = 400
                    }
                }
            }
        }
        if entity.kind == "pigZombie", sourceID == 0 {
            entity.angerTicks = 400 + random.nextInt(bound: 400)
            entity.specialTicks = random.nextInt(bound: 40)
            let area = entity.bounds.expanded(by: SIMD3(repeating: 32))
            for ally in entities.indices
            where ally != index && entities[ally].kind == "pigZombie"
                && entities[ally].bounds.intersects(area)
            {
                entities[ally].targetEntityID = sourceID
                entities[ally].angerTicks = 400 + random.nextInt(bound: 400)
                entities[ally].specialTicks = random.nextInt(bound: 40)
            }
        }
    }
}

extension EntityMotion {
    static func pounce(_ entity: inout GameEntity, toward point: SIMD3<Double>) {
        let delta = point - entity.position
        let length = Double(Float(sqrt(delta.x * delta.x + delta.z * delta.z)))
        guard length > 0 else { return }
        entity.velocity.x =
            delta.x / length * 0.5 * Double(Float(0.8)) + entity.velocity.x * Double(Float(0.2))
        entity.velocity.z =
            delta.z / length * 0.5 * Double(Float(0.8)) + entity.velocity.z * Double(Float(0.2))
        entity.velocity.y = Double(Float(0.4))
    }
}
