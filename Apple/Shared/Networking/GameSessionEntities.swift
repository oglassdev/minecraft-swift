import Foundation
import MinecraftCore

extension GameSession {
    func receiveMultiplayerEntity(_ packet: BetaPacket) {
        guard let state = multiplayer else { return }
        switch packet {
        case .namedEntitySpawn(let id, let username, let position, let yaw, let pitch, let item):
            var entity = remoteEntity(id: id, kind: "player", position: position)
            entity.owner = username
            entity.yaw = networkYaw(yaw)
            entity.pitch = networkPitch(pitch)
            entity.contents = Array(repeating: nil, count: 5)
            if item > 0 { entity.contents[0] = ItemStack(id: UInt16(item)) }
            entitySimulation.upsert(entity)
        case .pickupSpawn(let id, let item, let position, let velocity):
            var entity = remoteEntity(id: id, kind: "item", position: position)
            entity.itemStack = item.stack
            entity.velocity = SIMD3<Double>(velocity) / 128
            entitySimulation.upsert(entity)
        case .mobSpawn(let id, let type, let position, let yaw, let pitch, let metadata):
            guard let kind = Self.mobKinds[type] else { return }
            var entity = remoteEntity(id: id, kind: kind, position: position)
            entity.yaw = networkYaw(yaw)
            entity.pitch = networkPitch(pitch)
            if type == 53 {
                entity.width *= 6
                entity.height *= 6
            }
            entitySimulation.upsert(entity)
            applyRemoteMetadata(id: Int64(id), entries: metadata)
        case .objectSpawn(let id, let type, let position, let data, let velocity):
            guard let kind = Self.objectKinds[type] else { return }
            var entity = remoteEntity(id: id, kind: kind, position: position)
            if (10...12).contains(type) { entity.metadata = UInt8(type - 10) }
            if type == 71 { entity.fallingBlock = BlockState(.gravel) }
            if data > 0 { entity.projectileOwner = Int64(data) }
            if let velocity {
                entity.velocity = SIMD3<Double>(velocity) / 8000
                if entity.hasProjectileRotation {
                    entity.yaw = Float(atan2(entity.velocity.x, -entity.velocity.z))
                    entity.pitch = Float(
                        atan2(entity.velocity.y, hypot(entity.velocity.x, entity.velocity.z)))
                    entity.previousYaw = entity.yaw
                    entity.previousPitch = entity.pitch
                }
            }
            if type == 63 {
                entity.acceleration = entity.velocity
                entity.velocity = .zero
            }
            entitySimulation.upsert(entity)
        case .painting(let id, let title, let position, let direction):
            var entity = GameEntity(id: Int64(id), kind: "painting", position: center(of: position))
            entity.paintingMotive = title
            entity.paintingAnchor = position
            entity.paintingFacing = UInt8(truncatingIfNeeded: direction) & 3
            entitySimulation.upsert(entity)
        case .weatherEntity(let id, let type, let position):
            guard type == 1 else { return }
            var entity = remoteEntity(id: id, kind: "lightningBolt", position: position)
            entity.effectSeed = Int64.random(in: .min ... .max)
            entity.lightningFlashes = Int.random(in: 1...3)
            entitySimulation.upsert(entity)
            play(
                "ambient.weather.thunder", at: SIMD3<Float>(entity.position), volume: 10000,
                pitch: Float.random(in: 0.8...1))
            play(
                "random.explode", at: SIMD3<Float>(entity.position), volume: 2,
                pitch: Float.random(in: 0.5...0.7))
        case .relativeMove(let id, let delta): moveRemote(id: id, delta: delta)
        case .relativeMoveLook(let id, let delta, let yaw, let pitch):
            moveRemote(id: id, delta: delta, yaw: yaw, pitch: pitch)
        case .entityLook(let id, let yaw, let pitch):
            entitySimulation.update(id: Int64(id)) { entity in
                entity.remoteYaw = networkYaw(yaw, projectile: entity.hasProjectileRotation)
                entity.remotePitch = networkPitch(pitch, projectile: entity.hasProjectileRotation)
                entity.remoteTicks = 3
            }
        case .teleport(let id, let position, let yaw, let pitch):
            state.fixedPositions[Int64(id)] = position
            entitySimulation.update(id: Int64(id)) { entity in
                entity.remotePosition = SIMD3<Double>(position) / 32 + SIMD3(0, 1.0 / 64, 0)
                entity.remoteYaw = networkYaw(yaw, projectile: entity.hasProjectileRotation)
                entity.remotePitch = networkPitch(pitch, projectile: entity.hasProjectileRotation)
                entity.remoteTicks = 3
            }
        case .entityVelocity(let id, let velocity):
            let vector = SIMD3<Double>(velocity) / 8000
            if id == state.localEntityID {
                player.addVelocity(vector - player.velocity)
            } else {
                entitySimulation.update(id: Int64(id)) { $0.velocity = vector }
            }
        case .metadata(let id, let entries): applyRemoteMetadata(id: Int64(id), entries: entries)
        case .equipment(let id, let slot, let item, let damage):
            entitySimulation.update(id: Int64(id)) { entity in
                guard (0...4).contains(slot) else { return }
                if entity.contents.count < 5 {
                    entity.contents += Array(repeating: nil, count: 5 - entity.contents.count)
                }
                entity.contents[Int(slot)] =
                    item < 0 ? nil : ItemStack(id: UInt16(item), damage: UInt16(bitPattern: damage))
            }
        case .destroyEntity(let id):
            entitySimulation.remove(ids: [Int64(id)])
            state.fixedPositions.removeValue(forKey: Int64(id))
            if state.vehicleID == Int64(id) { state.vehicleID = nil }
        case .collect(let id, _):
            if let item = entities.first(where: { $0.id == Int64(id) }) {
                play(
                    "random.pop", at: SIMD3<Float>(item.position), volume: 0.2,
                    pitch: Float.random(in: 1.4...2.8))
            }
            entitySimulation.remove(ids: [Int64(id)])
            state.fixedPositions.removeValue(forKey: Int64(id))
        case .entityStatus(let id, let status):
            if id == state.localEntityID && status == 2 { player.animateHurt() }
            entitySimulation.update(id: Int64(id)) { entity in
                if status == 2 {
                    entity.hurtTicks = 10
                } else if status == 3 {
                    entity.health = 0
                    entity.deathTicks = 1
                } else if status == 6 || status == 7 {
                    for _ in 0..<7 {
                        enqueueParticle(
                            .particle(
                                name: status == 7 ? "heart" : "smoke",
                                position: entity.position + SIMD3(0, entity.height * 0.8, 0)))
                    }
                }
            }
        case .animation(let id, let animation):
            if id == state.localEntityID && animation == 3 { wakeFromBed(setSpawn: false) }
            entitySimulation.update(id: Int64(id)) { entity in
                if animation == 1 {
                    entity.attackCooldown = 6
                } else if animation == 2 {
                    entity.hurtTicks = 10
                }
            }
        case .attachEntity(let id, let vehicle):
            if id == state.localEntityID {
                state.vehicleID = vehicle < 0 ? nil : Int64(vehicle)
            } else {
                for entity in entities where entity.riderID == Int64(id) {
                    entitySimulation.update(id: entity.id) { $0.riderID = nil }
                }
                if vehicle >= 0 { entitySimulation.update(id: Int64(vehicle)) { $0.riderID = Int64(id) } }
            }
        case .sleep(let id, let mode, let position):
            if id == state.localEntityID && mode == 0 {
                beginSleeping(at: position)
                sleepTicks = 1
                resetInput()
            } else {
                entitySimulation.update(id: Int64(id)) { $0.targetPosition = center(of: position) }
            }
        case .soundEffect(let effect, let position, let data):
            playMultiplayerEffect(effect, at: position, data: data)
        case .statistic(let id, let amount):
            notifyAchievements(statistics.increment(Int(id), by: Int(amount)))
        case .mapData(let item, let id, let bytes): if item == 358 { maps.applyNetwork(id: id, bytes: bytes) }
        default: break
        }
    }

