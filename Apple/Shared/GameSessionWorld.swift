import Foundation
import MinecraftCore

extension GameSession {
    var desiredChunkRadius: Int {
        let view = [16, 8, 4, 2][min(3, max(0, options.renderDistance))]
        let survey = heldItem?.id == 358 ? (world.dimension == -1 ? 4 : 8) : 0
        return max(9, view, survey)
    }

    func loadWorld() async {
        let generation = sessionGeneration
        do {
            loadingProgress = 0
            let loaded = try await service.load(radius: 9) { [weak self] progress in
                Task { @MainActor in
                    guard let self, generation == self.sessionGeneration else { return }
                    self.loadingProgress = progress
                }
            }
            guard generation == sessionGeneration, !isMultiplayer else { return }
            adopt(loaded)
        } catch {
            guard generation == sessionGeneration, !isMultiplayer else { return }
            errorMessage = "Could not load world: \(error.localizedDescription)"
            isLoading = false
            isPaused = true
        }
    }

    func adopt(_ loaded: LoadedGame) {
        world = loaded.world
        maps = loaded.maps
        hasLoadedWorld = true
        litRevision = world.lightingRevision
        worldTime = loaded.level.time
        worldName = loaded.level.name
        spawn = loaded.level.spawn
        bedSpawn = loaded.level.player.bedSpawn
        let saved = loaded.level.player
        inventory = saved.inventory
        player = Player(position: saved.position, health: saved.health)
        recordedDamageTaken = 0
        hotbarPickupTicks = Array(repeating: 0, count: 9)
        player.restoreRuntime(
            air: saved.air, fireTicks: saved.fireTicks, fallDistance: saved.fallDistance,
            onGround: saved.onGround, hurtTime: saved.hurtTicks, deathTime: saved.deathTicks,
            attackTime: saved.attackTicks)
        player.difficulty = options.difficulty
        player.addVelocity(saved.velocity)
        camera = Camera(position: player.eyePosition, yaw: saved.yaw, pitch: saved.pitch)
        showDeathScreen = saved.health <= 0
        if saved.sleeping {
            sleepingBed = BlockPosition(
                Int(floor(saved.position.x)), Int(floor(saved.position.y + Double(Float(0.2)))),
                Int(floor(saved.position.z)))
            player.beginSleeping(eyePosition: saved.position + SIMD3(0, Double(Float(0.2)), 0))
            wakeFromBed(setSpawn: false)
        }
        lastStreamCenter = loaded.center
        streamedRadius = loaded.radius
        itemActions = ItemActions(seed: world.seed)
        blockSimulation = BlockSimulation(seed: world.seed)
        entitySimulation = EntitySimulation(seed: world.seed, naturalSpawningEnabled: false)
        entitySimulation.restore(world.chunks.values.flatMap(\.entities))
        entitySimulation.reserveIDs(through: loaded.level.nextEntityID - 1)
        weather = loaded.level.weather
        worldTickState = loaded.tickState
        rainStrength = weather.rainStrength
        thunderStrength = weather.weightedThunderStrength
        isLoading = false
        loadingProgress = nil
        streaming = false
        relighting = false
        evictionInProgress = false
        updateTarget()
        refreshHUD()
    }

    func extendWorld(around center: ChunkPosition) {
        guard !isMultiplayer else { return }
        streaming = true
        let radius =
            center == lastStreamCenter
            ? min(desiredChunkRadius, max(streamedRadius + 1, streamedRadius * 2))
            : min(streamedRadius, desiredChunkRadius)
        lastStreamCenter = center
        let snapshot = world
        let generation = sessionGeneration
        let maximumID = entitySimulation.nextEntityID - 1
        let backend = service
        streamingTask = Task {
            defer { if generation == sessionGeneration { streaming = false } }
            do {
                let chunks = try await backend.extend(
                    snapshot, around: center, maximumEntityID: maximumID, radius: radius)
                guard generation == sessionGeneration, !isMultiplayer else { return }
                streamedRadius = radius
                for chunk in chunks {
                    if let current = world.chunks[chunk.position], let old = snapshot.chunks[chunk.position],
                        current.revision != old.revision
                    {
                        continue
                    }
                    let newChunk = world.chunks[chunk.position] == nil
                    world.setChunk(chunk, updateLighting: false)
                    if newChunk { for entity in chunk.entities { entitySimulation.upsert(entity) } }
                }
                evictDistantChunks()
            } catch {
                guard generation == sessionGeneration, !isMultiplayer, !Task.isCancelled else { return }
                errorMessage = "Could not load more terrain: \(error.localizedDescription)"
            }
        }
    }

