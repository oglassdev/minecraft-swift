import Foundation

extension EntitySimulation {
    mutating func wolfBehavior(
        _ wolf: inout GameEntity, world: BlockWorld, player: Player, attacking: Bool, water: Bool,
        inventory: PlayerInventory
    ) -> [BlockEvent] {
        let riding = ridingEntityID(for: wolf.id) != nil
        if !attacking && !pathHasPoint(wolf) && wolf.owner != nil && !riding {
            let owner: LivingTarget?
            if wolf.owner?.caseInsensitiveCompare(localPlayerName) == .orderedSame && player.health > 0 {
                owner = livingTarget(id: 0, player: player)
            } else {
                owner = entities.first {
                    $0.kind == "player" && $0.owner?.caseInsensitiveCompare(wolf.owner ?? "") == .orderedSame
                        && $0.health > 0
                }.flatMap { livingTarget(id: $0.id, player: player) }
            }
            if let owner {
                let distance = Float(sqrt(EntityMotion.squaredLength(owner.position - wolf.position)))
                if distance > 5 {
                    let path = BetaPathfinder.path(in: world, entity: wolf, toward: owner.feet)
                    if path.isEmpty && distance > 12 {
                        let x = Int(floor(owner.position.x)) - 2
                        let z = Int(floor(owner.position.z)) - 2
                        let y = Int(floor(owner.bounds.min.y))
                        outer: for dx in 0...4 {
                            for dz in 0...4 where dx < 1 || dz < 1 || dx > 3 || dz > 3 {
                                if world[BlockPosition(x + dx, y - 1, z + dz)]?.isOpaque == true
                                    && world[BlockPosition(x + dx, y, z + dz)]?.isOpaque != true
                                    && world[BlockPosition(x + dx, y + 1, z + dz)]?.isOpaque != true
                                {
                                    wolf.position = SIMD3(
                                        Double(Float(x + dx) + 0.5), Double(y), Double(Float(z + dz) + 0.5))
                                    break outer
                                }
                            }
                        }
                    } else {
                        wolf.path = path
                        wolf.pathIndex = 0
                    }
                }
            } else if !water {
                wolf.metadata |= 1
            }
        } else if wolf.targetEntityID == nil && !pathHasPoint(wolf) && wolf.owner == nil
            && random.nextInt(bound: 100) == 0
        {
            let area = AxisAlignedBox(
                min: wolf.position - SIMD3(16, 4, 16), max: wolf.position + SIMD3(17, 5, 17))
            let sheep = contactCandidates(in: area).filter {
                entities[$0].kind == "sheep" && entities[$0].health > 0
                    && entities[$0].bounds.intersects(area)
            }
            if !sheep.isEmpty { wolf.targetEntityID = entities[sheep[random.nextInt(bound: sheep.count)]].id }
        }
        if water { wolf.metadata &= ~1 }
        let interesting =
            wolf.lookTicks > 0 && !pathHasPoint(wolf) && wolf.metadata & 2 == 0
            && ((wolf.owner == nil && inventory.selectedStack?.id == 352)
                || (wolf.owner != nil && [319, 320].contains(inventory.selectedStack?.id ?? 0)))
        wolf.wolfInterest += ((interesting ? Float(1) : Float(0)) - wolf.wolfInterest) * 0.4
        return []
    }

    mutating func wolfEffects(_ wolf: inout GameEntity, world: BlockWorld, water: Bool) -> [BlockEvent] {
        var events: [BlockEvent] = []
        if wolf.wolfWet && !wolf.wolfShaking && !pathHasPoint(wolf) && wolf.onGround {
            wolf.wolfShaking = true
            wolf.wolfShakeProgress = 0
            wolf.previousWolfShake = 0
        }
        let rainy = rainStrength > 0.2 && EntityMotion.skyVisible(in: world, position: wolf.position)
        if water || rainy {
            wolf.wolfWet = true
            wolf.wolfShaking = false
            wolf.wolfShakeProgress = 0
            wolf.previousWolfShake = 0
        } else if wolf.wolfShaking {
            if wolf.wolfShakeProgress == 0 {
                events.append(
                    .sound(
                        name: "mob.wolf.shake", position: wolf.position, volume: 0.4,
                        pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
            }
            wolf.previousWolfShake = wolf.wolfShakeProgress
            wolf.wolfShakeProgress += 0.05
            if wolf.previousWolfShake >= 2 {
                wolf.wolfWet = false
                wolf.wolfShaking = false
                wolf.previousWolfShake = 0
                wolf.wolfShakeProgress = 0
            }
            if wolf.wolfShakeProgress > 0.4 {
                let count = max(0, Int(EntityMotion.sine((wolf.wolfShakeProgress - 0.4) * BetaMath.pi) * 7))
                for _ in 0..<count {
                    let x = (random.nextFloat() * 2 - 1) * Float(wolf.width) * 0.5
                    let z = (random.nextFloat() * 2 - 1) * Float(wolf.width) * 0.5
                    events.append(
                        .particle(
                            name: "splash",
                            position: wolf.position
                                + SIMD3(
                                    Double(x), Double(Float(wolf.position.y) + 0.8) - wolf.position.y,
                                    Double(z))))
                }
            }
        }
        return events
    }

    mutating func wolfTamingParticles(
        at position: SIMD3<Double>, width: Double, height: Double, success: Bool
    ) {
        for _ in 0..<7 {
            _ = random.nextGaussian()
            _ = random.nextGaussian()
            _ = random.nextGaussian()
            let point =
                position
                + SIMD3(
                    Double(random.nextFloat() * Float(width) * 2 - Float(width)),
                    0.5 + Double(random.nextFloat() * Float(height)),
                    Double(random.nextFloat() * Float(width) * 2 - Float(width)))
            queuedEvents.append(.particle(name: success ? "heart" : "smoke", position: point))
        }
    }
}