    private static let mobKinds: [UInt8: String] = [
        50: "creeper", 51: "skeleton", 52: "spider", 53: "giant", 54: "zombie", 55: "slime",
        56: "ghast", 57: "pigZombie", 90: "pig", 91: "sheep", 92: "cow", 93: "chicken", 94: "squid",
        95: "wolf",
    ]

    private static let objectKinds: [Int8: String] = [
        1: "boat", 10: "minecart", 11: "minecart", 12: "minecart", 50: "primedTnt", 60: "arrow",
        61: "snowball", 62: "egg", 63: "fireball", 70: "fallingSand", 71: "fallingSand",
        90: "fishingHook",
    ]

    func remoteEntity(id: Int32, kind: String, position: SIMD3<Int32>) -> GameEntity {
        multiplayer?.fixedPositions[Int64(id)] = position
        return GameEntity(id: Int64(id), kind: kind, position: SIMD3<Double>(position) / 32)
    }

    func networkYaw(_ angle: UInt8, projectile: Bool = false) -> Float {
        let angle = Float(Int8(bitPattern: angle)) * Float(Double.pi) / 128
        return projectile ? Float(Double.pi) - angle : angle + Float(Double.pi)
    }
    func networkPitch(_ angle: UInt8, projectile: Bool = false) -> Float {
        Float(Int8(bitPattern: angle)) * Float(Double.pi) / 128 * (projectile ? 1 : -1)
    }

