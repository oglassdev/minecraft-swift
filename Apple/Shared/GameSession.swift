import Combine
import Foundation
import MinecraftCore

@MainActor
final class GameSession: ObservableObject {
    enum Action { case forward, backward, left, right, up, down, fast, jump, sneak }

    @Published var worldMenuOpen = false
    @Published var hideHUD = false
    @Published var thirdPerson = false
    @Published var smoothCamera = false
    @Published var fps = 0
    @Published var texturePacks: [TexturePackDescriptor] = [.defaultPack]
    @Published var texturePackURL: URL?
    @Published var texturePackRevision: UInt64 = 0
    @Published var hotbarPickupTicks = Array(repeating: 0, count: 9)
    var recordedDamageTaken = 0
    var textureSelectionGeneration: UInt64 = 0
    @Published var showDebug = false
    @Published var showDeathScreen = false
    var deathScreenTicks = 0
    var playerScore = 0
    @Published var availableWorlds: [WorldDescriptor] = []
    @Published var options = GameOptions()
    @Published var statistics = PlayerStatistics()
    @Published var achievementNotice: String?
    var achievementNoticeTicks = 0
    var statisticsFallDistance: Float = 0
    var worldTransitionPending = false
    var hasLoadedWorld = false
    let gameDirectory: URL
    var worldDirectory: URL
    @Published var errorMessage: String?
    @Published var isLoading = true
    @Published var loadingProgress: Double?
    @Published var inventoryOpen = false
    @Published var isPaused = false
    @Published var health = 20
    @Published var selectedHotbar = 0
    @Published var craftingWidth = 2
    @Published var furnaceOpen = false
    @Published var furnaceProgress: Double = 0
    @Published var containerTitle = ""

    @Published var inventoryItems: [ItemStack?] = Array(repeating: nil, count: 36)
    @Published var armorItems: [ItemStack?] = Array(repeating: nil, count: 4)
    @Published var containerItems: [ItemStack?] = []
    @Published var craftingItems: [ItemStack?] = Array(repeating: nil, count: 4)
    @Published var craftingResultItem: ItemStack?
    @Published var furnaceItems: [ItemStack?] = Array(repeating: nil, count: 3)
    var world = BlockWorld()
    var worldName = "World"
    var worldTime: Int64 = 0
    var selectedBlock: BlockHit?
    var entities: [GameEntity] { entitySimulation.entities }
    var camera = Camera()
    var pressed: Set<Action> = []
    var touchMovement = SIMD2<Float>.zero
    @Published var isMultiplayer = false
    @Published var chatOpen = false
    @Published var chatLines: [String] = []
    @Published var chatRevision: UInt64 = 0
    @Published var signEditorOpen = false
    @Published var signLines = ["", "", "", ""]
    var rainStrength: Float = 0
    var thunderStrength: Float = 0
    var renderPartialTick: Float { min(1, max(0, accumulator / 0.05)) }
    var cameraPositionDouble: SIMD3<Double> { player.interpolatedEyePosition(partialTick: renderPartialTick) }
    var cursorItem: ItemStack? { cursor }
    var armorPoints: Int { inventory.armorProtection }
    var air: Int { player.air }
    var isUnderwater: Bool { player.isEyeUnderwater(in: world) }
    var previousHealth: Int { player.previousHealth }
    var hurtTime: Int { player.hurtTime }
    var healthFlashTime: Int { player.healthFlashTime }
    var portalTime: Float = 0
    var previousPortalTime: Float = 0
    var furnaceBurnProgress: Double {
        guard let position = currentContainer, case .furnace(let furnace) = world.blockEntity(at: position)
        else { return 0 }
        return Double(furnace.burnTicksRemaining)
            / Double(max(1, furnace.currentFuelBurnTicks == 0 ? 200 : furnace.currentFuelBurnTicks))
    }
    var heldItem: ItemStack? { inventory.selectedStack }
    var isMining: Bool { miningPressed && miningTarget != nil && miningProgress > 0 }
    var sessionGeneration: UInt64 = 0
    var multiplayer: MultiplayerState?
    var connectionPending = false
    var particleEvents: [BlockEvent] = []
    var weather = WorldWeather(seed: 0)
    var worldTickState = WorldTickState(randomSeed: 0, coordinateSeed: 0)
    var itemActions = ItemActions(seed: 0)
    var maps = BetaMapCollection()
    var compassDial = ItemDialState()
    var clockDial = ItemDialState()
    var dialRandom = JavaRandom(seed: 0)
    var heldMap: BetaMapData? { heldItem?.id == 358 ? maps[Int16(bitPattern: heldItem!.damage)] : nil }
    var compassAngle: Double { compassDial.angle }
    var clockAngle: Double { clockDial.angle }
    var signPosition: BlockPosition?
    var portalTicks = 0
    var portalCooldown = 0
    var evictionInProgress = false