    func relightWorld() {
        guard !isMultiplayer else { return }
        relighting = true
        let snapshot = world
        let generation = sessionGeneration
        Task {
            let lit = await Task.detached {
                var world = snapshot
                WorldLighting.rebuild(world: &world, changedChunks: snapshot.pendingLightingChunks)
                return world
            }.value
            guard generation == sessionGeneration, !isMultiplayer else { return }
            for chunk in lit.chunks.values {
                guard let current = world.chunks[chunk.position],
                    let original = snapshot.chunks[chunk.position],
                    current.blockIDs == original.blockIDs
                else { continue }
                world.applyLighting(from: chunk)
            }
            litRevision = snapshot.lightingRevision
            relighting = false
        }
    }

    /// Chunks accepted by `include`, with the live entities standing in them attached.
    func chunksWithEntities(where include: (Chunk) -> Bool = { _ in true }) -> [Chunk] {
        let grouped = Dictionary(grouping: entitySimulation.entities, by: { chunkPosition(of: $0.position) })
        return world.chunks.values.filter(include).map { original in
            var chunk = original
            chunk.entities = grouped[chunk.position] ?? []
            return chunk
        }
    }

    func snapshotWithEntities() -> BlockWorld {
        var snapshot = world
        for chunk in chunksWithEntities() { snapshot.setChunk(chunk, updateLighting: false) }
        return snapshot
    }

    func chunkPosition(of position: SIMD3<Double>) -> ChunkPosition {
        ChunkPosition(Int(floor(position.x)) >> 4, Int(floor(position.z)) >> 4)
    }

    func savedLevel() -> SavedLevel {
        let savedPlayer = SavedPlayer(
            position: player.position, velocity: player.velocity,
            yaw: camera.yaw, pitch: camera.pitch, health: player.health, inventory: inventory,
            dimension: world.dimension, bedSpawn: bedSpawn,
            air: player.air, fireTicks: player.fireTicks, fallDistance: player.fallDistance,
            onGround: player.onGround, hurtTicks: player.hurtTime, deathTicks: player.deathTime,
            attackTicks: player.attackTime, sleeping: player.isSleeping, sleepTicks: sleepTicks)
        return SavedLevel(
            seed: world.seed, time: worldTime, spawn: spawn, player: savedPlayer, name: worldName,
            nextEntityID: entitySimulation.nextEntityID, weather: weather)
    }

    func saveWorld(completion: (@MainActor () -> Void)? = nil) {
        saveStatistics()
        guard !isLoading, !isMultiplayer, hasLoadedWorld else {
            let backend = service
            Task {
                await backend.flush()
                completion?()
            }
            return
        }
        let chunks = chunksWithEntities()
        let level = savedLevel()
        let mapSnapshot = maps
        let backend = service
        let generation = sessionGeneration
        Task {
            do {
                try await backend.save(chunks: chunks, level: level, maps: mapSnapshot)
            } catch {
                if generation == sessionGeneration, !isMultiplayer {
                    errorMessage = "Could not save world: \(error.localizedDescription)"
                }
            }
            completion?()
        }
        refreshHUD()
    }

    func evictDistantChunks() {
        guard !isMultiplayer, !evictionInProgress else { return }
        let center = chunkPosition(of: player.position)
        let keepRadius = desiredChunkRadius + 2
        let distant = chunksWithEntities {
            abs($0.position.x - center.x) > keepRadius || abs($0.position.z - center.z) > keepRadius
        }
        guard !distant.isEmpty else { return }
        evictionInProgress = true
        let backend = service
        let generation = sessionGeneration
        let time = worldTime
        let dimension = world.dimension
        Task {
            defer { if generation == sessionGeneration { evictionInProgress = false } }
            do {
                try await backend.saveChunks(distant, worldTime: time, dimension: dimension)
                guard generation == sessionGeneration, !isMultiplayer else { return }
                let currentCenter = chunkPosition(of: player.position)
                var removed: Set<ChunkPosition> = []
                for chunk in distant {
                    guard world.chunks[chunk.position]?.revision == chunk.revision,
                        abs(chunk.position.x - currentCenter.x) > desiredChunkRadius + 2
                            || abs(chunk.position.z - currentCenter.z) > desiredChunkRadius + 2
                    else { continue }
                    world.removeChunk(at: chunk.position)
                    removed.insert(chunk.position)
                }
                entitySimulation.remove(
                    ids: entitySimulation.entities.filter { removed.contains(chunkPosition(of: $0.position)) }
                        .map(\.id))
            } catch {
                if generation == sessionGeneration {
                    errorMessage = "Could not save distant terrain: \(error.localizedDescription)"
                }
            }
        }
    }

