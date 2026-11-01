import Foundation

enum EntityMotion {
    @discardableResult
    static func move(
        _ entity: inout GameEntity, world: BlockWorld, stepHeight: Double = 0, bodies: [GameEntity] = [],
        collisions: EntityCollisionView? = nil
    ) -> Bool {
        let collisions = collisions ?? EntityCollisionView(index: nil, fallback: bodies)
        let vehicle = entity.kind == "boat" || entity.kind == "minecart"
        let original = entity.bounds
        var requested = entity.velocity
        if entity.inWeb {
            entity.inWeb = false
            requested *= SIMD3(0.25, Double(Float(0.05)), 0.25)
            entity.velocity = .zero
        }
        var result = resolve(
            requested, bounds: original, world: world, moverID: entity.id, vehicle: vehicle,
            collisions: collisions)
        if stepHeight > 0, entity.onGround || (requested.y < 0 && requested.y != result.movement.y),
            requested.x != result.movement.x || requested.z != result.movement.z
        {
            let raised = resolve(
                SIMD3(requested.x, stepHeight, requested.z), bounds: original, world: world,
                moverID: entity.id,
                vehicle: vehicle, collisions: collisions)
            let obstacles =
                BlockCollision.boxes(
                    in: world, intersecting: original.swept(by: SIMD3(requested.x, stepHeight, requested.z)))
                + collisions.boxes(
                    movingID: entity.id, vehicle: vehicle,
                    intersecting: original.swept(by: SIMD3(requested.x, stepHeight, requested.z)))
            var down = -stepHeight
            for obstacle in obstacles { down = obstacle.clip(down, axis: 1, moving: raised.bounds) }
            let stepped = raised.movement + SIMD3(0, down, 0)
            if stepped.x * stepped.x + stepped.z * stepped.z > result.movement.x * result.movement.x + result
                .movement.z * result.movement.z
            {
                result = (stepped, raised.bounds.offset(by: SIMD3(0, down, 0)))
            }
        }
        entity.position = SIMD3(
            (result.bounds.min.x + result.bounds.max.x) / 2,
            result.bounds.min.y, (result.bounds.min.z + result.bounds.max.z) / 2)
        entity.onGround = requested.y < 0 && requested.y != result.movement.y
        if entity.isLiving {
            if entity.onGround {
                if entity.kind == "pig", entity.riderID == 0, entity.fallDistance > 5 {
                    entity.pendingPigFall = entity.fallDistance
                }
                if entity.fallDistance > 3 && !["chicken", "ghast"].contains(entity.kind) {
                    _ = entity.receiveDamage(Int(ceil(entity.fallDistance - 3)))
                }
                entity.fallDistance = 0
            } else if result.movement.y < 0 {
                entity.fallDistance = Float(Double(entity.fallDistance) - result.movement.y)
            }
        }
        for axis in 0..<3 where requested[axis] != result.movement[axis] { entity.velocity[axis] = 0 }
        entity.isCollidingHorizontally = requested.x != result.movement.x || requested.z != result.movement.z
        blockContacts(&entity, world: world)
        if !["item", "primedTnt", "fallingSand", "boat", "minecart", "spider", "wolf"].contains(entity.kind) {
            let x = entity.position.x - (original.min.x + original.max.x) / 2
            let z = entity.position.z - (original.min.z + original.max.z) / 2
            entity.walkedDistance = Float(
                Double(entity.walkedDistance) + Double(Float(sqrt(x * x + z * z))) * 0.6)
            let cell = BlockPosition(
                Int(floor(entity.position.x)), Int(floor(entity.position.y - Double(Float(0.2)))),
                Int(floor(entity.position.z)))
            if entity.walkedDistance > Float(entity.nextStepDistance), world[cell] != nil {
                entity.nextStepDistance += 1
                entity.stepEvents.append(cell)
            }
        }
        return entity.isCollidingHorizontally
    }