    var player = Player(position: SIMD3(8.5, 100, 8.5))
    var inventory = PlayerInventory()
    var crafting = CraftingGrid()
    var cursor: ItemStack?
    var spawn = BlockPosition(8, 100, 8)
    var bedSpawn: BlockPosition?
    var sleepingBed: BlockPosition?
    var blockSimulation = BlockSimulation(seed: 0)
    var entitySimulation = EntitySimulation(seed: 0)
    let audio = AudioManager()
    var service: WorldService
    var gameTimer = BetaTimer()
    var accumulator: Float {
        get { gameTimer.partialTick / 20 }
        set { gameTimer.partialTick = min(1, max(0, newValue * 20)) }
    }
    var mouseDelta = SIMD2<Float>.zero
    var mouseFilterX = BetaMouseFilter()
    var mouseFilterY = BetaMouseFilter()
    var lastPrimaryTick = 0
    var lastSecondaryTick = 0
    var secondaryPressed = false
    var statusElapsed: Float = 0
    var menuAudioElapsed: Float = 0
    var miningTarget: BlockPosition?
    var miningProgress: Float = 0
    var miningSoundTicks = 0
    var miningPressed = false
    var blockHitDelay = 0
    var flight = false
    var currentContainerEntity: Int64?
    var currentContainer: BlockPosition?
    var containerPositions: [BlockPosition] = []
    var sleepTicks = 0
    var streamingTask: Task<Void, Never>?
    var streamedRadius = 3
    var streaming = false
    var lastStreamCenter: ChunkPosition?
    var litRevision: UInt64 = 0
    var relighting = false
    @Published var tickCount = 0

    init(directory: URL? = nil, loadAutomatically: Bool = true, supportDirectory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        gameDirectory = supportDirectory ?? base.appendingPathComponent("MinecraftSwift")
        worldDirectory = directory ?? gameDirectory.appendingPathComponent("saves/World1")
        service = WorldService(directory: worldDirectory)
        options =
            (try? GameOptions.load(from: gameDirectory.appendingPathComponent("options.txt")))
            ?? GameOptions()
        statistics =
            (try? StatisticsStorage(directory: gameDirectory.appendingPathComponent("stats")).load())
            ?? PlayerStatistics()
        applyOptions()
        refreshTexturePacks()
        if let selected = texturePacks.first(where: { $0.name == options.skin }) {
            selectTexturePack(selected, persist: false)
        }
        if loadAutomatically {
            if directory != nil {
                Task { await loadWorld() }
            } else {
                isLoading = false
                isPaused = true
                worldMenuOpen = true
                refreshWorldList()
            }
        }
    }

    func update(deltaTime: Float) {
        guard !isLoading, !worldMenuOpen else {
            tickMenuAudio(deltaTime)
            return
        }
        audio.update(listener: camera.position, forward: camera.forward)
        guard !isPaused || isMultiplayer else {
            return
        }
        processMouseLook()
        let ticks = gameTimer.advance(seconds: Double(deltaTime))
        for _ in 0..<ticks {
            guard !isLoading else { break }
            tick()
        }
        updateTarget()
        statusElapsed += deltaTime
        if statusElapsed >= 0.15 {
            refreshHUD()
            statusElapsed = 0
        }
    }

    /// Beta's music scheduler runs every client tick, including on the title screen and while loading.
    private func tickMenuAudio(_ deltaTime: Float) {
        menuAudioElapsed += min(deltaTime, 0.25)
        while menuAudioElapsed >= 0.05 {
            menuAudioElapsed -= 0.05
            audio.tick()
        }
    }

