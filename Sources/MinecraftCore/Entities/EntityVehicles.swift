import Foundation

public enum EntityInteractionResult: Equatable, Sendable {
    case unhandled
    case used
    case container(entityID: Int64)
}

extension EntitySimulation {
    public mutating func interactResult(
        origin: SIMD3<Double>, direction: SIMD3<Double>, reach: Double = 4,
        player: inout Player, inventory: inout PlayerInventory, world: BlockWorld? = nil
    ) -> EntityInteractionResult {
        if let target = target(origin: origin, direction: direction, reach: reach, world: world),
            target.kind == "minecart", target.metadata == 1
        {
            update(id: target.id) { entity in
                if entity.contents.count < 27 {
                    entity.contents += Array(repeating: nil, count: 27 - entity.contents.count)
                }
            }
            return .container(entityID: target.id)
        }
        return interact(
            origin: origin, direction: direction, reach: reach, player: &player, inventory: &inventory,
            world: world) ? .used : .unhandled
    }

    public mutating func interact(
        origin: SIMD3<Double>, direction: SIMD3<Double>, reach: Double = 4,
        player: inout Player, inventory: inout PlayerInventory, world: BlockWorld? = nil
    ) -> Bool {
        guard let hit = nearestEntity(origin: origin, direction: direction, reach: reach) else {
            return false
        }
        if let world,
            let block = BlockRaycast.hit(in: world, origin: origin, direction: direction, reach: reach),
            block.distance < hit.distance
        {
            return false
        }
        var entity = entities[hit.index]
        switch entity.kind {
        case "boat", "minecart":
            if let rider = entity.riderID, rider != 0,
                entities.first(where: { $0.id == rider })?.kind == "player"
            {
                return true
            }
            if entity.kind == "minecart" && entity.metadata == 2 {
                if inventory.selectedStack?.id == 263 {
                    _ = inventory.removeSelected()
                    entity.fuelTicks += 1200
                }
                entity.pushDirection = SIMD2(
                    entity.position.x - player.position.x, entity.position.z - player.position.z)
            } else if entity.metadata == 0 {
                let dismount = entity.riderID == 0
                if dismount { dismountPlayer(player: &player) } else { dismountPlayer() }
                entity.riderID = dismount ? nil : 0
            } else {
                return false
            }
        case "cow":
            guard inventory.selectedStack?.id == 325 else { return false }
            _ = inventory.removeSelected()
            if let leftover = inventory.insert(ItemStack(id: 335)) { drop(leftover, at: entity.position) }
        case "pig":
            if inventory.selectedStack?.id == 329, entity.metadata & 1 == 0 {
                _ = inventory.removeSelected()
                entity.metadata |= 1
            } else if entity.metadata & 1 != 0, entity.riderID == nil || entity.riderID == 0 {
                let dismount = entity.riderID == 0
                if dismount { dismountPlayer(player: &player) } else { dismountPlayer() }
                entity.riderID = dismount ? nil : 0
            } else {
                return false
            }
        case "sheep":
            if let held = inventory.selectedStack, held.id == 351, held.damage < 16, entity.metadata & 16 == 0
            {
                let color = UInt8(15 - held.damage)
                if entity.metadata & 15 != color {
                    entity.metadata = (entity.metadata & 0xf0) | color
                    _ = inventory.removeSelected()
                }
                break
            }
            guard inventory.selectedStack?.id == 359, entity.metadata & 16 == 0 else { return false }
            entity.metadata |= 16
            inventory.damageSelected(by: 1)
            queuedEvents.append(
                .dropItem(
                    position: entity.position,
                    stack: ItemStack(
                        id: 35, count: 1 + random.nextInt(bound: 3), damage: UInt16(entity.metadata & 15))))
        case "wolf":
            if entity.owner == nil, inventory.selectedStack?.id == 352, entity.metadata & 2 == 0 {
                _ = inventory.removeSelected()
                if random.nextInt(bound: 3) == 0 {
                    entity.owner = localPlayerName
                    entity.metadata = 5
                    entity.health = 20
                    entity.path = []
                    entity.pathIndex = 0
                    entity.targetEntityID = nil
                }
                wolfTamingParticles(
                    at: entity.position, width: entity.width, height: entity.height,
                    success: entity.owner != nil)
            } else if entity.owner != nil, let held = inventory.selectedStack, [319, 320].contains(held.id),
                entity.health < 20
            {
                _ = inventory.removeSelected()
                entity.health = min(20, entity.health + 3)
                entity.hurtResistance = 10
            } else if entity.owner?.caseInsensitiveCompare(localPlayerName) == .orderedSame {
                entity.metadata ^= 1
                entity.path = []
                entity.pathIndex = 0
                entity.aiForward = 0
                entity.aiStrafe = 0
            } else {
                return false
            }
        default: return false
        }
        entities[hit.index] = entity
        player.isMounted = playerRidingEntityID != nil
        return true
    }