    static func living(
        _ entity: inout GameEntity, world: BlockWorld, forward: Float, strafe: Float = 0, jump: Bool,
        bodies: [GameEntity] = [], collisions: EntityCollisionView? = nil
    ) -> Bool {
        let collisions = collisions ?? EntityCollisionView(index: nil, fallback: bodies)
        let water = entity.isInWater
        let lava = isFluid(
            in: world,
            bounds: entity.bounds.expanded(
                by: SIMD3(-Double(Float(0.1)), -Double(Float(0.4)), -Double(Float(0.1)))),
            water: false)
        if jump {
            if water || lava {
                entity.velocity.y += Double(Float(0.04))
            } else if entity.onGround {
                entity.velocity.y = Double(Float(0.42))
            }
        }
        if water || lava {
            let previousY = entity.position.y
            if water { entity.fallDistance = 0 }
            accelerate(&entity, forward: forward * 0.98, strafe: strafe * 0.98, speed: 0.02)
            let blocked = move(&entity, world: world, stepHeight: 0.5, collisions: collisions)
            entity.velocity *= water ? Double(Float(0.8)) : 0.5
            entity.velocity.y -= 0.02
            let escape = entity.bounds.offset(
                by: SIMD3(
                    entity.velocity.x, entity.velocity.y + Double(Float(0.6)) - entity.position.y + previousY,
                    entity.velocity.z))
            if blocked && BlockCollision.boxes(in: world, intersecting: escape).isEmpty
                && collisions.boxes(movingID: entity.id, vehicle: false, intersecting: escape).isEmpty
                && !isFluid(in: world, bounds: escape, water: true)
                && !isFluid(in: world, bounds: escape, water: false)
            {
                entity.velocity.y = Double(Float(0.3))
            }
            entity.updateLimbSwing()
            return blocked
        }
        var friction: Float = 0.91
        if entity.onGround {
            let below = world[
                BlockPosition(
                    Int(floor(entity.position.x)), Int(floor(entity.position.y)) - 1,
                    Int(floor(entity.position.z)))]
            friction = (below == .ice ? Float(0.98) : Float(0.6)) * 0.91
        }
        let speed: Float = entity.onGround ? 0.1 * (0.16277136 / (friction * friction * friction)) : 0.02
        accelerate(&entity, forward: forward * 0.98, strafe: strafe * 0.98, speed: speed)
        let foot = BlockPosition(
            Int(floor(entity.position.x)), Int(floor(entity.position.y)), Int(floor(entity.position.z)))
        if world[foot] == .ladder || (entity.kind == "spider" && entity.isCollidingHorizontally) {
            entity.velocity.x = min(max(entity.velocity.x, -Double(Float(0.15))), Double(Float(0.15)))
            entity.velocity.z = min(max(entity.velocity.z, -Double(Float(0.15))), Double(Float(0.15)))
            entity.velocity.y = max(entity.velocity.y, -0.15)
            entity.fallDistance = 0
        }
        let blocked = move(&entity, world: world, stepHeight: 0.5, collisions: collisions)
        if blocked && (world[foot] == .ladder || entity.kind == "spider") { entity.velocity.y = 0.2 }
        entity.velocity.y = (entity.velocity.y - 0.08) * Double(Float(0.98))
        entity.velocity.x *= Double(friction)
        entity.velocity.z *= Double(friction)
        entity.updateLimbSwing()
        return blocked
    }

    static func accelerate(_ entity: inout GameEntity, forward: Float, strafe: Float, speed: Float) {
        let length = sqrt(forward * forward + strafe * strafe)
        guard length >= 0.01 else { return }
        let scale = speed / max(length, 1)
        let forward = forward * scale
        let strafe = -strafe * scale
        let radians = (entity.yaw * 180 / BetaMath.pi + 180) * BetaMath.pi / 180
        let sine = sines[Int(radians * 10430.378) & 65535]
        let cosine = sines[Int(radians * 10430.378 + 16384) & 65535]
        entity.velocity.x += Double(strafe * cosine - forward * sine)
        entity.velocity.z += Double(forward * cosine + strafe * sine)
    }

