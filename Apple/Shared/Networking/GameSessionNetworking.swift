import Foundation
import MinecraftCore

struct SingleplayerSnapshot {
    let worldName: String
    let worldMenuOpen: Bool
    let world: BlockWorld
    let worldTime: Int64
    let player: Player
    let inventory: PlayerInventory
    let camera: Camera
    let bedSpawn: BlockPosition?
    let spawn: BlockPosition
    let blockSimulation: BlockSimulation
    let entitySimulation: EntitySimulation
    let itemActions: ItemActions
    let maps: BetaMapCollection
    let weather: WorldWeather
    let center: ChunkPosition?

    @MainActor init(_ game: GameSession) {
        worldName = game.worldName
        worldMenuOpen = game.worldMenuOpen
        world = game.world
        worldTime = game.worldTime
        player = game.player
        inventory = game.inventory
        camera = game.camera
        bedSpawn = game.bedSpawn
        spawn = game.spawn
        blockSimulation = game.blockSimulation
        entitySimulation = game.entitySimulation
        itemActions = game.itemActions
        maps = game.maps
        weather = game.weather
        center = game.lastStreamCenter
    }
}

@MainActor
final class MultiplayerState {
    let singleplayer: SingleplayerSnapshot
    var client: MultiplayerClient?
    var localEntityID: Int32 = 0
    var receivedPosition = false
    var loadedChunks: Set<ChunkPosition> = []
    var fixedPositions: [Int64: SIMD3<Int32>] = [:]
    var playerWindow: [ItemStack?] = Array(repeating: nil, count: 45)
    var windowID: Int8 = 0
    var windowType: Int8 = -1
    var windowTitle = ""
    var containerSlotCount = 0
    var windowSlots: [ItemStack?] = []
    var transactionID: Int16 = 0
    var pendingClicks: [Int16: MultiplayerClickSnapshot] = [:]
    var digPosition: BlockPosition?
    var digFace: UInt8 = 0
    var awaitingDig: BlockPosition?
    var lastPosition: SIMD3<Double>?
    var lastYaw: Float?
    var lastPitch: Float?
    var wasSneaking = false
    var vehicleID: Int64?
    var raining = false
    var respawnRequested = false
    var pendingSign: BlockPosition?

    init(singleplayer: SingleplayerSnapshot) { self.singleplayer = singleplayer }
}

extension GameSession {
    func connectMultiplayer(host: String, port: UInt16, username: String) {
        guard !isLoading, !connectionPending, !worldTransitionPending else { return }
        if isMultiplayer { disconnectMultiplayer() }
        isPaused = true
        resetInput()
        connectionPending = true
        streamingTask?.cancel()
        sessionGeneration &+= 1
        let generation = sessionGeneration
        multiplayerStatus = "Saving singleplayer world…"
        returnCursorAndCrafting()
        saveWorld { [weak self] in
            guard let self, self.sessionGeneration == generation, self.connectionPending else { return }
            let state = MultiplayerState(singleplayer: SingleplayerSnapshot(self))
            self.multiplayer = state
            self.isMultiplayer = true
            self.worldMenuOpen = false
            self.connectionPending = false
            self.isLoading = true
            self.isPaused = false
            self.inventoryOpen = false
            self.chatOpen = false
            self.signEditorOpen = false
            self.bedSpawn = nil
            self.sleepingBed = nil
            self.flight = false
            self.streaming = false
            self.relighting = false
            self.evictionInProgress = false
            self.cursor = nil
            self.crafting = CraftingGrid()
            self.craftingWidth = 2
            self.containerPositions = []
            self.currentContainer = nil
            self.containerLabels = []
            self.containerTitle = ""
            self.furnaceOpen = false
            self.entitySimulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
            self.maps = BetaMapCollection()
            self.world = BlockWorld()
            self.inventory = PlayerInventory()
            self.player = Player(position: SIMD3(0, 100, 0))
            self.player.localDamageEnabled = false
            self.camera.setPosition(self.player.eyePosition)
            self.particleEvents.removeAll()
            self.chatLines.removeAll()
            self.audio.setPaused(true)
            self.multiplayerStatus = "Connecting to \(host):\(port)…"
            self.statusText = self.multiplayerStatus
            let client = MultiplayerClient(
                onPacket: { [weak self] packet in
                    guard let self, self.sessionGeneration == generation, self.isMultiplayer else { return }
                    self.receiveMultiplayer(packet)
                },
                onDisconnect: { [weak self] reason in
                    guard let self, self.sessionGeneration == generation, self.isMultiplayer else { return }
                    self.endMultiplayer(reason: reason)
                })
            state.client = client
            client.connect(host: host, port: port, username: username)
        }
    }