    func syncAudioPause() { audio.setPaused(isPaused && !isMultiplayer && !worldMenuOpen) }

    func tick() {
        if isMultiplayer {
            tickMultiplayer()
            return
        }
        tickCount += 1
        if hotbarPickupTicks.contains(where: { $0 > 0 }) {
            hotbarPickupTicks = hotbarPickupTicks.map { max(0, $0 - 1) }
        }
        if miningPressed && tickCount - lastPrimaryTick >= 5 {
            miningPressed = false
            primaryAction(isPressed: true)
        }
        if secondaryPressed && tickCount - lastSecondaryTick >= 5 {
            secondaryAction()
            lastSecondaryTick = tickCount
        }
        updateTarget()
        advanceMining()
        let previous = player.position
        let healthBefore = player.health
        let inventoryBefore = inventory
        let groundedBefore = player.onGround
        let inputEnabled =
            !inventoryOpen && !chatOpen && !signEditorOpen && !showDeathScreen && sleepTicks == 0
        let forward = inputEnabled ? axis(.forward, .backward) + touchMovement.y : 0
        let strafe = inputEnabled ? axis(.right, .left) + touchMovement.x : 0
        entitySimulation.setRidingInput(forward: forward, strafe: strafe)
        if flight {
            camera.move(
                MovementInput(
                    forward: forward, right: strafe,
                    up: inputEnabled ? axis(.up, .down) : 0, fast: pressed.contains(.fast)), deltaTime: 0.05)
            player.teleport(to: SIMD3<Double>(camera.position) - SIMD3(0, 1.62, 0))
        } else {
            player.tick(
                input: PlayerInput(
                    forward: forward, strafe: strafe,
                    jump: inputEnabled && pressed.contains(.jump),
                    sneak: inputEnabled && pressed.contains(.sneak)),
                yaw: camera.yaw, world: world, inventory: &inventory,
                entityCollisions: entitySimulation.collisionBoxes(
                    intersecting: player.bounds.expanded(by: SIMD3(repeating: 1))))
            camera.setPosition(player.eyePosition)
        }
        dispatch(player.drainStepEvents())
        let beforePickup = inventory.slots
        dispatch(
            entitySimulation.tick(world: &world, player: &player, inventory: &inventory, time: worldTime))
        animateHotbarPickups(previous: beforePickup)
        dispatch(player.drainStepEvents())
        dispatch(
            blockSimulation.withWorldRandom(&worldTickState.random) {
                $0.tickBlockEntities(
                    world: &world, players: [player.position], entities: entities, time: worldTime)
            })
        audio.tick()
        weather.advanceTimers(dimension: world.dimension, random: &worldTickState.random)
        entitySimulation.spawnNaturally(
            in: world, near: player, time: worldTime, worldRandom: &worldTickState.random)
        worldTime += 1
        tickItemState()
        if sleepTicks > 0 {
            resetInput()
            if player.health < healthBefore || sleepingBed.map({ world[$0] != .bed }) != false {
                wakeFromBed(setSpawn: false)
            } else {
                sleepTicks += 1
                if sleepTicks >= 100 {
                    worldTime += 24000 - worldTime % 24000
                    weather.stopPrecipitation()
                    wakeFromBed(setSpawn: true)
                }
            }
        }
        updateTarget()
        dispatch(
            blockSimulation.tick(
                world: &world, players: [player.position], time: worldTime,
                entities: entitySimulation.entities, weather: &weather, tickState: &worldTickState,
                includeBlockEntities: false))
        if sleepTicks > 0 && player.health < healthBefore { wakeFromBed(setSpawn: false) }
        rainStrength = weather.rainStrength
        thunderStrength = weather.weightedThunderStrength
        recordStatisticsTick(
            previous: previous, healthBefore: healthBefore, inventoryBefore: inventoryBefore,
            groundedBefore: groundedBefore)
        if player.health == 0 {
            if !showDeathScreen {
                statistics.recordDeath()
                for stack in (inventory.slots + inventory.armor).compactMap({ $0 }) {
                    dropFromPlayer(stack, scatter: true)
                }
                inventory = PlayerInventory()
                returnCursorAndCrafting()
                inventoryOpen = false
                showDeathScreen = true
                resetInput()
            }
            deathScreenTicks += 1
        }
        updatePortalContact()
        guard !isLoading else { return }
        let center = chunkPosition(of: player.position)
        if (center != lastStreamCenter || streamedRadius < desiredChunkRadius) && !streaming {
            extendWorld(around: center)
        }
        if world.lightingRevision != litRevision && !relighting { relightWorld() }
        if tickCount % 600 == 0 { saveWorld() }
    }