    public mutating func dismountPlayer() {
        for index in entities.indices where entities[index].riderID == 0 { entities[index].riderID = nil }
    }

    private mutating func boatSplashes(_ entity: GameEntity, speed: Double) -> [BlockEvent] {
        let angle = Double(entity.vehicleYaw ?? 0) * .pi / 180
        let cosine = cos(angle)
        let sine = sin(angle)
        var events: [BlockEvent] = []
        var index = 0
        while Double(index) < 1 + speed * 60 {
            let offset = Double(random.nextFloat() * 2 - 1)
            let side = Double(random.nextInt(bound: 2) * 2 - 1) * 0.7
            let x: Double
            let z: Double
            if random.nextBoolean() {
                x = entity.position.x - cosine * offset * 0.8 + sine * side
                z = entity.position.z - sine * offset * 0.8 - cosine * side
            } else {
                x = entity.position.x + cosine + sine * offset * 0.7
                z = entity.position.z + sine - cosine * offset * 0.7
            }
            events.append(
                .particle(
                    name: "splash", position: SIMD3(x, entity.position.y + entity.height / 2 - 0.125, z)))
            index += 1
        }
        return events
    }

    mutating func tickVehicle(_ entity: inout GameEntity, world: inout BlockWorld, player: inout Player)
        -> [BlockEvent]
    {
        var events: [BlockEvent] = []
        if entity.kind == "boat" {
            var submerged = 0.0
            for layer in 0..<5 {
                let lower = entity.position.y + entity.height * Double(layer) / 5 - 0.125
                let upper = entity.position.y + entity.height * Double(layer + 1) / 5 - 0.125
                let slice = AxisAlignedBox(
                    min: SIMD3(entity.bounds.min.x, lower, entity.bounds.min.z),
                    max: SIMD3(entity.bounds.max.x, upper, entity.bounds.max.z))
                if EntityMotion.fluidSurfaceContact(in: world, bounds: slice, water: true) {
                    submerged += 0.2
                }
            }
            if submerged < 1 {
                entity.velocity.y += Double(Float(0.04)) * (submerged * 2 - 1)
            } else {
                if entity.velocity.y < 0 { entity.velocity.y /= 2 }
                entity.velocity.y += Double(Float(0.007))
            }
            if entity.riderID == 0 {
                entity.velocity.x += player.velocity.x * 0.2
                entity.velocity.z += player.velocity.z * 0.2
            }
            entity.velocity.x = min(max(entity.velocity.x, -0.4), 0.4)
            entity.velocity.z = min(max(entity.velocity.z, -0.4), 0.4)
            if entity.onGround { entity.velocity *= 0.5 }
            let collision = EntityMotion.move(
                &entity, world: world, collisions: collisionView(player: player))
            let speed = sqrt(entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z)
            if speed > 0.15 { events += boatSplashes(entity, speed: speed) }
            if collision && speed > 0.15 {
                entity.health = 0
                events += loot(for: entity)
                entity.lootDropped = true
            } else {
                entity.velocity *= SIMD3(Double(Float(0.99)), Double(Float(0.95)), Double(Float(0.99)))
            }
            let delta = entity.previousPosition - entity.position
            var yaw = Double(entity.vehicleYaw ?? 0)
            if delta.x * delta.x + delta.z * delta.z > 0.001 {
                let target = Double(Float(atan2(delta.z, delta.x) * 180 / Double.pi))
                var difference = (target - yaw).truncatingRemainder(dividingBy: 360)
                if difference >= 180 { difference -= 360 }
                if difference < -180 { difference += 360 }
                yaw += min(max(difference, -20), 20)
            }
            entity.vehicleYaw = Float(yaw)
            entity.yaw = Float(yaw) * BetaMath.pi / 180 - BetaMath.pi
            for corner in 0..<4 {
                let x = Int(floor(entity.position.x + (Double(corner % 2) - 0.5) * 0.8))
                let y = Int(floor(entity.position.y + entity.height / 2))
                let z = Int(floor(entity.position.z + (Double(corner / 2) - 0.5) * 0.8))
                if world[BlockPosition(x, y, z)] == .snowLayer { world[BlockPosition(x, y, z)] = nil }
            }
            entity.pitch = 0
        } else {
            tickMinecart(&entity, world: world, player: player)
        }
        if entity.riderID == 0 {
            if player.health == 0 {
                entity.riderID = nil
            } else {
                player.teleport(to: Self.riderPosition(on: entity, isPlayer: true))
            }
        }
        return events
    }