    func moveRemote(id: Int32, delta: SIMD3<Int8>, yaw: UInt8? = nil, pitch: UInt8? = nil) {
        guard let state = multiplayer, let previous = state.fixedPositions[Int64(id)] else { return }
        let position = previous &+ SIMD3<Int32>(truncatingIfNeeded: delta)
        state.fixedPositions[Int64(id)] = position
        entitySimulation.update(id: Int64(id)) { entity in
            entity.remotePosition = SIMD3<Double>(position) / 32
            entity.remoteTicks = 3
            if let yaw { entity.remoteYaw = networkYaw(yaw, projectile: entity.hasProjectileRotation) }
            if let pitch {
                entity.remotePitch = networkPitch(pitch, projectile: entity.hasProjectileRotation)
            }
        }
    }

    func applyRemoteMetadata(id: Int64, entries: [BetaMetadataEntry]) {
        entitySimulation.update(id: id) { entity in
            for entry in entries {
                switch (entry.index, entry.value) {
                case (0, .byte(let flags)):
                    entity.remoteFlags = UInt8(bitPattern: flags)
                    entity.fireTicks = flags & 1 != 0 ? 300 : 0
                case (16, .byte(let value)):
                    if entity.kind == "creeper" {
                        entity.specialTicks = Int(value)
                        continue
                    }
                    entity.metadata = UInt8(bitPattern: value)
                    if entity.kind == "slime" {
                        let size = max(1, Int(value))
                        entity.width = Double(Float(0.6) * Float(size))
                        entity.height = entity.width
                    }
                    if entity.kind == "pig" { entity.metadata = value == 0 ? 0 : 1 }
                case (17, .byte(let value)):
                    if entity.kind == "creeper" { entity.metadata = UInt8(bitPattern: value) & 1 }
                case (17, .string(let owner)): entity.owner = owner
                case (18, .int(let health)): if entity.kind == "wolf" { entity.health = Int(health) }
                default: break
                }
            }
        }
    }

    func playMultiplayerEffect(_ effect: Int32, at position: BlockPosition, data: Int32) {
        switch effect {
        case 1000, 1001: play("random.click", at: position.vector, pitch: effect == 1001 ? 1.2 : 1)
        case 1002: play("random.bow", at: position.vector, pitch: 1.2)
        case 1003:
            play(
                Bool.random() ? "random.door_open" : "random.door_close", at: position.vector,
                pitch: Float.random(in: 0.9...1))
        case 1004: play("random.fizz", at: position.vector, volume: 0.5, pitch: Float.random(in: 1.8...3.4))
        case 1005:
            let record: String?
            switch data {
            case 2256: record = "13"
            case 2257: record = "cat"
            default: record = nil
            }
            audio.playRecord(record, at: position.vector)
        case 2000:
            for _ in 0..<10 { enqueueParticle(.particle(name: "smoke", position: center(of: position))) }
        case 2001:
            let id = UInt8(truncatingIfNeeded: data)
            if let kind = BlockKind(rawValue: id) { play(stepSound(kind), at: position.vector, pitch: 0.8) }
            enqueueParticle(
                .particle(name: "tilecrack_\(id)_\((data >> 8) & 255)", position: center(of: position)))
        default: break
        }
    }
}
