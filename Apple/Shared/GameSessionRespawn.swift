import Foundation
import MinecraftCore

extension GameSession {
    func beginSleeping(at bed: BlockPosition) {
        guard world.dimension == 0, sleepTicks == 0, player.health > 0,
            abs(player.position.x - Double(bed.x)) <= 3,
            abs(player.eyePositionDouble.y - Double(bed.y)) <= 2,
            abs(player.position.z - Double(bed.z)) <= 3
        else { return }
        let time = worldTime % 24000
        guard time > 12541 && time < 23458 else {
            postChat("You can only sleep at night")
            return
        }
        sleepingBed = bed
        let facing = Int(world.state(at: bed)?.metadata ?? 0) & 3
        let offset = [SIMD2<Float>(0.5, 0.9), SIMD2(0.1, 0.5), SIMD2(0.5, 0.1), SIMD2(0.9, 0.5)][facing]
        player.beginSleeping(
            eyePosition: SIMD3(
                Double(bed.x) + Double(offset.x), Double(bed.y) + Double(Float(0.9375)),
                Double(bed.z) + Double(offset.y)))
        camera.setPosition(player.eyePosition)
        sleepTicks = 1
        resetInput()
    }

    func wakeFromBed(setSpawn: Bool) {
        player.endSleeping()
        if let bed = sleepingBed, world[bed] == .bed {
            let exit = bedRespawnExit(at: bed, in: world) ?? BlockPosition(bed.x, bed.y + 1, bed.z)
            player.teleport(
                to: SIMD3(Double(exit.x) + 0.5, Double(Float(exit.y) + 0.1), Double(exit.z) + 0.5))
            camera.setPosition(player.eyePosition)
            if setSpawn { bedSpawn = bed }
        }
        sleepingBed = nil
        sleepTicks = 0
    }

    /// BlockBed's two neighboring 3×3 scans require actual air above a normal cube.
    func bedRespawnExit(at bed: BlockPosition, in world: BlockWorld) -> BlockPosition? {
        guard let state = world.state(at: bed), state.kind == .bed else { return nil }
        let direction = [SIMD2(0, 1), SIMD2(-1, 0), SIMD2(0, -1), SIMD2(1, 0)][Int(state.metadata & 3)]
        for half in 0...1 {
            let startX = bed.x - direction.x * half - 1
            let startZ = bed.z - direction.y * half - 1
            for x in startX...(startX + 2) {
                for z in startZ...(startZ + 2) {
                    let below = BlockPosition(x, bed.y - 1, z)
                    let feet = BlockPosition(x, bed.y, z)
                    let head = BlockPosition(x, bed.y + 1, z)
                    if world[below]?.isNormalCube == true, world[feet] == nil, world[head] == nil {
                        return feet
                    }
                }
            }
        }
        return nil
    }

    func finishSingleplayerRespawn(generation: UInt64) async {
        do {
            var exit: BlockPosition?
            var invalidBed = false
            if let bed = bedSpawn {
                try await loadRespawnArea(around: bed, generation: generation)
                guard sessionGeneration == generation, !isMultiplayer else { return }
                exit = bedRespawnExit(at: bed, in: world)
                if exit == nil {
                    bedSpawn = nil
                    invalidBed = true
                }
            }
            if exit == nil {
                try await loadRespawnArea(around: spawn, generation: generation)
                guard sessionGeneration == generation, !isMultiplayer else { return }
            }
            let position: SIMD3<Double>
            if let exit {
                position = SIMD3(Double(exit.x) + 0.5, Double(Float(exit.y) + 0.1), Double(exit.z) + 0.5)
            } else {
                position = SIMD3(Double(spawn.x) + 0.5, Double(spawn.y) + 1, Double(spawn.z) + 0.5)
            }
            player = Player(position: position)
            showDeathScreen = false
            deathScreenTicks = 0
            player.difficulty = options.difficulty
            if exit == nil {
                while !BlockCollision.boxes(in: world, intersecting: player.bounds).isEmpty {
                    player.teleport(to: player.position + SIMD3(0, 1, 0))
                }
            }
            camera = Camera(position: player.eyePosition, yaw: Float(Double.pi), pitch: 0)
            isLoading = false
            isPaused = false
            accumulator = 0
            if invalidBed { postChat("Your home bed was missing or obstructed") }
            updateTarget()
            refreshHUD()
            saveWorld()
        } catch {
            guard sessionGeneration == generation, !isMultiplayer else { return }
            isLoading = false
            isPaused = true
            errorMessage = "Could not load respawn area: \(error.localizedDescription)"
        }
    }

    func loadRespawnArea(around position: BlockPosition, generation: UInt64) async throws {
        let corners = [-3, 3].flatMap { x in
            [-3, 3].map { z in ChunkPosition((position.x + x) >> 4, (position.z + z) >> 4) }
        }
        guard !corners.allSatisfy({ world.chunks[$0] != nil }) else { return }
        let center = ChunkPosition(position.x >> 4, position.z >> 4)
        let snapshot = world
        let chunks = try await service.extend(
            snapshot, around: center,
            maximumEntityID: entitySimulation.nextEntityID - 1, radius: 1)
        guard sessionGeneration == generation, !isMultiplayer else { return }
        for chunk in chunks {
            let isNew = world.chunks[chunk.position] == nil
            world.setChunk(chunk, updateLighting: false)
            if isNew { for entity in chunk.entities { entitySimulation.upsert(entity) } }
        }
        lastStreamCenter = center
        streamedRadius = 1
    }
}