    private mutating func tickMinecart(_ entity: inout GameEntity, world: BlockWorld, player: Player) {
        let verticalOffset = entity.height / 2
        entity.velocity.y -= Double(Float(0.04))
        var cell = BlockPosition(
            Int(floor(entity.position.x)), Int(floor(entity.position.y + verticalOffset)),
            Int(floor(entity.position.z)))
        if Self.isRail(world[BlockPosition(cell.x, cell.y - 1, cell.z)]) { cell.y -= 1 }
        var burningFuel = false
        if let state = world.state(at: cell), Self.isRail(state.kind) {
            let before = Self.railPoint(entity.position + SIMD3(0, verticalOffset, 0), world: world)
            let metadata = Int(state.metadata) & (state.kind == .rail ? 15 : 7)
            guard metadata < Self.railEnds.count else { return }
            let ends = Self.railEnds[metadata]
            entity.position.y = Double(cell.y) + (metadata >= 2 && metadata <= 5 ? 1 : 0)
            if metadata == 2 { entity.velocity.x -= 0.0078125 }
            if metadata == 3 { entity.velocity.x += 0.0078125 }
            if metadata == 4 { entity.velocity.z += 0.0078125 }
            if metadata == 5 { entity.velocity.z -= 0.0078125 }
            var direction = SIMD2(Double(ends.1.x - ends.0.x), Double(ends.1.z - ends.0.z))
            if entity.velocity.x * direction.x + entity.velocity.z * direction.y < 0 {
                direction = -direction
            }
            let length = sqrt(direction.x * direction.x + direction.y * direction.y)
            let speed = sqrt(entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z)
            entity.velocity.x = speed * direction.x / length
            entity.velocity.z = speed * direction.y / length
            let powered = state.kind == .poweredRail && state.metadata & 8 != 0
            if state.kind == .poweredRail && !powered {
                entity.velocity *= speed < 0.03 ? .zero : SIMD3(0.5, 0, 0.5)
            }
            let first = SIMD2(
                Double(cell.x) + 0.5 + Double(ends.0.x) / 2, Double(cell.z) + 0.5 + Double(ends.0.z) / 2)
            let last = SIMD2(
                Double(cell.x) + 0.5 + Double(ends.1.x) / 2, Double(cell.z) + 0.5 + Double(ends.1.z) / 2)
            let line = last - first
            let t =
                line.x == 0
                ? entity.position.z - Double(cell.z)
                : (line.y == 0
                    ? entity.position.x - Double(cell.x)
                    : ((entity.position.x - first.x) * line.x + (entity.position.z - first.y) * line.y) * 2)
            entity.position.x = first.x + line.x * t
            entity.position.z = first.y + line.y * t
            let moving = entity.velocity
            let passengerScale = entity.riderID == nil ? 1.0 : 0.75
            entity.velocity = SIMD3(
                min(max(moving.x * passengerScale, -0.4), 0.4), 0,
                min(max(moving.z * passengerScale, -0.4), 0.4))
            let requested = entity.velocity
            _ = EntityMotion.move(&entity, world: world, collisions: collisionView(player: player))
            let resolved = entity.velocity
            entity.velocity = moving
            if resolved.x != requested.x { entity.velocity.x = 0 }
            if resolved.z != requested.z { entity.velocity.z = 0 }
            entity.velocity.y = 0
            for end in [ends.0, ends.1]
            where end.y != 0 && Int(floor(entity.position.x)) - cell.x == end.x
                && Int(floor(entity.position.z)) - cell.z == end.z
            {
                entity.position.y += Double(end.y)
                break
            }
            if entity.riderID != nil {
                entity.velocity *= Double(Float(0.997))
            } else {
                if entity.metadata == 2 {
                    let pushLength = Double(
                        Float(
                            sqrt(
                                entity.pushDirection.x * entity.pushDirection.x + entity.pushDirection.y
                                    * entity.pushDirection.y)))
                    if pushLength > 0.01 {
                        burningFuel = true
                        entity.pushDirection /= pushLength
                        entity.velocity =
                            entity.velocity * Double(Float(0.8)) + SIMD3(
                                entity.pushDirection.x, 0, entity.pushDirection.y) * 0.04
                    } else {
                        entity.velocity *= Double(Float(0.9))
                    }
                }
                entity.velocity *= Double(Float(0.96))
            }
            if let after = Self.railPoint(entity.position + SIMD3(0, verticalOffset, 0), world: world),
                let before
            {
                let slope = (before.y - after.y) * 0.05
                let speed = sqrt(
                    entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z)
                if speed > 0 {
                    entity.velocity.x = entity.velocity.x / speed * (speed + slope)
                    entity.velocity.z = entity.velocity.z / speed * (speed + slope)
                }
                entity.position.y = after.y - verticalOffset
            }
            let nextX = Int(floor(entity.position.x))
            let nextZ = Int(floor(entity.position.z))
            if nextX != cell.x || nextZ != cell.z {
                let speed = sqrt(
                    entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z)
                entity.velocity.x = speed * Double(nextX - cell.x)
                entity.velocity.z = speed * Double(nextZ - cell.z)
            }
            if entity.metadata == 2 {
                let length = Double(
                    Float(
                        sqrt(
                            entity.pushDirection.x * entity.pushDirection.x + entity.pushDirection.y
                                * entity.pushDirection.y)))
                if length > 0.01
                    && entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z > 0.001
                {
                    entity.pushDirection /= length
                    if entity.pushDirection.x * entity.velocity.x + entity.pushDirection.y * entity.velocity.z
                        < 0
                    {
                        entity.pushDirection = .zero
                    } else {
                        entity.pushDirection = SIMD2(entity.velocity.x, entity.velocity.z)
                    }
                }
            }
            if powered {
                let speed = sqrt(
                    entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z)
                if speed > 0.01 {
                    entity.velocity += SIMD3(entity.velocity.x / speed, 0, entity.velocity.z / speed) * 0.06
                } else if metadata == 1 {
                    if world[BlockPosition(cell.x - 1, cell.y, cell.z)]?.isOpaque == true {
                        entity.velocity.x = 0.02
                    } else if world[BlockPosition(cell.x + 1, cell.y, cell.z)]?.isOpaque == true {
                        entity.velocity.x = -0.02
                    }
                } else if metadata == 0 {
                    if world[BlockPosition(cell.x, cell.y, cell.z - 1)]?.isOpaque == true {
                        entity.velocity.z = 0.02
                    } else if world[BlockPosition(cell.x, cell.y, cell.z + 1)]?.isOpaque == true {
                        entity.velocity.z = -0.02
                    }
                }
            }
        } else {
            entity.velocity.x = min(max(entity.velocity.x, -0.4), 0.4)
            entity.velocity.z = min(max(entity.velocity.z, -0.4), 0.4)
            if entity.onGround { entity.velocity *= 0.5 }
            _ = EntityMotion.move(&entity, world: world, collisions: collisionView(player: player))
            if !entity.onGround { entity.velocity *= Double(Float(0.95)) }
        }
        if burningFuel && random.nextInt(bound: 4) == 0 {
            entity.fuelTicks -= 1
            if entity.fuelTicks < 0 { entity.pushDirection = .zero }
            queuedEvents.append(.particle(name: "largesmoke", position: entity.position + SIMD3(0, 0.8, 0)))
        }
        let delta = entity.previousPosition - entity.position
        var yaw = entity.vehicleYaw ?? 0
        if delta.x * delta.x + delta.z * delta.z > 0.001 {
            yaw = Float(atan2(delta.z, delta.x) * 180 / Double.pi)
            if entity.vehicleReversed { yaw += 180 }
        }
        var difference = Double(yaw - (entity.vehicleYaw ?? 0)).truncatingRemainder(dividingBy: 360)
        if difference >= 180 { difference -= 360 }
        if difference < -180 { difference += 360 }
        if difference < -170 || difference >= 170 {
            yaw += 180
            entity.vehicleReversed.toggle()
        }
        entity.vehicleYaw = yaw
        entity.yaw = yaw * BetaMath.pi / 180 - BetaMath.pi
        entity.pitch = 0
    }

