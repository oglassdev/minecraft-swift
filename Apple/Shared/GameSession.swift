import Combine
import Foundation
import MinecraftCore

@MainActor
final class GameSession: ObservableObject {
    enum Action { case forward, backward, left, right, up, down, fast, jump, sneak }

    @Published var worldMenuOpen = false
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
    @Published var isMouseCaptured = false
    @Published var errorMessage: String?
    @Published var positionText = ""
    @Published var statusText = "Loading world…"
    @Published var isLoading = true
    @Published var inventoryOpen = false
    @Published var isPaused = false
    @Published var health = 20
    @Published var selectedHotbar = 0
    @Published var hotbarLabels = Array(repeating: "", count: 9)
    @Published var inventoryLabels = Array(repeating: "", count: 36)
    @Published var craftingWidth = 2
    @Published var craftingLabels = Array(repeating: "", count: 4)
    @Published var craftingResultLabel = ""
    @Published var cursorLabel = ""
    @Published var furnaceOpen = false
    @Published var furnaceLabels = Array(repeating: "", count: 3)
    @Published var furnaceProgress: Double = 0
    @Published var armorLabels = Array(repeating: "", count: 4)
    @Published var containerTitle = ""
    @Published var containerLabels: [String] = []

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
    @Published var multiplayerStatus = ""
    @Published var chatOpen = false
    @Published var chatLines: [String] = []
    @Published var signEditorOpen = false
    @Published var signLines = ["", "", "", ""]
    @Published var rainStrength: Float = 0
    @Published var thunderStrength: Float = 0
    var cameraPositionDouble: SIMD3<Double> { player.eyePositionDouble }
    var heldItem: ItemStack? { inventory.selectedStack }
    var isMining: Bool { miningPressed && miningTarget != nil && miningProgress > 0 }
    var sessionGeneration: UInt64 = 0
    var multiplayer: MultiplayerState?
    var connectionPending = false
    var particleEvents: [BlockEvent] = []
    var weather = WorldWeather(seed: 0)
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
    var accumulator: Float = 0
    var statusElapsed: Float = 0
    var miningTarget: BlockPosition?
    var miningProgress: Float = 0
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
    var tickCount = 0

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
        guard !isLoading, !worldMenuOpen else { return }
        audio.update(listener: camera.position, forward: camera.forward)
        guard !isPaused || isMultiplayer else {
            accumulator = 0
            return
        }
        accumulator += min(max(deltaTime, 0), 0.25)
        while accumulator >= 0.05 && !isLoading {
            tick()
            accumulator -= 0.05
        }
        updateTarget()
        statusElapsed += deltaTime
        if statusElapsed >= 0.15 {
            refreshHUD()
            statusElapsed = 0
        }
    }

    func tick() {
        if isMultiplayer {
            tickMultiplayer()
            return
        }
        let previous = player.position
        let healthBefore = player.health
        let inventoryBefore = inventory
        let groundedBefore = player.onGround
        let inputEnabled = !inventoryOpen && !chatOpen && !signEditorOpen
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
                yaw: camera.yaw, world: world, inventory: &inventory)
            camera.setPosition(player.eyePosition)
        }
        dispatch(player.drainStepEvents())
        worldTime += 1
        tickCount += 1
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
        advanceMining()
        dispatch(
            blockSimulation.tick(
                world: &world, players: [player.position], time: worldTime,
                entities: entitySimulation.entities, weather: weather))
        dispatch(
            entitySimulation.tick(world: &world, player: &player, inventory: &inventory, time: worldTime))
        dispatch(weather.tick(world: &world, players: [player.position], time: worldTime))
        if sleepTicks > 0 && player.health < healthBefore { wakeFromBed(setSpawn: false) }
        rainStrength = weather.rainStrength
        thunderStrength = weather.weightedThunderStrength
        recordStatisticsTick(
            previous: previous, healthBefore: healthBefore, inventoryBefore: inventoryBefore,
            groundedBefore: groundedBefore)
        if player.health == 0 {
            statistics.recordDeath()
            respawnSingleplayer()
            return
        }
        updatePortalContact()
        guard !isLoading else { return }
        let center = ChunkPosition(Int(floor(player.position.x)) >> 4, Int(floor(player.position.z)) >> 4)
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
        if isPressed && !miningPressed && !inventoryOpen && !isPaused {
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
            let attacked = blockSimulation.attack(
                hit: hit, holding: inventory.selectedStack, health: player.health, world: &world,
                time: worldTime)
            if attacked.healthRestored > 0 { player.heal(attacked.healthRestored) }
            dispatch(attacked.events)
        }
        miningProgress += BlockMining.progressPerTick(
            for: state.kind, with: inventory.selectedStack,
            underwater: player.isInWater, onGround: player.onGround)
        if tickCount % 4 == 0 { play(stepSound(state.kind), at: hit.position.vector, volume: 0.5) }
        guard miningProgress >= 1 else { return }
        let tool = inventory.selectedStack
        let drops = BlockMining.drops(for: state, with: tool)
        notifyAchievements(statistics.recordMine(state.kind))
        if let entity = world.blockEntity(at: hit.position) {
            dispatch(blockSimulation.containerDrops(entity, at: hit.position))
        }
        if state.kind == .jukebox { audio.playRecord(nil) }
        world.setBlock(nil, at: hit.position)
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
        for stack in drops { entitySimulation.drop(stack, at: center(of: hit.position)) }
        dispatch(blockSimulation.blockChanged(at: hit.position, world: &world, time: worldTime))
        play(state.kind == .glass ? "random.glass" : stepSound(state.kind), at: hit.position.vector)
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
        guard !isLoading && !isPaused && !inventoryOpen else { return }
        let usedItem = inventory.selectedStack
        switch entitySimulation.interactResult(
            origin: player.eyePositionDouble, direction: SIMD3<Double>(camera.forward),
            reach: min(selectedBlock?.distance ?? 4, 4), player: &player, inventory: &inventory, world: world)
        {
        case .used:
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
                    entities: &entitySimulation, yaw: camera.yaw, pitch: camera.pitch), itemID: usedItem?.id)
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
        let result = BlockInteractions.use(
            hit: hit, holding: inventory.selectedStack, yaw: camera.yaw,
            playerBounds: player.bounds, world: &world, health: player.health)
        if result.replaceHeldStack {
            inventory.slots[inventory.selectedHotbar] = result.replacement
        } else if result.consumed > 0 {
            _ = inventory.removeSelected(count: result.consumed)
        }
        inventory.damageSelected(by: result.durabilityDamage)
        if result.healthRestored > 0 { player.heal(result.healthRestored) }
        for position in result.changedPositions {
            dispatch(blockSimulation.blockChanged(at: position, world: &world, time: worldTime))
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
                        entities: &entitySimulation, yaw: camera.yaw, pitch: camera.pitch),
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
        audio.setPaused(isPaused && !isMultiplayer)
        refreshHUD()
    }

    func togglePause() {
        if !isMultiplayer && sleepTicks > 0 { wakeFromBed(setSpawn: false) }
        isPaused.toggle()
        resetInput()
        audio.setPaused(isPaused && !isMultiplayer)
    }

    func toggleFlight() {
        guard !isMultiplayer else { return }
        flight.toggle()
        statusText = flight ? "Debug flight enabled" : "Survival movement"
        player.teleport(to: SIMD3<Double>(camera.position) - SIMD3(0, 1.62, 0))
    }

    func inventoryClick(slot: Int, secondary: Bool = false) {
        if isMultiplayer {
            multiplayerInventoryClick(slot: slot, secondary: secondary)
            return
        }
        guard inventory.slots.indices.contains(slot) else { return }
        exchange(&inventory.slots[slot], secondary: secondary)
        refreshHUD()
    }

    func craftingClick(slot: Int, secondary: Bool = false) {
        if isMultiplayer {
            multiplayerCraftingClick(slot: slot, secondary: secondary)
            return
        }
        guard crafting.slots.indices.contains(slot) else { return }
        exchange(&crafting.slots[slot], secondary: secondary)
        refreshHUD()
    }

    func armorClick(slot: Int) {
        if isMultiplayer {
            multiplayerWindowClick(slot: slot + 5, secondary: false)
            return
        }
        guard inventory.armor.indices.contains(slot) else { return }
        if let cursor, cursor.definition?.armorSlot != slot { return }
        exchange(&inventory.armor[slot])
        refreshHUD()
    }

    func containerClick(slot: Int, secondary: Bool = false) {
        if isMultiplayer {
            multiplayerWindowClick(slot: slot, secondary: secondary)
            return
        }
        if let id = currentContainerEntity {
            entitySimulation.update(id: id) { entity in
                guard entity.contents.indices.contains(slot) else { return }
                exchange(&entity.contents[slot], secondary: secondary)
            }
            refreshHUD()
            return
        }
        var index = slot
        for position in containerPositions {
            guard let entity = world.blockEntity(at: position) else { continue }
            var slots = entity.contents
            if slots.indices.contains(index) {
                exchange(&slots[index], secondary: secondary)
                switch entity {
                case .chest: world.setBlockEntity(.chest(slots: slots), at: position)
                case .dispenser: world.setBlockEntity(.dispenser(slots: slots), at: position)
                default: return
                }
                refreshHUD()
                return
            }
            index -= slots.count
        }
    }

    func takeCraftingResult() {
        if isMultiplayer {
            multiplayerWindowClick(slot: 0, secondary: false)
            return
        }
        guard let result = crafting.result else { return }
        if let cursor {
            guard cursor.canStack(with: result), cursor.count + result.count <= cursor.maximumStackSize else {
                return
            }
        }
        guard var made = crafting.craft() else { return }
        if made.id == 358 { made = maps.craft(at: player.position, dimension: world.dimension) }
        if cursor == nil { cursor = made } else { cursor?.count += made.count }
        notifyAchievements(statistics.recordCraft(made))
        play("random.click", volume: 0.3)
        refreshHUD()
    }

    func furnaceClick(slot: Int) {
        if isMultiplayer {
            multiplayerWindowClick(slot: slot, secondary: false)
            return
        }
        guard let position = currentContainer, case .furnace(var furnace) = world.blockEntity(at: position)
        else { return }
        switch slot {
        case 0: exchange(&furnace.input)
        case 1: exchange(&furnace.fuel)
        case 2:
            guard let output = furnace.output else { return }
            if cursor == nil {
                cursor = output
                furnace.output = nil
                notifyAchievements(statistics.recordCraft(output, source: .furnace))
            } else if cursor?.canStack(with: output) == true,
                cursor!.count + output.count <= cursor!.maximumStackSize
            {
                cursor?.count += output.count
                furnace.output = nil
                notifyAchievements(statistics.recordCraft(output, source: .furnace))
            }
        default: return
        }
        world.setBlockEntity(.furnace(furnace), at: position)
        refreshHUD()
    }

    func exchange(_ slot: inout ItemStack?, secondary: Bool = false) {
        SlotTransfer.exchange(cursor: &cursor, slot: &slot, secondary: secondary)
        play("random.click", volume: 0.3)
    }

    func returnCursorAndCrafting() {
        guard !isMultiplayer else { return }
        for stack in ([cursor] + crafting.slots).compactMap({ $0 }) {
            if let remaining = inventory.insert(stack) {
                entitySimulation.drop(remaining, at: player.position)
            }
        }
        cursor = nil
        crafting = CraftingGrid(width: craftingWidth, height: craftingWidth)
    }

    func resizeCrafting(to width: Int) {
        if crafting.width != width {
            returnCursorAndCrafting()
            crafting = CraftingGrid(width: width, height: width)
        }
        craftingWidth = width
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
                    dispatch(
                        blockSimulation.stepped(
                            at: position, world: &world, time: worldTime, position: source))
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
                    at: position, power: power, world: &world, player: &player)
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
        let p = player.position
        positionText = String(format: "XYZ  %.1f  %.1f  %.1f  ·  Beta 1.7.3", p.x, p.y, p.z)
        health = player.health
        selectedHotbar = inventory.selectedHotbar
        inventoryItems = inventory.slots
        armorItems = inventory.armor
        inventoryLabels = inventory.slots.map(label)
        armorLabels = inventory.armor.map(label)
        if let id = currentContainerEntity {
            containerItems = entities.first(where: { $0.id == id })?.contents ?? []
        } else {
            containerItems = containerPositions.flatMap { world.blockEntity(at: $0)?.contents ?? [] }
        }
        containerLabels = containerItems.map(label)
        hotbarLabels = Array(inventoryLabels.prefix(9))
        craftingItems = crafting.slots
        craftingResultItem = crafting.result
        craftingLabels = crafting.slots.map(label)
        craftingResultLabel = label(crafting.result)
        cursorLabel = label(cursor)
        if let position = currentContainer, case .furnace(let furnace) = world.blockEntity(at: position) {
            furnaceItems = [furnace.input, furnace.fuel, furnace.output]
            furnaceLabels = furnaceItems.map(label)
            furnaceProgress = Double(furnace.cookTicks) / 200
        }
        if isMultiplayer { refreshMultiplayerHUD() }
    }

    func label(_ stack: ItemStack?) -> String {
        guard let stack else { return "" }
        return stack.count == 1 ? stack.name : "\(stack.name) ×\(stack.count)"
    }

    func resetInput() {
        if isMultiplayer { stopMultiplayerMining() }
        pressed.removeAll()
        touchMovement = .zero
        miningPressed = false
        miningTarget = nil
        miningProgress = 0
    }
}
