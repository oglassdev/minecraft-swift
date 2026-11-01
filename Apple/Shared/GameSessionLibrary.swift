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
            self.invalidateWorldTasks()
            self.worldDirectory = descriptor.directory
            self.service = WorldService(
                directory: descriptor.directory, newWorldSeed: descriptor.seed, newWorldName: descriptor.name)
            self.isLoading = true
            self.isPaused = false
            self.worldMenuOpen = false
            self.closeScreens()
            self.portalTicks = 0
            self.portalCooldown = 0
            self.errorMessage = nil
            self.particleEvents.removeAll()
            self.audio.playRecord(nil)
            self.syncAudioPause()
            Task {
                await self.loadWorld()
                if descriptor.isNew, !self.isLoading { self.saveWorld() }
            }
        }
    }

    func convertWorld(_ descriptor: WorldDescriptor) {
        invalidateWorldTasks()
        let generation = sessionGeneration
        isLoading = true
        Task {
            do {
                _ = try await Task.detached {
                    try LegacyWorldConverter(directory: descriptor.directory).convert {
                        [weak self] progress in
                        Task { @MainActor in
                            guard let self, self.sessionGeneration == generation else { return }
                            self.loadingProgress = progress.fractionCompleted
                        }
                    }
                }.value
                guard sessionGeneration == generation else { return }
                isLoading = false
                loadingProgress = nil
                refreshWorldList()
                if let converted = availableWorlds.first(where: { $0.directory == descriptor.directory }) {
                    openWorld(converted)
                }
            } catch {
                guard sessionGeneration == generation else { return }
                isLoading = false
                loadingProgress = nil
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
            guard let self else { return }
            self.worldMenuOpen = true
            self.showDeathScreen = false
            self.deathScreenTicks = 0
            self.inventoryOpen = false
            self.chatOpen = false
            self.signEditorOpen = false
            self.syncAudioPause()
            self.refreshWorldList()
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
        if isMultiplayer {
            multiplayer?.client?.send(.dig(status: 4, position: BlockPosition(0, 0, 0), face: 0))
        } else if let item = inventory.removeSelected() {
            dropFromPlayer(item)
        }
        refreshHUD()
    }
}

extension GameSession {
    func renameWorld(_ descriptor: WorldDescriptor, name: String) {
        guard !worldTransitionPending else { return }
        worldTransitionPending = true
        let catalog = WorldCatalog(directory: gameDirectory.appendingPathComponent("saves"))
        Task {
            defer { worldTransitionPending = false }
            await service.flush()
            do {
                try await Task.detached { try catalog.rename(descriptor, name: name) }.value
                if descriptor.directory == worldDirectory { worldName = name }
                refreshWorldList()
            } catch { errorMessage = "Could not rename world: \(error.localizedDescription)" }
        }
    }

    func deleteWorld(_ descriptor: WorldDescriptor) {
        guard !worldTransitionPending else { return }
        worldTransitionPending = true
        let catalog = WorldCatalog(directory: gameDirectory.appendingPathComponent("saves"))
        Task {
            defer { worldTransitionPending = false }
            await service.flush()
            do {
                try await Task.detached { try catalog.delete(descriptor) }.value
                if descriptor.directory == worldDirectory {
                    invalidateWorldTasks()
                    hasLoadedWorld = false
                    showDeathScreen = false
                    world = BlockWorld()
                }
                refreshWorldList()
            } catch { errorMessage = "Could not delete world: \(error.localizedDescription)" }
        }
    }
}