    static func isFluid(in world: BlockWorld, bounds: AxisAlignedBox, water: Bool) -> Bool {
        guard floor(bounds.min.x) <= floor(bounds.max.x), floor(bounds.min.y) <= floor(bounds.max.y),
            floor(bounds.min.z) <= floor(bounds.max.z)
        else { return false }
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in Int(floor(bounds.min.y))...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    guard let kind = world[BlockPosition(x, y, z)] else { continue }
                    if water ? (kind == .water || kind == .stillWater) : (kind == .lava || kind == .stillLava)
                    {
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func blockContacts(_ entity: inout GameEntity, world: BlockWorld) {
        let bounds = entity.bounds.expanded(by: SIMD3(repeating: -0.001))
        guard bounds.min.y <= bounds.max.y else { return }
        var burning = false
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in Int(floor(bounds.min.y))...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    switch world[BlockPosition(x, y, z)] {
                    case .cobweb:
                        entity.inWeb = true
                        entity.fallDistance = 0
                    case .soulSand:
                        entity.velocity.x *= 0.4
                        entity.velocity.z *= 0.4
                    case .cactus: _ = entity.receiveDamage(1)
                    case .fire, .lava, .stillLava: burning = true
                    default: break
                    }
                }
            }
        }
        if burning {
            if !entity.fireImmune { _ = entity.receiveDamage(1) }
            if !entity.isWet {
                entity.fireTicks += 1
                if entity.fireTicks == 0 { entity.fireTicks = 300 }
            }
        } else if entity.fireTicks <= 0 {
            entity.fireTicks = -1
        }
        if entity.isWet && entity.fireTicks > 0 {
            entity.pendingFizz = true
            entity.fireTicks = -1
        }
    }

    static func fluidSurfaceContact(in world: BlockWorld, bounds: AxisAlignedBox, water: Bool) -> Bool {
        guard floor(bounds.min.x) <= floor(bounds.max.x), floor(bounds.min.y) <= floor(bounds.max.y),
            floor(bounds.min.z) <= floor(bounds.max.z)
        else { return false }
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in Int(floor(bounds.min.y))...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    guard let state = world.state(at: BlockPosition(x, y, z)),
                        water
                            ? (state.kind == .water || state.kind == .stillWater)
                            : (state.kind == .lava || state.kind == .stillLava)
                    else { continue }
                    let surface = Double(y + 1) - (state.metadata < 8 ? Double(state.metadata) / 8 : 0)
                    if surface >= bounds.min.y { return true }
                }
            }
        }
        return false
    }

    static func normalized(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        let length = sqrt(squaredLength(vector))
        return length < 0.0001 ? .zero : vector / length
    }

    static func squaredLength(_ vector: SIMD3<Double>) -> Double {
        vector.x * vector.x + vector.y * vector.y + vector.z * vector.z
    }

    static func sine(_ angle: Float) -> Float { sines[Int(angle * 10430.378) & 65535] }
    static func cosine(_ angle: Float) -> Float { sines[Int(angle * 10430.378 + 16384) & 65535] }

    static func face(
        _ entity: inout GameEntity, toward point: SIMD3<Double>, maximumTurn: Float = BetaMath.pi / 6
    ) {
        let delta = point - entity.position
        let targetYaw = Float(atan2(delta.x, -delta.z))
        let difference = (targetYaw - entity.yaw).remainder(dividingBy: BetaMath.pi * 2)
        entity.yaw += min(max(difference, -maximumTurn), maximumTurn)
        entity.pitch = Float(atan2(delta.y, sqrt(delta.x * delta.x + delta.z * delta.z)))
    }

    static func skyVisible(in world: BlockWorld, position: SIMD3<Double>) -> Bool {
        let x = Int(floor(position.x))
        let z = Int(floor(position.z))
        let lower = max(0, Int(floor(position.y)))
        guard lower < 128 else { return true }
        for y in lower..<128 {
            if world[BlockPosition(x, y, z)]?.isOpaque == true { return false }
        }
        return true
    }

    static func light(
        in world: BlockWorld, position: BlockPosition, time: Int64, rain: Float = 0,
        thunder: Float = 0, darkeningOverride: Int? = nil
    ) -> Int {
        let darkening =
            darkeningOverride
            ?? skyDarkening(time: time, dimension: world.dimension, rain: rain, thunder: thunder)
        if let kind = world[position], [44, 53, 60, 67].contains(kind.rawValue) {
            return [
                BlockPosition(0, 1, 0), BlockPosition(1, 0, 0), BlockPosition(-1, 0, 0),
                BlockPosition(0, 0, 1), BlockPosition(0, 0, -1),
            ].map {
                let light = world.light(
                    at: BlockPosition(position.x + $0.x, position.y + $0.y, position.z + $0.z))
                return max(Int(light.block), max(0, Int(light.sky) - darkening))
            }.max() ?? 0
        }
        let light = world.light(at: BlockPosition(position.x, min(127, position.y), position.z))
        return max(Int(light.block), max(0, Int(light.sky) - darkening))
    }

    static func skyDarkening(time: Int64, dimension: Int8 = 0, rain: Float = 0, thunder: Float = 0) -> Int {
        var angle: Float = 0.5
        if dimension != -1 {
            angle = (Float(time % 24000) + 1) / 24000 - 0.25
            if angle < 0 { angle += 1 }
            if angle > 1 { angle -= 1 }
            let original = angle
            angle = 1 - Float((cos(Double(angle) * .pi) + 1) / 2)
            angle = original + (angle - original) / 3
        }
        let cosine = sines[Int(angle * BetaMath.pi * 2 * 10430.378 + 16384) & 65535]
        var darkness = min(max(1 - (cosine * 2 + 0.5), 0), 1)
        darkness = 1 - darkness
        darkness = Float(Double(darkness) * (1 - Double(rain * 5) / 16))
        darkness = Float(Double(darkness) * (1 - Double(thunder * rain * 5) / 16))
        return Int((1 - darkness) * 11)
    }

    static func brightness(light: Int, dimension: Int8 = 0) -> Float {
        let minimum: Float = dimension == -1 ? 0.1 : 0.05
        let inverse: Float = 1 - Float(light) / 15
        return (1 - inverse) / (inverse * 3 + 1) * (1 - minimum) + minimum
    }

    private static func resolve(
        _ movement: SIMD3<Double>, bounds: AxisAlignedBox, world: BlockWorld, moverID: Int64,
        vehicle: Bool, collisions: EntityCollisionView
    ) -> (
        movement: SIMD3<Double>, bounds: AxisAlignedBox
    ) {
        let obstacles =
            BlockCollision.boxes(in: world, intersecting: bounds.swept(by: movement))
            + collisions.boxes(movingID: moverID, vehicle: vehicle, intersecting: bounds.swept(by: movement))
        var bounds = bounds
        var movement = movement
        for axis in [1, 0, 2] {
            for obstacle in obstacles {
                movement[axis] = obstacle.clip(movement[axis], axis: axis, moving: bounds)
            }
            var offset = SIMD3<Double>.zero
            offset[axis] = movement[axis]
            bounds = bounds.offset(by: offset)
        }
        return (movement, bounds)
    }

    private static let sines: [Float] = (0..<65536).map { Float(sin(Double($0) * .pi * 2 / 65536)) }
}

