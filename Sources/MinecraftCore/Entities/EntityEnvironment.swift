import Foundation

enum EntityDamageResult { case ignored, additional, full }

extension GameEntity {
    var sourcePosition: SIMD3<Double> {
        position
            + SIMD3(
                0, ["item", "primedTnt", "fallingSand", "boat", "minecart"].contains(kind) ? height / 2 : 0, 0
            )
    }
    var fireImmune: Bool { kind == "pigZombie" || kind == "ghast" }

    mutating func receiveDamage(_ amount: Int) -> EntityDamageResult {
        guard health > 0 else { return .ignored }
        if isLiving {
            if hurtResistance > 10 {
                guard amount > lastDamage else { return .ignored }
                health -= amount - lastDamage
                lastDamage = amount
                return .additional
            }
            previousHealth = health
            health -= amount
            lastDamage = amount
            hurtResistance = 20
            hurtTicks = 10
            maxHurtTicks = 10
            pendingHurtSound = true
            return .full
        }
        if kind == "item" {
            health -= amount
            return .full
        }
        if kind == "painting" {
            health = 0
            return .full
        }
        if kind == "boat" || kind == "minecart" {
            vehicleDamage += amount * 10
            vehicleHitTicks = 10
            vehicleForwardDirection = -vehicleForwardDirection
            if vehicleDamage > 40 { health = 0 }
            return .full
        }
        return .ignored
    }
}

extension EntitySimulation {
    func raining(on entity: GameEntity, world: BlockWorld) -> Bool {
        guard rainStrength > 0.2, world.dimension != -1 else { return false }
        let p = BlockPosition(
            Int(floor(entity.sourcePosition.x)), Int(floor(entity.sourcePosition.y)),
            Int(floor(entity.sourcePosition.z)))
        let climate = world.climate(atX: p.x, z: p.z)
        guard
            WorldWeather.precipitation(
                temperature: climate.temperature, humidity: climate.humidity, dimension: world.dimension)
                == .rain, p.y >= 0, let chunk = world.chunks[p.chunk]
        else { return false }
        if p.y < 128 {
            for y in p.y..<128 where (chunk[p.x & 15, y, p.z & 15]?.kind.lightOpacity ?? 0) > 0 {
                return false
            }
        }
        return true
    }

