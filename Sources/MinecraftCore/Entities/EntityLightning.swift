import Foundation

extension EntitySimulation {
    mutating func tickLightning(
        _ bolt: inout GameEntity, world: inout BlockWorld, player: inout Player,
        inventory: inout PlayerInventory
    ) -> [BlockEvent] {
        var generator = effectRandoms[bolt.id] ?? JavaRandom(seed: bolt.effectSeed)
        var events: [BlockEvent] = []
        let cell = BlockPosition(
            Int(floor(bolt.position.x)), Int(floor(bolt.position.y)), Int(floor(bolt.position.z)))
        let loaded = lightningAreaLoaded(in: world, at: cell)
        if bolt.ageTicks == 1, player.difficulty >= 2, loaded {
            igniteLightningCell(cell, in: &world)
            for _ in 0..<4 {
                let offset = BlockPosition(
                    cell.x + generator.nextInt(bound: 3) - 1,
                    cell.y + generator.nextInt(bound: 3) - 1,
                    cell.z + generator.nextInt(bound: 3) - 1)
                igniteLightningCell(offset, in: &world)
            }
        }
        if bolt.lightningState == 2 {
            events.append(
                .sound(
                    name: "ambient.weather.thunder", position: bolt.position, volume: 10000,
                    pitch: 0.8 + generator.nextFloat() * 0.2))
            events.append(
                .sound(
                    name: "random.explode", position: bolt.position, volume: 2,
                    pitch: 0.5 + generator.nextFloat() * 0.2))
        }
        bolt.lightningState -= 1
        if bolt.lightningState < 0 {
            if bolt.lightningFlashes == 0 {
                bolt.health = 0
            } else if bolt.lightningState < -generator.nextInt(bound: 10) {
                bolt.lightningFlashes -= 1
                bolt.lightningState = 1
                bolt.effectSeed = generator.nextLong()
                if loaded { igniteLightningCell(cell, in: &world) }
            }
        }
        if bolt.lightningState >= 0 {
            let area = AxisAlignedBox(
                min: bolt.position - SIMD3(3, 3, 3), max: bolt.position + SIMD3(3, 9, 3))
            if player.bounds.intersects(area) { player.strikeByLightning(inventory: &inventory) }
            for index in entities.indices
            where entities[index].id != bolt.id && entities[index].health > 0
                && entities[index].bounds.intersects(area)
            {
                if entities[index].kind == "pig" {
                    let position = entities[index].position
                    let yaw = entities[index].yaw
                    let pitch = entities[index].pitch
                    entities[index].health = 0
                    entities[index].deathTicks = 20
                    entities[index].lootDropped = true
                    let id = spawn(kind: "pigZombie", position: position)
                    update(id: id) {
                        $0.yaw = yaw
                        $0.pitch = pitch
                    }
                    continue
                }
                let velocity = entities[index].velocity
                if ![
                    "pigZombie", "ghast", "primedTnt", "fallingSand", "arrow", "snowball", "egg", "fireball",
                ].contains(entities[index].kind) {
                    _ = hurtEntity(at: index, amount: 5, sourcePosition: bolt.position)
                }
                entities[index].velocity = velocity
                if entities[index].kind == "creeper" { entities[index].metadata |= 1 }
                entities[index].fireTicks = max(300, entities[index].fireTicks + 1)
            }
        }
        effectRandoms[bolt.id] = bolt.health > 0 ? generator : nil
        return events
    }

    private func lightningAreaLoaded(in world: BlockWorld, at cell: BlockPosition) -> Bool {
        guard cell.y + 10 >= 0, cell.y - 10 < 128 else { return false }
        for x in ((cell.x - 10) >> 4)...((cell.x + 10) >> 4) {
            for z in ((cell.z - 10) >> 4)...((cell.z + 10) >> 4) {
                if world.chunks[ChunkPosition(x, z)] == nil { return false }
            }
        }
        return true
    }

    private func igniteLightningCell(_ position: BlockPosition, in world: inout BlockWorld) {
        guard world[position] == nil, (0..<128).contains(position.y) else { return }
        let flammable: Set<UInt8> = [5, 17, 18, 31, 35, 46, 47, 53, 85]
        let supported = world[BlockPosition(position.x, position.y - 1, position.z)]?.isOpaque == true
        let neighbors = [
            BlockPosition(1, 0, 0), BlockPosition(-1, 0, 0), BlockPosition(0, 1, 0),
            BlockPosition(0, -1, 0), BlockPosition(0, 0, 1), BlockPosition(0, 0, -1),
        ]
        if supported
            || neighbors.contains(where: {
                world[BlockPosition(position.x + $0.x, position.y + $0.y, position.z + $0.z)].map {
                    flammable.contains($0.rawValue)
                } ?? false
            })
        {
            world[position] = .fire
        }
    }
}