extension EntitySimulation {
    public mutating func displaceEntities(
        in bounds: AxisAlignedBox, by movement: SIMD3<Double>, world: BlockWorld
    ) {
        for index in entities.indices where entities[index].bounds.intersects(bounds) {
            var entity = entities[index]
            if entity.kind == "painting", movement != .zero {
                entities[index].health = 0
                entities[index].lootDropped = true
                queuedEvents.append(
                    .dropItem(
                        position: entity.position + SIMD3(0, entity.height / 2, 0), stack: ItemStack(id: 321))
                )
                continue
            }
            var velocity = entity.velocity
            let before = entity.position
            entity.velocity = movement
            _ = EntityMotion.move(&entity, world: world, collisions: collisionView())
            let actual = entity.position - before
            for axis in 0..<3 where abs(actual[axis] - movement[axis]) > 0.0000001 { velocity[axis] = 0 }
            entity.velocity = velocity
            queuedEvents += entity.stepEvents.map { .stepped(at: $0, position: entity.position) }
            if let distance = entity.pendingPigFall {
                queuedEvents.append(.pigFall(distance: distance))
                entity.pendingPigFall = nil
            }
            entity.stepEvents.removeAll(keepingCapacity: true)
            entities[index] = entity
        }
    }

    mutating func tickItem(
        _ entity: inout GameEntity, world: BlockWorld, player: Player, inventory: inout PlayerInventory
    ) -> [BlockEvent] {
        var events: [BlockEvent] = []
        entity.velocity.y -= Double(Float(0.04))
        if EntityMotion.isFluid(in: world, bounds: entity.bounds, water: false) {
            entity.velocity = SIMD3(
                Double((random.nextFloat() - random.nextFloat()) * 0.2), Double(Float(0.2)),
                Double((random.nextFloat() - random.nextFloat()) * 0.2))
            events.append(
                .sound(
                    name: "random.fizz", position: entity.position, volume: 0.4,
                    pitch: 2 + random.nextFloat() * 0.4))
        }
        _ = EntityMotion.move(&entity, world: world, collisions: collisionView())
        var friction: Float = 0.98
        if entity.onGround {
            let below = world[
                BlockPosition(
                    Int(floor(entity.position.x)), Int(floor(entity.position.y)) - 1,
                    Int(floor(entity.position.z)))]
            friction = (below == .ice ? Float(0.98) : Float(0.6)) * 0.98
        }
        entity.velocity *= SIMD3(Double(friction), Double(Float(0.98)), Double(friction))
        if entity.onGround { entity.velocity.y *= -0.5 }
        if player.health > 0, entity.pickupDelay == 0,
            entity.bounds.intersects(player.bounds.expanded(by: SIMD3(1, 0, 1))),
            let stack = entity.itemStack
        {
            let leftover = inventory.insert(stack)
            if leftover?.count != stack.count {
                events.append(
                    .sound(
                        name: "random.pop", position: entity.position, volume: 0.2,
                        pitch: ((random.nextFloat() - random.nextFloat()) * 0.7 + 1) * 2))
            }
            entity.itemStack = leftover
            if leftover == nil { entity.health = 0 }
        }
        if entity.ageTicks >= 6000 { entity.health = 0 }
        return events
    }