    func disconnectMultiplayer() { endMultiplayer(reason: "Disconnected") }

    func endMultiplayer(reason: String) {
        streamingTask?.cancel()
        sessionGeneration &+= 1
        connectionPending = false
        guard let state = multiplayer else {
            multiplayerStatus = reason
            return
        }
        multiplayer = nil
        state.client?.disconnect()
        let saved = state.singleplayer
        worldName = saved.worldName
        worldMenuOpen = saved.worldMenuOpen
        world = saved.world
        worldTime = saved.worldTime
        player = saved.player
        inventory = saved.inventory
        camera = saved.camera
        bedSpawn = saved.bedSpawn
        sleepingBed = nil
        spawn = saved.spawn
        blockSimulation = saved.blockSimulation
        entitySimulation = saved.entitySimulation
        itemActions = saved.itemActions
        maps = saved.maps
        weather = saved.weather
        lastStreamCenter = saved.center
        rainStrength = weather.rainStrength
        thunderStrength = weather.weightedThunderStrength
        isMultiplayer = false
        isLoading = false
        isPaused = true
        inventoryOpen = false
        chatOpen = false
        signEditorOpen = false
        furnaceOpen = false
        containerTitle = ""
        containerLabels = []
        containerPositions = []
        currentContainer = nil
        cursor = nil
        crafting = CraftingGrid()
        craftingWidth = 2
        streaming = false
        relighting = false
        evictionInProgress = false
        particleEvents.removeAll()
        sleepTicks = 0
        accumulator = 0
        litRevision = world.lightingRevision
        multiplayerStatus = reason
        statusText = reason
        resetInput()
        audio.setPaused(true)
        updateTarget()
        refreshHUD()
    }