    static func isRail(_ block: BlockKind?) -> Bool {
        block.map { [27, 28, 66].contains($0.rawValue) } ?? false
    }

    public static func railOffsetPoint(_ point: SIMD3<Double>, offset: Double, world: BlockWorld)
        -> SIMD3<Double>?
    {
        var cell = BlockPosition(Int(floor(point.x)), Int(floor(point.y)), Int(floor(point.z)))
        if isRail(world[BlockPosition(cell.x, cell.y - 1, cell.z)]) { cell.y -= 1 }
        guard let state = world.state(at: cell), isRail(state.kind) else { return nil }
        let metadata = Int(state.metadata) & (state.kind == .rail ? 15 : 7)
        guard metadata < railEnds.count else { return nil }
        let ends = railEnds[metadata]
        let direction = SIMD2(Double(ends.1.x - ends.0.x), Double(ends.1.z - ends.0.z))
        let length = sqrt(direction.x * direction.x + direction.y * direction.y)
        var result = SIMD3(
            point.x + direction.x / length * offset,
            Double(cell.y + (metadata >= 2 && metadata <= 5 ? 1 : 0)),
            point.z + direction.y / length * offset)
        for end in [ends.0, ends.1]
        where end.y != 0 && Int(floor(result.x)) - cell.x == end.x
            && Int(floor(result.z)) - cell.z == end.z
        {
            result.y += Double(end.y)
            break
        }
        return railPoint(result, world: world)
    }