    mutating func tickFallingBlock(_ entity: inout GameEntity, world: inout BlockWorld) -> [BlockEvent] {
        guard let state = entity.fallingBlock else {
            entity.health = 0
            return []
        }
        entity.velocity.y -= Double(Float(0.04))
        _ = EntityMotion.move(&entity, world: world, collisions: collisionView())
        entity.velocity *= Double(Float(0.98))
        let cell = BlockPosition(
            Int(floor(entity.position.x)), Int(floor(entity.position.y)), Int(floor(entity.position.z)))
        if entity.ageTicks == 1 && world[cell] == state.kind { world[cell] = nil }
        if entity.onGround {
            entity.health = 0
            if world[cell] == nil && (world[BlockPosition(cell.x, cell.y - 1, cell.z)]?.isSolid == true) {
                world.setBlock(state, at: cell)
                return []
            }
            return [
                .dropItem(
                    position: entity.position,
                    stack: ItemStack(id: UInt16(state.kind.rawValue), damage: UInt16(state.metadata)))
            ]
        }
        if entity.ageTicks > 100 {
            entity.health = 0
            return [
                .dropItem(
                    position: entity.position,
                    stack: ItemStack(id: UInt16(state.kind.rawValue), damage: UInt16(state.metadata)))
            ]
        }
        return []
    }

}