    func axis(_ positive: Action, _ negative: Action) -> Float {
        (pressed.contains(positive) ? 1 : 0) - (pressed.contains(negative) ? 1 : 0)
    }

    func updateTarget() {
        selectedBlock = BlockRaycast.hit(
            in: world, origin: player.eyePositionDouble,
            direction: SIMD3<Double>(camera.forward), reach: 5)
    }

    func primaryAction(isPressed: Bool) {
        if isMultiplayer {
            multiplayerPrimaryAction(isPressed: isPressed)
            return
        }
        if isPressed && !miningPressed && !inventoryOpen && !isPaused && player.health > 0 {
            player.swing()
            lastPrimaryTick = tickCount
            let damage = inventory.selectedStack?.definition?.attackDamage ?? 1
            let target = entitySimulation.target(
                origin: player.eyePositionDouble, direction: SIMD3<Double>(camera.forward), reach: 4,
                world: world)
            if entitySimulation.attack(
                origin: player.eyePositionDouble, direction: SIMD3<Double>(camera.forward),
                reach: min(selectedBlock?.distance ?? 4, 4), damage: damage, world: world)
            {
                let held = inventory.selectedStack
                let cost = target?.isLiving == true ? BlockMining.durabilityCostHittingEntity(with: held) : 0
                if let held, cost > 0 {
                    notifyAchievements(statistics.recordUse(itemID: held.id))
                    inventory.damageSelected(by: cost)
                    if inventory.selectedStack == nil {
                        notifyAchievements(statistics.recordBreak(itemID: held.id))
                    }
                }
                if let target, let current = entities.first(where: { $0.id == target.id }) {
                    statistics.recordDamageDealt(max(0, target.health - current.health))
                    if target.isLiving && target.health > 0 && current.health <= 0 {
                        notifyAchievements(statistics.recordKill(kind: target.kind))
                    }
                }
                refreshHUD()
            }
        }
        miningPressed = isPressed
        if !isPressed {
            miningTarget = nil
            miningProgress = 0
        }
    }

    func advanceMining() {
        if isMultiplayer {
            advanceMultiplayerMining()
            return
        }
        if blockHitDelay > 0 {
            blockHitDelay -= 1
            return
        }
        guard miningPressed, let hit = selectedBlock, let state = world.state(at: hit.position) else {
            miningTarget = nil
            miningProgress = 0
            return
        }
        if miningTarget != hit.position {
            miningTarget = hit.position
            miningProgress = 0
            miningSoundTicks = 0
            let attacked = blockSimulation.withWorldRandom(&worldTickState.random) {
                $0.attack(
                    hit: hit, holding: inventory.selectedStack, health: player.health, world: &world,
                    time: worldTime)
            }
            if attacked.healthRestored > 0 { player.heal(attacked.healthRestored) }
            dispatch(attacked.events)
        }
        miningProgress += BlockMining.progressPerTick(
            for: state.kind, with: inventory.selectedStack,
            underwater: player.isInWater, onGround: player.onGround)
        if miningSoundTicks % 4 == 0 {
            dispatch([BlockSounds.hit(for: state.kind, at: center(of: hit.position))])
        }
        miningSoundTicks += 1
        guard miningProgress >= 1 else { return }
        let tool = inventory.selectedStack
        if BlockMining.canHarvest(state.kind, with: tool) {
            notifyAchievements(statistics.recordMine(state.kind))
        }
        if let entity = world.blockEntity(at: hit.position) {
            dispatch(blockSimulation.containerDrops(entity, at: hit.position, kind: state.kind))
        }
        if state.kind == .jukebox { audio.playRecord(nil) }
        world.setBlock(nil, at: hit.position)
        _ = BlockInteractions.didRemove(state, at: hit.position, world: &world)
        enqueueParticle(
            .particle(
                name: "tilecrack_\(state.kind.rawValue)_\(state.metadata)", position: center(of: hit.position)
            ))
        dispatch(BlockInteractions.didBreak(state, at: hit.position, holding: tool, world: &world))
        let durabilityCost = BlockMining.durabilityCost(on: state.kind, with: tool)
        inventory.damageSelected(by: durabilityCost)
        if let tool {
            if BlockMining.recordsUseWhenMining(with: tool) {
                notifyAchievements(statistics.recordUse(itemID: tool.id))
            }
            if inventory.selectedStack == nil { notifyAchievements(statistics.recordBreak(itemID: tool.id)) }
        }
        notifyBlockChanged(at: hit.position, previousState: state)
        dispatch(BlockDrops.harvest(state, at: hit.position, with: tool, random: &worldTickState.random))
        dispatch([BlockSounds.breaking(for: state.kind, at: center(of: hit.position))])
        miningProgress = 0
        miningTarget = nil
        blockHitDelay = 5
        refreshHUD()
    }