    public static func railPoint(_ point: SIMD3<Double>, world: BlockWorld) -> SIMD3<Double>? {
        var cell = BlockPosition(Int(floor(point.x)), Int(floor(point.y)), Int(floor(point.z)))
        if isRail(world[BlockPosition(cell.x, cell.y - 1, cell.z)]) { cell.y -= 1 }
        guard let state = world.state(at: cell), isRail(state.kind) else { return nil }
        let metadata = Int(state.metadata) & (state.kind == .rail ? 15 : 7)
        guard metadata < railEnds.count else { return nil }
        let ends = railEnds[metadata]
        let first = SIMD3(
            Double(cell.x) + 0.5 + Double(ends.0.x) / 2, Double(cell.y) + 0.5 + Double(ends.0.y) / 2,
            Double(cell.z) + 0.5 + Double(ends.0.z) / 2)
        let last = SIMD3(
            Double(cell.x) + 0.5 + Double(ends.1.x) / 2, Double(cell.y) + 0.5 + Double(ends.1.y) / 2,
            Double(cell.z) + 0.5 + Double(ends.1.z) / 2)
        var line = last - first
        line.y *= 2
        let t =
            line.x == 0
            ? point.z - Double(cell.z)
            : (line.z == 0
                ? point.x - Double(cell.x)
                : ((point.x - first.x) * line.x + (point.z - first.z) * line.z) * 2)
        var result = first + line * t
        if line.y < 0 { result.y += 1 }
        if line.y > 0 { result.y += 0.5 }
        return result
    }

    private static let railEnds: [(BlockPosition, BlockPosition)] = [
        (BlockPosition(0, 0, -1), BlockPosition(0, 0, 1)), (BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0)),
        (BlockPosition(-1, -1, 0), BlockPosition(1, 0, 0)),
        (BlockPosition(-1, 0, 0), BlockPosition(1, -1, 0)),
        (BlockPosition(0, 0, -1), BlockPosition(0, -1, 1)),
        (BlockPosition(0, -1, -1), BlockPosition(0, 0, 1)),
        (BlockPosition(0, 0, 1), BlockPosition(1, 0, 0)), (BlockPosition(0, 0, 1), BlockPosition(-1, 0, 0)),
        (BlockPosition(0, 0, -1), BlockPosition(-1, 0, 0)), (BlockPosition(0, 0, -1), BlockPosition(1, 0, 0)),
    ]
}
