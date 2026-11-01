import Foundation
import MinecraftCore

extension GameSession {
    func refreshWorldList() {
        do {
            availableWorlds = try WorldCatalog(directory: gameDirectory.appendingPathComponent("saves"))
                .worlds()
        } catch { errorMessage = "Could not list worlds: \(error.localizedDescription)" }
    }

    func createWorld(name: String, seed: String) {
        do {
            let descriptor = try WorldCatalog(directory: gameDirectory.appendingPathComponent("saves"))
                .create(name: name, seedText: seed)
            openWorld(descriptor)
        } catch { errorMessage = "Could not create world: \(error.localizedDescription)" }
    }

    func openWorld(_ descriptor: WorldDescriptor) {
        guard !isLoading, !worldTransitionPending else { return }
        if descriptor.requiresConversion {
            convertWorld(descriptor)
            return
        }
        if isMultiplayer { disconnectMultiplayer() }
        worldTransitionPending = true
        isPaused = true
        resetInput()
        returnCursorAndCrafting()
        saveWorld { [weak self] in
            guard let self else { return }
            self.worldTransitionPending = false
            self.streamingTask?.cancel()
            self.sessionGeneration &+= 1
            self.worldDirectory = descriptor.directory
            self.service = WorldService(
                directory: descriptor.directory, newWorldSeed: descriptor.seed, newWorldName: descriptor.name)
            self.streaming = false
            self.relighting = false
            self.evictionInProgress = false
            self.isLoading = true
            self.isPaused = false
            self.worldMenuOpen = false
            self.inventoryOpen = false
            self.chatOpen = false
            self.signEditorOpen = false
            self.currentContainer = nil
            self.currentContainerEntity = nil
            self.containerPositions = []
            self.cursor = nil
            self.crafting = CraftingGrid()
            self.craftingWidth = 2
            self.portalTicks = 0
            self.portalCooldown = 0
            self.sleepTicks = 0
            self.sleepingBed = nil
            self.errorMessage = nil
            self.statusText = "Loading \(descriptor.name)…"
            self.particleEvents.removeAll()
            self.audio.playRecord(nil)
            Task {
                await self.loadWorld()
                if descriptor.isNew, !self.isLoading { self.saveWorld() }
            }
        }
    }

    func convertWorld(_ descriptor: WorldDescriptor) {
        streamingTask?.cancel()
        sessionGeneration &+= 1
        let generation = sessionGeneration
        isLoading = true
        statusText = "Converting \(descriptor.name)…"
        Task {
            do {
                _ = try await Task.detached {
                    try LegacyWorldConverter(directory: descriptor.directory).convert {
                        [weak self] progress in
                        Task { @MainActor in
                            guard let self, self.sessionGeneration == generation else { return }
                            self.statusText =
                                "Converting \(descriptor.name)… \(Int(progress.fractionCompleted * 100))%"
                        }
                    }
                }.value
                guard sessionGeneration == generation else { return }
                isLoading = false
                refreshWorldList()
                if let converted = availableWorlds.first(where: { $0.directory == descriptor.directory }) {
                    openWorld(converted)
                }
            } catch {
                guard sessionGeneration == generation else { return }
                isLoading = false
                errorMessage = "Could not convert world: \(error.localizedDescription)"
            }
        }
    }

    func showWorldMenu() {
        if isMultiplayer { disconnectMultiplayer() }
        isPaused = true
        resetInput()
        returnCursorAndCrafting()
        saveWorld { [weak self] in
            self?.worldMenuOpen = true
            self?.refreshWorldList()
        }
    }

    func applyOptions() {
        options.sound = options.sound.isFinite ? min(1, max(0, options.sound)) : 1
        options.music = options.music.isFinite ? min(1, max(0, options.music)) : 1
        options.mouseSensitivity =
            options.mouseSensitivity.isFinite ? min(1, max(0, options.mouseSensitivity)) : 0.5
        options.renderDistance = min(3, max(0, options.renderDistance))
        options.difficulty = min(3, max(0, options.difficulty))
        options.fpsLimit = min(2, max(0, options.fpsLimit))
        audio.effectsVolume = min(1, max(0, options.sound))
        audio.musicVolume = min(1, max(0, options.music))
        audio.musicEnabled = options.music > 0
        player.difficulty = min(3, max(0, options.difficulty))
    }

    func saveOptions() {
        applyOptions()
        do { try options.save(to: gameDirectory.appendingPathComponent("options.txt")) } catch {
            errorMessage = "Could not save options: \(error.localizedDescription)"
        }
    }

    func dropSelectedItem() {
        guard !inventoryOpen, !isPaused, !isLoading else { return }
        statistics.recordDrop()
        if isMultiplayer {
            multiplayer?.client?.send(.dig(status: 4, position: BlockPosition(0, 0, 0), face: 0))
        } else if let item = inventory.removeSelected() {
            let position = player.eyePositionDouble - SIMD3(0, 0.3, 0)
            let id = entitySimulation.spawn(
                kind: "item", position: position,
                velocity: SIMD3<Double>(camera.forward) * 0.3 + SIMD3(0, 0.1, 0))
            entitySimulation.update(id: id) {
                $0.itemStack = item
                $0.pickupDelay = 40
            }
        }
        refreshHUD()
    }
}
