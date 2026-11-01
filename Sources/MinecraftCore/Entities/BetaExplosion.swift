import Foundation

public enum BetaExplosion {
    public static func resistance(of block: BlockKind) -> Float { resistances[Int(block.rawValue)] }

    public static func affectedBlocks(
        in world: BlockWorld, at center: SIMD3<Double>, power: Float, random: inout JavaRandom
    ) -> Set<BlockPosition> {
        guard power > 0, power.isFinite else { return [] }
        var affected: Set<BlockPosition> = []
        let step = Float(0.3)
        for x in 0..<16 {
            for y in 0..<16 {
                for z in 0..<16 where x == 0 || x == 15 || y == 0 || y == 15 || z == 0 || z == 15 {
                    var direction = SIMD3(
                        Double(Float(x) / 15 * 2 - 1), Double(Float(y) / 15 * 2 - 1),
                        Double(Float(z) / 15 * 2 - 1))
                    direction = EntityMotion.normalized(direction)
                    var strength = power * (0.7 + random.nextFloat() * 0.6)
                    var point = center
                    while strength > 0 {
                        let position = BlockPosition(
                            Int(floor(point.x)), Int(floor(point.y)), Int(floor(point.z)))
                        if let block = world[position] { strength -= (resistance(of: block) + 0.3) * step }
                        if strength > 0 { affected.insert(position) }
                        point += direction * Double(step)
                        strength -= step * 0.75
                    }
                }
            }
        }
        return affected
    }

    static func exposure(in world: BlockWorld, center: SIMD3<Double>, bounds: AxisAlignedBox) -> Float {
        let size = bounds.max - bounds.min
        let increment = SIMD3(1 / (size.x * 2 + 1), 1 / (size.y * 2 + 1), 1 / (size.z * 2 + 1))
        var visible = 0
        var total = 0
        var x: Float = 0
        while x <= 1 {
            var y: Float = 0
            while y <= 1 {
                var z: Float = 0
                while z <= 1 {
                    let point = bounds.min + size * SIMD3(Double(x), Double(y), Double(z))
                    let delta = center - point
                    let distance = sqrt(EntityMotion.squaredLength(delta))
                    if BlockRaycast.hit(in: world, origin: point, direction: delta, reach: distance) == nil {
                        visible += 1
                    }
                    total += 1
                    z = Float(Double(z) + increment.z)
                }
                y = Float(Double(y) + increment.y)
            }
            x = Float(Double(x) + increment.x)
        }
        return total == 0 ? 0 : Float(visible) / Float(total)
    }

    private static let resistances: [Float] = [
        0, 6, 0.6, 0.5, 6, 3, 0, 3_600_000, 100, 100, 0, 100, 0.5, 0.6, 3, 3, 3, 2, 0.2, 0.6,
        0.3, 3, 3, 3.5, 0.8, 0.8, 0.2, 0.7, 0.7, 0.5, 4, 0, 0, 0.5, 0.5, 0.8, 0, 0, 0, 0, 0,
        6, 6, 6, 6, 6, 0, 1.5, 6, 1200, 0, 0, 5, 3, 2.5, 0, 3, 6, 2.5, 0, 0.6, 3.5, 3.5, 1,
        3, 0.4, 0.7, 6, 1, 0.5, 0.5, 5, 0.5, 3, 3, 0, 0, 0.5, 0.1, 0.5, 0.2, 0.4, 0.6, 0,
        6, 3, 1, 0.4, 0.5, 0.3, 0, 1, 0.5, 0, 0, 0, 3,
    ]
}

extension EntitySimulation {
    public mutating func explode(
        at center: SIMD3<Double>, power: Float, world: inout BlockWorld, player: inout Player,
        inventory: inout PlayerInventory, worldRandom: inout JavaRandom
    ) -> [BlockEvent] {
        let saved = random
        random = worldRandom
        let events = explode(at: center, power: power, world: &world, player: &player, inventory: &inventory)
        worldRandom = random
        random = saved
        return events
    }

    struct ExplosionContext: Sendable {
        var position: SIMD3<Double>
        var power: Float
        var source: PlayerDamageSource
        var ignitesFire: Bool
    }

    mutating func explosionEvent(
        at position: SIMD3<Double>, power: Float, source: PlayerDamageSource = .environment,
        ignitesFire: Bool = false
    ) -> BlockEvent {
        explosionContexts.append(
            ExplosionContext(position: position, power: power, source: source, ignitesFire: ignitesFire))
        return .explosion(position: position, power: power)
    }