    func secondaryAction() {
        if isMultiplayer {
            multiplayerSecondaryAction()
            return
        }
        guard !isLoading && !isPaused && !inventoryOpen && player.health > 0 else { return }
        let usedItem = inventory.selectedStack
        switch entitySimulation.interactResult(
            origin: player.eyePositionDouble, direction: SIMD3<Double>(camera.forward),
            reach: min(selectedBlock?.distance ?? 4, 4), player: &player, inventory: &inventory, world: world)
        {
        case .used:
            player.swing()
            refreshHUD()
            return
        case .container(let id):
            currentContainerEntity = id
            currentContainer = nil
            containerPositions = []
            containerTitle = "Minecart"
            furnaceOpen = false
            inventoryOpen = true
            resetInput()
            refreshHUD()
            return
        case .unhandled: break
        }
        guard let hit = selectedBlock else {
            applyItemAction(
                itemActions.useInAir(
                    world: &world, player: &player, inventory: &inventory,
                    entities: &entitySimulation, yaw: camera.yaw, pitch: camera.pitch,
                    random: &worldTickState.random), itemID: usedItem?.id)
            refreshHUD()
            return
        }
        let oldRecord: UInt16?
        if case .jukebox(let record) = world.blockEntity(at: hit.position) {
            oldRecord = record
        } else {
            oldRecord = nil
        }
        let placingSign = inventory.selectedStack?.id == 323
        let result = itemActions.interactWithBlock(
            hit: hit, holding: inventory.selectedStack, yaw: camera.yaw,
            playerBounds: player.bounds, world: &world, health: player.health,
            placementBlockers: entities.filter(\.preventsBlockSpawning).map(\.bounds),
            random: &worldTickState.random)
        if result.replaceHeldStack {
            inventory.slots[inventory.selectedHotbar] = result.replacement
        } else if result.consumed > 0 {
            _ = inventory.removeSelected(count: result.consumed)
        }
        inventory.damageSelected(by: result.durabilityDamage)
        if result.healthRestored > 0 { player.heal(result.healthRestored) }
        for position in result.changedPositions {
            notifyBlockChanged(at: position)
        }
        dispatch(result.events)
        if result.handled && result.itemUsed, let id = usedItem?.id {
            notifyAchievements(statistics.recordUse(itemID: id))
        }
        if let previous = usedItem, previous.definition?.maximumDurability ?? 0 > 0,
            inventory.selectedStack == nil
        {
            notifyAchievements(statistics.recordBreak(itemID: previous.id))
        }
        if oldRecord != nil, case .jukebox(let record) = world.blockEntity(at: hit.position), record == nil {
            audio.playRecord(nil)
        }
        if !result.handled {
            let onBlock = itemActions.useOnBlock(
                hit: hit, world: &world, player: &player, inventory: &inventory,
                entities: &entitySimulation, yaw: camera.yaw, pitch: camera.pitch)
            applyItemAction(onBlock, itemID: usedItem?.id, countUse: true)
            if !onBlock.handled {
                applyItemAction(
                    itemActions.useInAir(
                        world: &world, player: &player, inventory: &inventory,
                        entities: &entitySimulation, yaw: camera.yaw, pitch: camera.pitch,
                        random: &worldTickState.random),
                    itemID: usedItem?.id)
            }
        }
        if let position = result.openContainer, !placingSign { openContainer(at: position) }
        if placingSign,
            let position = result.changedPositions.first(where: {
                world[$0] == .standingSign || world[$0] == .wallSign
            })
        {
            beginSignEditing(at: position)
        }
        if result.handled { player.swing() }
        if let bed = result.sleepAt { beginSleeping(at: bed) }
        refreshHUD()
    }