    func receiveMultiplayer(_ packet: BetaPacket) {
        guard let state = multiplayer else { return }
        switch packet {
        case .login(let id, _, let seed, let dimension):
            state.localEntityID = id
            world = BlockWorld(seed: seed, dimension: dimension)
            entitySimulation = EntitySimulation(seed: seed, naturalSpawningEnabled: false)
            multiplayerStatus = "Loading server terrain…"
            statusText = multiplayerStatus
        case .spawnPosition(let position): spawn = position
        case .time(let time): worldTime = time
        case .health(let value):
            player.setHealthFromServer(Int(value))
            if value <= 0 {
                resetInput()
                isPaused = true
                statusText = "You died"
            }
            refreshHUD()
        case .respawn(let dimension):
            if world.dimension != dimension {
                world = BlockWorld(seed: world.seed, dimension: dimension)
                entitySimulation = EntitySimulation(seed: world.seed, naturalSpawningEnabled: false)
                state.fixedPositions.removeAll()
                state.loadedChunks.removeAll()
            }
            player = Player(position: player.position)
            player.localDamageEnabled = false
            state.receivedPosition = false
            state.respawnRequested = false
            state.vehicleID = nil
            isLoading = true
            isPaused = false
            inventoryOpen = false
            sleepTicks = 0
            closeMultiplayerWindow(send: false)
        case .playerPositionLook(let x, let eyeY, let feetY, let z, let yaw, let pitch, let grounded):
            guard [x, eyeY, feetY, z, Double(yaw), Double(pitch)].allSatisfy(\.isFinite),
                abs(x) < 32_000_000, abs(z) < 32_000_000, abs(feetY) < 1_000_000
            else {
                endMultiplayer(reason: "The server sent an invalid player position.")
                return
            }
            player.teleport(to: SIMD3(x, feetY, z))
            camera = Camera(
                position: player.eyePosition, yaw: yaw * Float(Double.pi) / 180 + Float(Double.pi),
                pitch: -pitch * Float(Double.pi) / 180)
            state.receivedPosition = true
            state.lastPosition = player.position
            state.lastYaw = camera.yaw
            state.lastPitch = camera.pitch
            state.client?.send(
                .playerPositionLook(
                    x: x, y: feetY, stance: eyeY, z: z, yaw: yaw, pitch: pitch, onGround: grounded))
            finishMultiplayerLoading()
        case .preChunk(let x, let z, let load):
            let position = ChunkPosition(Int(x), Int(z))
            if load {
                if world.chunks[position] == nil {
                    world.setChunk(Chunk(position: position), updateLighting: false)
                }
            } else {
                world.removeChunk(at: position)
                state.loadedChunks.remove(position)
            }
        case .mapChunk(let chunk):
            chunk.apply(to: &world)
            for x in (Int(chunk.x) >> 4)...((Int(chunk.x) + chunk.sizeX - 1) >> 4) {
                for z in (Int(chunk.z) >> 4)...((Int(chunk.z) + chunk.sizeZ - 1) >> 4) {
                    state.loadedChunks.insert(ChunkPosition(x, z))
                }
            }
            finishMultiplayerLoading()
        case .blockChange(let position, let id, let data):
            applyMultiplayerBlock(id: id, metadata: data, at: position)
            if state.pendingSign == position, id == 63 || id == 68 {
                state.pendingSign = nil
                beginSignEditing(at: position)
            }
        case .multiBlockChange(let x, let z, let changes):
            for change in changes {
                applyMultiplayerBlock(
                    id: change.id, metadata: change.metadata,
                    at: BlockPosition(Int(x) * 16 + change.x, change.y, Int(z) * 16 + change.z))
            }
        case .blockAction(let position, let instrument, let pitch):
            if world[position] == .piston || world[position] == .stickyPiston {
                dispatch(
                    blockSimulation.applyPistonAction(
                        at: position, event: instrument, parameter: pitch, world: &world, time: worldTime))
            } else if world[position] == .noteBlock {
                let sounds = ["note.harp", "note.bd", "note.snare", "note.hat", "note.bassattack"]
                if Int(instrument) < sounds.count {
                    play(
                        sounds[Int(instrument)], at: position.vector, volume: 3,
                        pitch: pow(2, (Float(pitch) - 12) / 12))
                }
            }
        case .explosion(let position, let power, let blocks):
            guard [position.x, position.y, position.z].allSatisfy(\.isFinite),
                abs(position.x) < 32_000_000, abs(position.y) < 1_000_000, abs(position.z) < 32_000_000
            else { return }
            for offset in blocks {
                world.setBlock(
                    nil,
                    at: BlockPosition(
                        Int(position.x) + Int(offset.x), Int(position.y) + Int(offset.y),
                        Int(position.z) + Int(offset.z)))
            }
            enqueueParticle(.explosion(position: position, power: power))
            play(
                "random.explode", at: SIMD3<Float>(position), volume: 4,
                pitch: 0.7 * Float.random(in: 0.8...1.2))
        case .gameState(let reason):
            if reason == 1 {
                state.raining = true
            } else if reason == 2 {
                state.raining = false
            } else if reason == 0 {
                statusText = "You can only sleep at night"
            }
        case .chat(let text):
            chatLines.append(text)
            if chatLines.count > 50 { chatLines.removeFirst(chatLines.count - 50) }
        case .updateSign(let position, let lines):
            world.setBlockEntity(.sign(lines: lines), at: position)
        case .disconnect(let reason): endMultiplayer(reason: reason)
        default:
            if !receiveMultiplayerInventory(packet) { receiveMultiplayerEntity(packet) }
        }
    }

    func applyMultiplayerBlock(id: UInt8, metadata: UInt8, at position: BlockPosition) {
        if multiplayer?.awaitingDig == position { multiplayer?.awaitingDig = nil }
        let state = id == 0 ? nil : BlockKind(rawValue: id).map { BlockState($0, metadata: metadata) }
        world.setBlock(state, at: position)
        if let state, let entity = BlockEntity.initial(for: state.kind),
            world.blockEntity(at: position) == nil
        {
            world.setBlockEntity(entity, at: position)
        }
    }

    func finishMultiplayerLoading() {
        guard let state = multiplayer, state.receivedPosition,
            state.loadedChunks.contains(
                ChunkPosition(Int(floor(player.position.x)) >> 4, Int(floor(player.position.z)) >> 4))
        else { return }
        if isLoading {
            isLoading = false
            isPaused = false
            multiplayerStatus = "Connected to Beta 1.7.3 server"
            statusText = ""
            accumulator = 0
            audio.setPaused(false)
            updateTarget()
            refreshHUD()
        }
    }

