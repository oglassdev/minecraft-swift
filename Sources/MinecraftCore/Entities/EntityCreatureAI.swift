import Foundation

extension EntitySimulation {
    func pathHasPoint(_ entity: GameEntity) -> Bool { entity.pathIndex < entity.path.count }

    mutating func creatureMovement(
        _ entity: inout GameEntity, world: BlockWorld, player: Player, time: Int64,
        attacking: Bool, sitting: Bool, combatTarget: LivingTarget? = nil
    ) -> (forward: Float, strafe: Float, jump: Bool) {
        guard !sitting else {
            entity.path = []
            return (0, 0, false)
        }
        let target = entity.targetPosition
        if attacking || entity.targetEntityID == nil
            || (pathHasPoint(entity) && random.nextInt(bound: 20) != 0)
        {
            if !attacking
                && ((!pathHasPoint(entity) && random.nextInt(bound: 80) == 0)
                    || random.nextInt(bound: 80) == 0)
            {
                wander(&entity, world: world, time: time)
            }
        } else if let target {
            entity.path = BetaPathfinder.path(in: world, entity: entity, toward: target)
            entity.pathIndex = 0
        }
        let water = EntityMotion.isFluid(in: world, bounds: entity.bounds, water: true)
        let lava = EntityMotion.isFluid(in: world, bounds: entity.bounds, water: false)
        guard pathHasPoint(entity), random.nextInt(bound: 100) != 0 else {
            entity.path = []
            entity.pathIndex = 0
            return idleMovement(&entity, player: player, water: water || lava)
        }
        let feetY = floor(entity.bounds.min.y + 0.5)
        let threshold = Double(Float(entity.width) * 2)
        while pathHasPoint(entity) {
            let point = BetaPathfinder.waypoint(entity.path[entity.pathIndex], for: entity)
            let delta = point - entity.position
            if delta.x * delta.x + delta.z * delta.z >= threshold * threshold { break }
            entity.pathIndex += 1
        }
        var forward: Float = 0
        var strafe: Float = 0
        var jump = false
        if pathHasPoint(entity) {
            let point = BetaPathfinder.waypoint(entity.path[entity.pathIndex], for: entity)
            let delta = point - entity.position
            let yaw = Float(atan2(delta.z, delta.x) * 180 / Double(BetaMath.pi)) - 270
            entity.yaw = turn(entity.yaw, toward: yaw * BetaMath.pi / 180, maximum: BetaMath.pi / 6)
            forward = entity.kind == "zombie" ? 0.5 : (entity.kind == "spider" ? 0.8 : 0.7)
            if entity.kind == "wolf" { forward = 1.1 }
            if entity.kind == "pigZombie" { forward = entity.targetEntityID == nil ? 0.5 : 0.95 }
            if attacking, let combatTarget {
                let before = entity.yaw
                let delta = combatTarget.position - entity.position
                entity.yaw = Float(atan2(delta.x, -delta.z))
                let angle = before - entity.yaw + BetaMath.pi / 2
                strafe = sin(angle) * forward
                forward = cos(angle) * forward
            }
            jump = point.y - feetY > 0
        }
        if let combatTarget {
            look(
                &entity, at: combatTarget.eye,
                maximumYaw: BetaMath.pi / 6, maximumPitch: BetaMath.pi / 6)
        }
        if entity.isCollidingHorizontally && !pathHasPoint(entity) { jump = true }
        if random.nextFloat() < 0.8 && (water || lava) { jump = true }
        return (forward, strafe, jump)
    }

    private mutating func wander(_ entity: inout GameEntity, world: BlockWorld, time: Int64) {
        var best: BlockPosition?
        var weight: Float = -99999
        for _ in 0..<10 {
            let p = BlockPosition(
                Int(floor(entity.position.x + Double(random.nextInt(bound: 13)) - 6)),
                Int(floor(entity.position.y + Double(random.nextInt(bound: 7)) - 3)),
                Int(floor(entity.position.z + Double(random.nextInt(bound: 13)) - 6)))
            let brightness = EntityMotion.brightness(
                light: EntityMotion.light(
                    in: world, position: p, time: time, rain: rainStrength, thunder: thunderStrength),
                dimension: world.dimension)
            let passive = ["pig", "sheep", "cow", "chicken", "wolf"].contains(entity.kind)
            let value: Float =
                passive
                ? (world[BlockPosition(p.x, p.y - 1, p.z)] == .grass ? 10 : brightness - 0.5)
                : 0.5 - brightness
            if value > weight {
                weight = value
                best = p
            }
        }
        if let best {
            entity.path = BetaPathfinder.path(
                in: world, entity: entity,
                toward: SIMD3(Double(best.x) + 0.5, Double(best.y) + 0.5, Double(best.z) + 0.5), range: 10)
            entity.pathIndex = 0
        }
    }

    private mutating func idleMovement(_ entity: inout GameEntity, player: Player, water: Bool) -> (
        Float, Float, Bool
    ) {
        entity.idleTicks += 1
        let distance = EntityMotion.squaredLength(
            player.position + SIMD3(0, Double(Float(1.62)), 0) - entity.position)
        if entity.owner == nil {
            if distance > 16384 {
                entity.health = 0
                entity.lootDropped = true
                entity.deathTicks = 21
            }
            if entity.idleTicks > 600 && random.nextInt(bound: 800) == 0 {
                if distance < 1024 {
                    entity.idleTicks = 0
                } else {
                    entity.health = 0
                    entity.lootDropped = true
                    entity.deathTicks = 21
                }
            }
        }
        if random.nextFloat() < 0.02 {
            if distance < 64 {
                entity.lookTicks = 10 + random.nextInt(bound: 20)
            } else {
                entity.yawVelocity = (random.nextFloat() - 0.5) * 20 * BetaMath.pi / 180
            }
        }
        if entity.lookTicks > 0 {
            look(
                &entity, at: player.eyePositionDouble, maximumYaw: BetaMath.pi / 18,
                maximumPitch: BetaMath.pi * 2 / 9)
            entity.lookTicks -= 1
            if distance > 64 { entity.lookTicks = 0 }
        } else {
            if random.nextFloat() < 0.05 {
                entity.yawVelocity = (random.nextFloat() - 0.5) * 20 * BetaMath.pi / 180
            }
            entity.yaw += entity.yawVelocity
            entity.pitch = 0
        }
        return (0, 0, water && random.nextFloat() < 0.8)
    }

    private func turn(_ current: Float, toward target: Float, maximum: Float) -> Float {
        var delta = (target - current).truncatingRemainder(dividingBy: BetaMath.pi * 2)
        if delta < -BetaMath.pi { delta += BetaMath.pi * 2 }
        if delta >= BetaMath.pi { delta -= BetaMath.pi * 2 }
        return current + min(max(delta, -maximum), maximum)
    }

    private func look(
        _ entity: inout GameEntity, at point: SIMD3<Double>, maximumYaw: Float, maximumPitch: Float
    ) {
        let delta = point - (entity.position + SIMD3(0, entity.height * 0.85, 0))
        entity.yaw = turn(entity.yaw, toward: Float(atan2(delta.x, -delta.z)), maximum: maximumYaw)
        entity.pitch = turn(
            entity.pitch, toward: Float(atan2(delta.y, sqrt(delta.x * delta.x + delta.z * delta.z))),
            maximum: maximumPitch)
    }
}