    mutating func tickEnvironment(_ entity: inout GameEntity, world: BlockWorld) -> [BlockEvent] {
        let rained = raining(on: entity, world: world)
        entity.isWet = rained
        guard !["primedTnt", "fallingSand", "minecart", "painting"].contains(entity.kind) else { return [] }
        var events: [BlockEvent] = []
        let bounds =
            entity.kind == "item"
            ? entity.bounds : entity.bounds.expanded(by: SIMD3(-0.001, -Double(Float(0.4)) - 0.001, -0.001))
        let water = FluidPhysics.waterContact(in: world, bounds: bounds)
        entity.isInWater = water.touching
        if entity.kind != "squid" { entity.velocity += water.acceleration }
        entity.isWet = water.touching || rained
        if water.touching {
            entity.fireTicks = 0
            entity.fallDistance = 0
        }
        if entity.fireTicks > 0 {
            if entity.fireImmune {
                entity.fireTicks = max(0, entity.fireTicks - 4)
            } else {
                if entity.fireTicks % 20 == 0 {
                    _ = entity.receiveDamage(1)
                    events += damageEffects(&entity)
                }
                entity.fireTicks -= 1
            }
        }
        entity.isInLava = EntityMotion.isFluid(
            in: world,
            bounds: entity.bounds.expanded(
                by: SIMD3(-Double(Float(0.1)), -Double(Float(0.4)), -Double(Float(0.1)))), water: false)
        if entity.isInLava && !entity.fireImmune {
            _ = entity.receiveDamage(4)
            events += damageEffects(&entity)
            entity.fireTicks = 600
            entity.fallDistance *= 0.5
        }
        if entity.isLiving {
            let ambient = random.nextInt(bound: 1000) < entity.ambientTicks
            entity.ambientTicks += 1
            if ambient {
                entity.ambientTicks =
                    -(["pig", "sheep", "cow", "chicken", "squid", "wolf"].contains(entity.kind) ? 120 : 80)
                if let name = ambientSound(for: entity) {
                    events.append(
                        .sound(
                            name: name, position: entity.sourcePosition, volume: volume(for: entity),
                            pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
                }
            }
            if entity.health > 0 && suffocating(entity, world: world) {
                _ = entity.receiveDamage(1)
                events += damageEffects(&entity)
            }
            if entity.fireImmune { entity.fireTicks = 0 }
            if entity.health > 0 && entity.kind != "squid" && underwater(entity, world: world) {
                entity.air -= 1
                if entity.air == -20 {
                    entity.air = 0
                    for _ in 0..<8 {
                        let offset = SIMD3(
                            Double(random.nextFloat() - random.nextFloat()),
                            Double(random.nextFloat() - random.nextFloat()),
                            Double(random.nextFloat() - random.nextFloat()))
                        events.append(.particle(name: "bubble", position: entity.sourcePosition + offset))
                    }
                    _ = entity.receiveDamage(2)
                    events += damageEffects(&entity)
                }
                entity.fireTicks = 0
            } else {
                entity.air = 300
            }
            if entity.attackCooldown > 0 { entity.attackCooldown -= 1 }
            if entity.hurtTicks > 0 { entity.hurtTicks -= 1 }
            if entity.hurtResistance > 0 { entity.hurtResistance -= 1 }
        }
        events += damageEffects(&entity)
        return events
    }

    mutating func damageEffects(_ entity: inout GameEntity) -> [BlockEvent] {
        var events: [BlockEvent] = []
        if entity.pendingHurtSound {
            if entity.kind != "squid" {
                events.append(
                    .sound(
                        name: sound(for: entity.kind, dead: entity.health <= 0),
                        position: entity.sourcePosition, volume: volume(for: entity),
                        pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
            }
            entity.pendingHurtSound = false
        }
        if entity.pendingFizz {
            events.append(
                .sound(
                    name: "random.fizz", position: entity.sourcePosition, volume: 0.7,
                    pitch: 1.6 + (random.nextFloat() - random.nextFloat()) * 0.4))
            entity.pendingFizz = false
        }
        if entity.health <= 0 && !entity.lootDropped {
            events += loot(for: entity)
            entity.lootDropped = true
        }
        return events
    }

    func volume(for entity: GameEntity) -> Float {
        entity.kind == "ghast"
            ? 10 : (["wolf", "squid"].contains(entity.kind) ? 0.4 : (entity.kind == "slime" ? 0.6 : 1))
    }

    mutating func ambientSound(for entity: GameEntity) -> String? {
        switch entity.kind {
        case "pig": return "mob.pig"
        case "cow": return "mob.cow"
        case "sheep": return "mob.sheep"
        case "chicken": return "mob.chicken"
        case "zombie": return "mob.zombie"
        case "skeleton": return "mob.skeleton"
        case "spider": return "mob.spider"
        case "pigZombie": return "mob.zombiepig.zpig"
        case "ghast": return "mob.ghast.moan"
        case "wolf":
            if entity.metadata & 2 != 0 { return "mob.wolf.growl" }
            if random.nextInt(bound: 3) == 0 {
                return entity.owner != nil && entity.health < 10 ? "mob.wolf.whine" : "mob.wolf.panting"
            }
            return "mob.wolf.bark"
        default: return nil
        }
    }

    private func underwater(_ entity: GameEntity, world: BlockWorld) -> Bool {
        let eye = entity.eyePosition
        let p = BlockPosition(Int(floor(eye.x)), Int(floor(eye.y)), Int(floor(eye.z)))
        guard let state = world.state(at: p), state.kind == .water || state.kind == .stillWater else {
            return false
        }
        let level = state.metadata >= 8 ? 0 : Int(state.metadata)
        let offset = Float(level + 1) / 9 - 0.11111111
        return eye.y < Double(Float(p.y + 1) - offset)
    }

    private func suffocating(_ entity: GameEntity, world: BlockWorld) -> Bool {
        for corner in 0..<8 {
            let offset = SIMD3(
                Double((Float(corner & 1) - 0.5) * Float(entity.width) * 0.9),
                Double((Float((corner >> 1) & 1) - 0.5) * 0.1),
                Double((Float((corner >> 2) & 1) - 0.5) * Float(entity.width) * 0.9))
            let point = entity.eyePosition + offset
            if world[BlockPosition(Int(floor(point.x)), Int(floor(point.y)), Int(floor(point.z)))]?.isOpaque
                == true
            {
                return true
            }
        }
        return false
    }
}
