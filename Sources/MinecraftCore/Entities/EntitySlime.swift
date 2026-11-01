import Foundation

extension EntitySimulation {
    mutating func splitSlime(_ entity: GameEntity) {
        let size = Int(entity.metadata)
        for index in 0..<4 {
            let x = (Float(index % 2) - 0.5) * Float(size) / 4
            let z = (Float(index / 2) - 0.5) * Float(size) / 4
            let id = spawn(
                kind: "slime", position: entity.position + SIMD3(Double(x), 0.5, Double(z)),
                metadata: UInt8(size / 2))
            let yaw = random.nextFloat() * BetaMath.pi * 2
            update(id: id) { $0.yaw = yaw }
        }
    }

    mutating func tickSlime(
        _ entity: inout GameEntity, world: BlockWorld, player: inout Player, inventory: inout PlayerInventory,
        visible: Bool
    ) -> [BlockEvent] {
        var events: [BlockEvent] = []
        entity.previousSquishAmount = entity.squishAmount
        let delta = player.position + SIMD3(0, Double(Float(1.62)), 0) - entity.position
        let distance = sqrt(EntityMotion.squaredLength(delta))
        if distance > 128 {
            entity.health = 0
            entity.lootDropped = true
            entity.deathTicks = 21
            return []
        }
        if distance < 16 {
            EntityMotion.face(&entity, toward: player.eyePositionDouble, maximumTurn: BetaMath.pi / 18)
        }
        var jump = false
        if entity.onGround {
            let expired = entity.specialTicks <= 0
            entity.specialTicks -= 1
            if expired {
                entity.specialTicks = random.nextInt(bound: 20) + 10
                if distance < 16 { entity.specialTicks /= 3 }
                jump = true
                if entity.metadata > 1 {
                    events.append(
                        .sound(
                            name: "mob.slime", position: entity.position, volume: 0.6,
                            pitch: ((random.nextFloat() - random.nextFloat()) * 0.2 + 1) * 0.8))
                }
                entity.aiStrafe = 1 - random.nextFloat() * 2
                entity.aiForward = Float(entity.metadata)
                entity.squishAmount = 1
            } else {
                entity.aiForward = 0
                entity.aiStrafe = 0
            }
        }
        let grounded = entity.onGround
        _ = EntityMotion.living(
            &entity, world: world, forward: entity.aiForward, strafe: -entity.aiStrafe, jump: jump,
            collisions: collisionView())
        entity.aiForward *= 0.98
        entity.aiStrafe *= 0.98
        let size = Int(entity.metadata)
        if entity.onGround && !grounded {
            entity.squishAmount = -0.5
            for _ in 0..<(size * 8) {
                let angle = random.nextFloat() * BetaMath.pi * 2
                let scale = random.nextFloat() * 0.5 + 0.5
                let x = EntityMotion.sine(angle) * Float(size) * 0.5 * scale
                let z = EntityMotion.cosine(angle) * Float(size) * 0.5 * scale
                events.append(
                    .particle(name: "slime", position: entity.position + SIMD3(Double(x), 0, Double(z))))
            }
            if size > 2 {
                events.append(
                    .sound(
                        name: "mob.slime", position: entity.position, volume: 0.6,
                        pitch: ((random.nextFloat() - random.nextFloat()) * 0.2 + 1) / 0.8))
            }
        }
        if size > 1, visible, distance < 0.6 * Double(size),
            entity.bounds.intersects(player.bounds.expanded(by: SIMD3(1, 0, 1))),
            player.damage(size, inventory: &inventory)
        {
            events.append(
                .sound(
                    name: "mob.slimeattack", position: entity.position, volume: 1,
                    pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
        }
        entity.squishAmount *= 0.6
        return events
    }
}