    func updatePortalContact() {
        previousPortalTime = portalTime
        let bounds = player.bounds
        let lowY = max(0, Int(floor(bounds.min.y)))
        let highY = min(127, Int(floor(bounds.max.y)))
        guard lowY <= highY else {
            portalCooldown = max(0, portalCooldown - 1)
            portalTicks = max(0, portalTicks - 4)
            return
        }
        let touching = (Int(floor(bounds.min.x))...Int(floor(bounds.max.x))).contains { x in
            (lowY...highY).contains { y in
                (Int(floor(bounds.min.z))...Int(floor(bounds.max.z))).contains { z in
                    world[BlockPosition(x, y, z)] == .portal
                }
            }
        }
        if touching {
            portalTime = min(1, portalTime + 0.0125)
            if portalCooldown > 0 {
                portalCooldown = 10
                portalTicks = 0
                return
            }
            portalTicks += 1
            if portalTicks >= 80 {
                let destination: Int8 = world.dimension == -1 ? 0 : -1
                let scale: Double = destination == -1 ? 0.125 : 8
                travel(to: destination, position: player.position * SIMD3(scale, 1, scale), placePortal: true)
            }
        } else {
            portalTime = max(0, portalTime - 0.05)
            portalCooldown = max(0, portalCooldown - 1)
            portalTicks = max(0, portalTicks - 4)
        }
    }

    func respawnSingleplayer() {
        if isMultiplayer {
            respawnMultiplayer()
            return
        }
        showDeathScreen = false
        deathScreenTicks = 0
        returnCursorAndCrafting()
        inventory = PlayerInventory()
        sleepingBed = nil
        sleepTicks = 0
        if world.dimension == -1 {
            let target = bedSpawn ?? spawn
            travel(
                to: 0, position: SIMD3(Double(target.x) + 0.5, Double(target.y) + 1, Double(target.z) + 0.5),
                placePortal: false, respawning: true)
        } else {
            invalidateWorldTasks()
            let generation = sessionGeneration
            isLoading = true
            resetInput()
            Task { await finishSingleplayerRespawn(generation: generation) }
        }
    }

    func travel(to dimension: Int8, position: SIMD3<Double>, placePortal: Bool, respawning: Bool = false) {
        guard !isLoading, !isMultiplayer else { return }
        returnCursorAndCrafting()
        let snapshot = snapshotWithEntities()
        var level = savedLevel()
        let mapSnapshot = maps
        let backend = service
        if respawning {
            level.player.health = 20
            level.player.inventory = PlayerInventory()
        }
        invalidateWorldTasks()
        let generation = sessionGeneration
        portalTicks = 0
        portalCooldown = 10
        isLoading = true
        resetInput()
        Task {
            do {
                let loaded = try await backend.travel(
                    from: snapshot, level: level, to: dimension,
                    position: position, yaw: camera.yaw, placePortal: placePortal, maps: mapSnapshot)
                guard generation == sessionGeneration, !isMultiplayer else { return }
                adopt(loaded)
                portalCooldown = 10
                if respawning {
                    isLoading = true
                    await finishSingleplayerRespawn(generation: generation)
                }
            } catch {
                guard generation == sessionGeneration, !isMultiplayer else { return }
                isLoading = false
                errorMessage = "Could not change dimension: \(error.localizedDescription)"
            }
        }
    }

    func enqueueParticle(_ event: BlockEvent) {
        switch event {
        case .particle, .explosion:
            if particleEvents.count >= 512 { particleEvents.removeFirst(128) }
            particleEvents.append(event)
        default: break
        }
    }

    func takeParticleEvents() -> [BlockEvent] {
        let events = particleEvents
        particleEvents.removeAll(keepingCapacity: true)
        return events
    }
}