    func tickMultiplayer() {
        guard let state = multiplayer else { return }
        let active = !inventoryOpen && !isPaused && !chatOpen && !signEditorOpen && sleepTicks == 0
        let forward = active ? axis(.forward, .backward) + touchMovement.y : 0
        let strafe = active ? axis(.right, .left) + touchMovement.x : 0
        entitySimulation.tickRemote()
        dispatch(blockSimulation.tickAnimations(world: &world, time: worldTime, notifyNeighbors: false))
        if let vehicleID = state.vehicleID, let vehicle = entities.first(where: { $0.id == vehicleID }) {
            player.teleport(to: vehicle.position + SIMD3(0, vehicle.height * 0.75, 0))
            let x = Double(sin(camera.yaw) * forward + cos(camera.yaw) * strafe) * 0.02
            let z = Double(-cos(camera.yaw) * forward + sin(camera.yaw) * strafe) * 0.02
            state.client?.send(
                .playerPositionLook(
                    x: x, y: -999, stance: -999, z: z,
                    yaw: camera.yaw * 180 / Float(Double.pi) - 180,
                    pitch: -camera.pitch * 180 / Float(Double.pi),
                    onGround: player.onGround))
        } else {
            let center = ChunkPosition(Int(floor(player.position.x)) >> 4, Int(floor(player.position.z)) >> 4)
            if state.loadedChunks.contains(center) {
                player.tick(
                    input: PlayerInput(
                        forward: forward, strafe: strafe,
                        jump: active && pressed.contains(.jump), sneak: active && pressed.contains(.sneak)),
                    yaw: camera.yaw, world: world)
            }
            sendMultiplayerMovement()
        }
        for case .stepped(let position, let source) in player.drainStepEvents() {
            let below = BlockPosition(position.x, position.y - 1, position.z)
            let above = BlockPosition(position.x, position.y + 1, position.z)
            if let kind = world[below] == .fence ? .fence : world[position] {
                let soundKind = world[above] == .snowLayer ? .snowLayer : kind
                if !kind.isLiquid || soundKind == .snowLayer {
                    dispatch([BlockSounds.step(for: soundKind, at: source ?? center(of: position))])
                }
            }
        }
        camera.setPosition(player.eyePosition)
        if achievementNoticeTicks > 0 { achievementNoticeTicks -= 1 } else { achievementNotice = nil }
        worldTime += 1
        tickCount += 1
        tickItemState()
        updateTarget()
        advanceMultiplayerMining()
        rainStrength =
            world.dimension == -1 ? 0 : min(1, max(0, rainStrength + (state.raining ? 0.01 : -0.01)))
        thunderStrength = 0
    }

    func sendMultiplayerMovement() {
        guard let state = multiplayer else { return }
        let position = player.position
        let moved = state.lastPosition != position
        let looked = state.lastYaw != camera.yaw || state.lastPitch != camera.pitch
        let yaw = camera.yaw * 180 / Float(Double.pi) - 180
        let pitch = -camera.pitch * 180 / Float(Double.pi)
        if moved && looked {
            state.client?.send(
                .playerPositionLook(
                    x: position.x, y: position.y, stance: player.eyePositionDouble.y,
                    z: position.z, yaw: yaw, pitch: pitch, onGround: player.onGround))
        } else if moved {
            state.client?.send(
                .playerPosition(
                    x: position.x, y: position.y, stance: player.eyePositionDouble.y, z: position.z,
                    onGround: player.onGround))
        } else if looked {
            state.client?.send(.playerLook(yaw: yaw, pitch: pitch, onGround: player.onGround))
        } else {
            state.client?.send(.grounded(player.onGround))
        }
        let sneaking = pressed.contains(.sneak) && !inventoryOpen && !isPaused
        if sneaking != state.wasSneaking {
            state.client?.send(.entityAction(entityID: state.localEntityID, action: sneaking ? 1 : 2))
            state.wasSneaking = sneaking
        }
        state.lastPosition = position
        state.lastYaw = camera.yaw
        state.lastPitch = camera.pitch
    }

    func respawnMultiplayer() {
        guard let state = multiplayer, !state.respawnRequested else { return }
        state.respawnRequested = true
        state.client?.send(.respawn(world.dimension))
        isPaused = false
        statusText = "Respawning…"
    }
}
