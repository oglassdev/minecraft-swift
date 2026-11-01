import Foundation

extension EntitySimulation {
    public func target(
        origin: SIMD3<Double>, direction: SIMD3<Double>, reach: Double = 4, world: BlockWorld? = nil
    ) -> GameEntity? {
        guard let hit = nearestEntity(origin: origin, direction: direction, reach: reach) else { return nil }
        if let world,
            let block = BlockRaycast.hit(in: world, origin: origin, direction: direction, reach: reach),
            block.distance < hit.distance
        {
            return nil
        }
        return entities[hit.index]
    }

    public mutating func upsert(_ entity: GameEntity) {
        if let index = entityArrayIndex(id: entity.id) {
            entities[index] = entity
            refreshSpatialBody(at: index)
        } else {
            entities.append(entity)
            spatialIndex?.append(EntityCollisionBody(entity))
        }
        reserveIDs(through: entity.id)
    }

    public mutating func remove(ids: [Int64]) {
        spatialIndex = nil
        let ids = Set(ids)
        entities.removeAll { ids.contains($0.id) }
        for id in ids { effectRandoms[id] = nil }
        for id in ids { entityRandoms[id] = nil }
    }

    public mutating func update(id: Int64, _ body: (inout GameEntity) -> Void) {
        guard let index = entityArrayIndex(id: id) else { return }
        body(&entities[index])
        refreshSpatialBody(at: index)
    }

    /// Advances client presentation; the server remains responsible for simulation and removal.
    public mutating func tickRemote() {
        for index in entities.indices {
            entities[index].previousPosition = entities[index].position
            entities[index].previousYaw = entities[index].yaw
            entities[index].previousPitch = entities[index].pitch
            entities[index].previousBodyYawDegrees = entities[index].bodyYawDegrees
            entities[index].ageTicks += 1
            if entities[index].kind == "lightningBolt" {
                var generator =
                    effectRandoms[entities[index].id] ?? JavaRandom(seed: entities[index].effectSeed)
                if entities[index].ageTicks == 1 {
                    entities[index].lightningFlashes = generator.nextInt(bound: 3) + 1
                }
                entities[index].lightningState -= 1
                if entities[index].lightningState < 0 {
                    if entities[index].lightningFlashes == 0 {
                        entities[index].health = 0
                    } else if entities[index].lightningState < -generator.nextInt(bound: 10) {
                        entities[index].lightningFlashes -= 1
                        entities[index].lightningState = 1
                        entities[index].effectSeed = generator.nextLong()
                    }
                }
                effectRandoms[entities[index].id] = generator
            }
            if entities[index].hurtTicks > 0 { entities[index].hurtTicks -= 1 }
            if entities[index].attackCooldown > 0 { entities[index].attackCooldown -= 1 }
            if entities[index].fireTicks > 0 { entities[index].fireTicks -= 1 }
            if entities[index].kind == "primedTnt", entities[index].fuseTicks > 0 {
                entities[index].fuseTicks -= 1
            }
            if entities[index].remoteTicks > 0 {
                let remaining = Float(entities[index].remoteTicks)
                if let position = entities[index].remotePosition {
                    entities[index].position += (position - entities[index].position) / Double(remaining)
                }
                if let yaw = entities[index].remoteYaw {
                    entities[index].yaw +=
                        (yaw - entities[index].yaw).remainder(dividingBy: BetaMath.pi * 2) / remaining
                }
                if let pitch = entities[index].remotePitch {
                    entities[index].pitch += (pitch - entities[index].pitch) / remaining
                }
                entities[index].remoteTicks -= 1
                if entities[index].remoteTicks == 0 {
                    entities[index].remotePosition = nil
                    entities[index].remoteYaw = nil
                    entities[index].remotePitch = nil
                }
            }
            if entities[index].isLiving {
                entities[index].updateLimbSwing()
                entities[index].updateBodyYaw()
                if entities[index].health <= 0 { entities[index].deathTicks += 1 }
                if entities[index].kind == "chicken" {
                    let velocity = entities[index].velocity
                    entities[index].updateChickenWings()
                    entities[index].velocity = velocity
                }
            }
        }
        let expired = entities.filter { $0.kind == "lightningBolt" && $0.health <= 0 }.map(\.id)
        remove(ids: expired)
    }
}