    func openContainer(at position: BlockPosition) {
        currentContainerEntity = nil
        currentContainer = position
        containerPositions = []
        furnaceOpen = false
        if world[position] == .craftingTable {
            resizeCrafting(to: 3)
        } else if case .furnace = world.blockEntity(at: position) {
            furnaceOpen = true
        } else if case .chest = world.blockEntity(at: position) {
            containerPositions = [position]
            for offset in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let neighbor = BlockPosition(position.x + offset.0, position.y, position.z + offset.1)
                if case .chest = world.blockEntity(at: neighbor) {
                    containerPositions.append(neighbor)
                    break
                }
            }
            containerPositions.sort { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }
            containerTitle = containerPositions.count == 2 ? "Large chest" : "Chest"
        } else if case .dispenser = world.blockEntity(at: position) {
            containerPositions = [position]
            containerTitle = "Dispenser"
        }
        inventoryOpen = true
        resetInput()
        refreshHUD()
    }

    func selectHotbar(_ slot: Int) {
        guard (0..<9).contains(slot) else { return }
        if isMultiplayer { stopMultiplayerMining() }
        inventory.selectedHotbar = slot
        if isMultiplayer { multiplayer?.client?.send(.heldItem(Int16(slot))) }
        miningTarget = nil
        miningProgress = 0
        refreshHUD()
    }

    func cycleHotbar(_ direction: Int) { selectHotbar((inventory.selectedHotbar - direction % 9 + 9) % 9) }

    func toggleInventory() {
        guard !showDeathScreen else { return }
        if isMultiplayer {
            toggleMultiplayerInventory()
            return
        }
        if inventoryOpen {
            returnCursorAndCrafting()
            currentContainer = nil
            currentContainerEntity = nil
            containerPositions = []
            containerTitle = ""
            furnaceOpen = false
            resizeCrafting(to: 2)
        }
        inventoryOpen.toggle()
        if inventoryOpen { notifyAchievements(statistics.recordInventoryOpen()) }
        resetInput()
        syncAudioPause()
        refreshHUD()
    }

    func togglePause() {
        guard !showDeathScreen else { return }
        if !isMultiplayer && sleepTicks > 0 { wakeFromBed(setSpawn: false) }
        isPaused.toggle()
        resetInput()
        syncAudioPause()
    }

    func toggleFlight() {
        guard !isMultiplayer else { return }
        flight.toggle()
        player.teleport(to: SIMD3<Double>(camera.position) - SIMD3(0, 1.62, 0))
    }

    func dispatch(_ events: [BlockEvent]) {
        for event in events {
            switch event {
            case .dropItem(let position, let stack):
                if !isMultiplayer { entitySimulation.drop(stack, at: position) }
            case .fishCaught: statistics.recordFishCaught()
            case .pigFall(let distance): notifyAchievements(statistics.recordPigFall(distance: distance))
            case .dropItemMoving(let position, let stack, let velocity):
                if !isMultiplayer { entitySimulation.drop(stack, at: position, velocity: velocity) }
            case .stepped(let position, let source):
                if !isMultiplayer {
                    let events = blockSimulation.withWorldRandom(&worldTickState.random) {
                        $0.stepped(at: position, world: &world, time: worldTime, position: source)
                    }
                    dispatch(events)
                }
            case .sound(let name, let position, let volume, let pitch):
                play(name, at: SIMD3<Float>(position), volume: volume, pitch: pitch)
            case .spawnEntity(let kind, let position):
                if !isMultiplayer { entitySimulation.spawn(kind: kind, position: position) }
            case .projectile(let kind, let position, let velocity):
                if !isMultiplayer {
                    entitySimulation.spawn(kind: kind, position: position, velocity: velocity)
                }
            case .explosion(let position, let power):
                enqueueParticle(event)
                guard !isMultiplayer else { continue }
                let aftermath = entitySimulation.explode(
                    at: position, power: power, world: &world, player: &player, inventory: &inventory,
                    worldRandom: &worldTickState.random)
                dispatch(aftermath)
            case .particle: enqueueParticle(event)
            case .displace(let bounds, let delta):
                entitySimulation.displaceEntities(in: bounds, by: delta, world: world)
                if player.bounds.intersects(bounds) {
                    player.displace(by: delta, world: world)
                    camera.setPosition(player.eyePosition)
                }
            }
        }
    }

    func play(_ name: String, at position: SIMD3<Float>? = nil, volume: Float = 1, pitch: Float = 1) {
        if name.hasPrefix("records.") {
            audio.playRecord(String(name.dropFirst(8)), at: position)
            return
        }
        audio.play(event: name, at: position, listener: camera.position, volume: volume, pitch: pitch)
    }

    func stepSound(_ kind: BlockKind) -> String {
        switch kind {
        case .grass, .leaves: "step.grass"
        case .dirt, .gravel: "step.gravel"
        case .sand, .soulSand: "step.sand"
        case .wood, .planks, .woodenStairs, .craftingTable, .chest: "step.wood"
        case .wool: "step.cloth"
        case .snow, .snowLayer: "step.snow"
        default: "step.stone"
        }
    }

    func center(of position: BlockPosition) -> SIMD3<Double> {
        SIMD3(Double(position.x) + 0.5, Double(position.y) + 0.5, Double(position.z) + 0.5)
    }

    func refreshHUD() {
        health = player.health
        selectedHotbar = inventory.selectedHotbar
        inventoryItems = inventory.slots
        armorItems = Array(inventory.armor.reversed())
        if let id = currentContainerEntity {
            containerItems = entities.first(where: { $0.id == id })?.contents ?? []
        } else {
            containerItems = containerPositions.flatMap { world.blockEntity(at: $0)?.contents ?? [] }
        }
        craftingItems = crafting.slots
        craftingResultItem = crafting.result
        if let position = currentContainer, case .furnace(let furnace) = world.blockEntity(at: position) {
            furnaceItems = [furnace.input, furnace.fuel, furnace.output]
            furnaceProgress = Double(furnace.cookTicks) / 200
        }
        if isMultiplayer { refreshMultiplayerHUD() }
    }

    /// True while a screen, load, or pause is taking input away from gameplay.
    var isInputBlocked: Bool {
        inventoryOpen || isPaused || isLoading || worldMenuOpen || showDeathScreen || chatOpen
            || signEditorOpen
    }

    func releaseInputAndPause() {
        primaryAction(isPressed: false)
        resetInput()
        if !isPaused && !inventoryOpen { togglePause() }
    }

    func persist(completion: (@MainActor () -> Void)? = nil) {
        returnCursorAndCrafting()
        saveWorld(completion: completion)
    }

    /// Cancels background world work; completions from earlier generations are ignored afterwards.
    func invalidateWorldTasks() {
        streamingTask?.cancel()
        sessionGeneration &+= 1
        streaming = false
        relighting = false
        evictionInProgress = false
    }

    /// Closes every screen and container and discards the cursor, crafting grid, and sleep state.
    func closeScreens() {
        inventoryOpen = false
        chatOpen = false
        signEditorOpen = false
        furnaceOpen = false
        currentContainer = nil
        currentContainerEntity = nil
        containerPositions = []
        containerTitle = ""
        cursor = nil
        crafting = CraftingGrid()
        craftingWidth = 2
        sleepingBed = nil
        sleepTicks = 0
    }

    func postChat(_ text: String) {
        chatLines.append(text)
        if chatLines.count > 50 { chatLines.removeFirst(chatLines.count - 50) }
        chatRevision &+= 1
    }

    func resetInput() {
        if isMultiplayer { stopMultiplayerMining() }
        pressed.removeAll()
        touchMovement = .zero
        miningPressed = false
        secondaryPressed = false
        mouseDelta = .zero
        miningTarget = nil
        miningProgress = 0
    }
}
