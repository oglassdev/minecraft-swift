import Foundation
import MinecraftCore

#if os(macOS)
    import AppKit
#endif

extension GameSession {
    func refreshTexturePacks() {
        do {
            let directory = gameDirectory.appendingPathComponent("texturepacks", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            texturePacks = try TexturePackCatalog(directory: directory).packs()
        } catch { errorMessage = "Could not list texture packs: \(error.localizedDescription)" }
    }

    func selectTexturePack(_ descriptor: TexturePackDescriptor, persist: Bool = true) {
        textureSelectionGeneration &+= 1
        let generation = textureSelectionGeneration
        let catalog = TexturePackCatalog(directory: gameDirectory.appendingPathComponent("texturepacks"))
        let cache = gameDirectory.appendingPathComponent("texturepack-cache", isDirectory: true)
        Task {
            do {
                let override = try await Task.detached {
                    try catalog.select(name: descriptor.name, to: cache)
                }.value
                guard generation == textureSelectionGeneration else { return }
                texturePackURL = override
                texturePackRevision &+= 1
                TextureResources.configure(overrideURL: override, revision: texturePackRevision)
                options.skin = descriptor.name
                if persist { saveOptions() }
            } catch {
                guard generation == textureSelectionGeneration else { return }
                errorMessage = "Could not load texture pack: \(error.localizedDescription)"
            }
        }
    }

    func openTexturePackFolder() {
        #if os(macOS)
            let directory = gameDirectory.appendingPathComponent("texturepacks", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        #endif
    }
}