    public mutating func explode(
        at center: SIMD3<Double>, power: Float, world: inout BlockWorld, player: inout Player,
        inventory: inout PlayerInventory, source: PlayerDamageSource = .environment, ignitesFire: Bool = false
    ) -> [BlockEvent] {
        player.beginArmorUpdate(from: inventory)
        let events = explode(
            at: center, power: power, world: &world, player: &player, source: source, ignitesFire: ignitesFire
        )
        player.endArmorUpdate(in: &inventory)
        return events
    }

    public mutating func explode(
        at center: SIMD3<Double>, power: Float, world: inout BlockWorld, player: inout Player,
        source: PlayerDamageSource = .environment, ignitesFire: Bool = false
    ) -> [BlockEvent] {
        guard power > 0, power.isFinite else { return [] }
        var source = source
        var ignitesFire = ignitesFire
        if let index = explosionContexts.firstIndex(where: { $0.position == center && $0.power == power }) {
            let context = explosionContexts.remove(at: index)
            source = context.source
            ignitesFire = context.ignitesFire
        }
        let affected = BetaExplosion.affectedBlocks(in: world, at: center, power: power, random: &random)
        let radius = Double(power * 2)
        for index in entities.indices where entities[index].health > 0 {
            let delta = entities[index].position - center
            let distance = sqrt(EntityMotion.squaredLength(delta))
            guard distance <= radius else { continue }
            let exposure = Double(
                BetaExplosion.exposure(in: world, center: center, bounds: entities[index].bounds))
            let impact = (1 - distance / radius) * exposure
            let damage = Int((impact * impact + impact) / 2 * 8 * radius + 1)
            _ = hurtEntity(at: index, amount: damage, sourcePosition: center)
            entities[index].velocity += EntityMotion.normalized(delta) * impact
        }
        let playerDelta = player.position - center
        let playerDistance = sqrt(EntityMotion.squaredLength(playerDelta))
        if playerDistance <= radius {
            let exposure = Double(BetaExplosion.exposure(in: world, center: center, bounds: player.bounds))
            let impact = (1 - playerDistance / radius) * exposure
            player.damage(Int((impact * impact + impact) / 2 * 8 * radius + 1), source: source)
            player.addVelocity(EntityMotion.normalized(playerDelta) * impact)
        }
        var events: [BlockEvent] = [
            .sound(
                name: "random.explode", position: center, volume: 4,
                pitch: (1 + (random.nextFloat() - random.nextFloat()) * 0.2) * 0.7)
        ]
        if ignitesFire {
            // Beta prepares flame before block destruction, which also removes affected fire.
            for position in affected.sorted(by: {
                $0.x == $1.x ? ($0.y == $1.y ? $0.z < $1.z : $0.y < $1.y) : $0.x < $1.x
            }) {
                if world[position] == nil,
                    world[BlockPosition(position.x, position.y - 1, position.z)]?.isOpaque == true,
                    flameRandom.nextInt(bound: 3) == 0
                {
                    world[position] = .fire
                    if world[BlockPosition(position.x, position.y - 1, position.z)] == .obsidian {
                        _ = PortalFormation.form(at: position, world: &world)
                    }
                }
            }
        }
        for position in affected.sorted(by: {
            $0.x == $1.x ? ($0.y == $1.y ? $0.z < $1.z : $0.y < $1.y) : $0.x < $1.x
        }) {
            guard let state = world.state(at: position) else { continue }
            if state.kind == .tnt {
                spawn(
                    kind: "primedTnt", position: position.center - SIMD3(0, Double(Float(0.98)) / 2, 0),
                    fuseTicks: 10 + random.nextInt(bound: 20))
            } else {
                let drops = BlockMining.explosionDrops(
                    for: state, roll: { limit in random.nextInt(bound: limit) })
                for stack in drops {
                    for _ in 0..<stack.count where random.nextFloat() <= 0.3 {
                        events.append(
                            .dropItem(
                                position: position.center,
                                stack: ItemStack(id: stack.id, damage: stack.damage)))
                    }
                }
            }
            if let container = world.blockEntity(at: position) {
                events += container.contents.compactMap { stack in
                    stack.map { .dropItem(position: position.center, stack: $0) }
                }
            }
            world[position] = nil
            events.append(.particle(name: "explode", position: position.center))
        }
        return events
    }
}
