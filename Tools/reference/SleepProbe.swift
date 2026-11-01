import Foundation
import MinecraftCore

/// Compile with the shared Apple sources except MinecraftApp.swift, plus macOS/MetalSurface.swift.
/// An optional argument checks a disposable copy of a saved world, without saving any changes.
@main
struct SleepProbe {
    static let bed = BlockPosition(8, 64, 8)

    @MainActor
    static func fixture(rotation: UInt8 = 0) -> GameSession {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("minecraft-sleep-probe")
        let session = GameSession(
            directory: root.appendingPathComponent("world"), loadAutomatically: false,
            supportDirectory: root)
        var chunk = Chunk(position: ChunkPosition(0, 0))
        chunk.isTerrainPopulated = true
        for x in 0..<16 {
            for z in 0..<16 { chunk[x, 63, z] = BlockState(.stone) }
        }
        let direction = [SIMD2(0, 1), SIMD2(-1, 0), SIMD2(0, -1), SIMD2(1, 0)][Int(rotation)]
        chunk[8, 64, 8] = BlockState(.bed, metadata: 8 | rotation)
        chunk[8 - direction.x, 64, 8 - direction.y] = BlockState(.bed, metadata: rotation)
        session.world.setChunk(chunk, updateLighting: false)
        session.entitySimulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        session.player = Player(position: SIMD3(9.5, 64, 8.5))
        session.player.difficulty = 0
        session.worldTime = 13000
        session.isLoading = false
        session.isPaused = false
        session.streaming = true
        return session
    }

    @MainActor
    static func main() async throws {
        let offsets = [SIMD2(0.5, 0.9), SIMD2(0.1, 0.5), SIMD2(0.5, 0.1), SIMD2(0.9, 0.5)]
        for rotation: UInt8 in 0...3 {
            for fps in [30, 60, 120] {
                let session = fixture(rotation: rotation)
                session.weather = WorldWeather(seed: 0, raining: true, thundering: true)
                session.beginSleeping(at: bed)
                precondition(session.isSleeping && session.player.isSleeping && session.sleepTicks == 0)
                let eye = session.player.eyePositionDouble
                let offset = offsets[Int(rotation)]
                precondition(abs(eye.x - 8 - Double(Float(offset.x))) < 0.000001)
                precondition(abs(eye.z - 8 - Double(Float(offset.y))) < 0.000001)
                precondition(eye.y == 64.9375)
                for _ in 0..<(fps * 6) { session.update(deltaTime: 1 / Float(fps)) }
                precondition(!session.isSleeping && !session.player.isSleeping && session.sleepTicks == 0)
                precondition((24000...24025).contains(session.worldTime))
                precondition(
                    session.bedSpawn == bed && !session.weather.raining && !session.weather.thundering)
                precondition(!session.isPaused && session.errorMessage == nil)
            }
        }

        let session = fixture()
        session.beginSleeping(at: bed)
        for _ in 0..<50 { session.update(deltaTime: 0.05) }
        precondition(session.isSleeping && session.sleepTicks == 50 && session.worldTime == 13050)
        precondition(session.sleepOpacity == 110.0 / 255)
        session.toggleInventory()
        precondition(!session.inventoryOpen)
        session.primaryAction(isPressed: true)
        session.secondaryAction()
        precondition(!session.miningPressed && session.sleepTicks == 50)
        session.dismissOverlay()
        precondition(
            !session.isSleeping && !session.isPaused && session.bedSpawn == nil && session.sleepTicks == 0)

        session.beginSleeping(at: bed)
        for _ in 0..<100 { session.update(deltaTime: 0.05) }
        precondition(!session.isSleeping && session.worldTime == 24000 && session.sleepTicks == 100)
        precondition(session.sleepOpacity == 220.0 / 255)
        for _ in 0..<5 { session.update(deltaTime: 0.05) }
        precondition(session.sleepTicks == 105 && session.sleepOpacity == 110.0 / 255)
        for _ in 0..<5 { session.update(deltaTime: 0.05) }
        precondition(session.sleepTicks == 0 && session.sleepOpacity == 0)

        let broken = fixture()
        broken.beginSleeping(at: bed)
        broken.world.setBlock(nil, at: bed)
        broken.update(deltaTime: 0.05)
        precondition(!broken.isSleeping && !broken.player.isSleeping && broken.bedSpawn == nil)

        let flying = fixture()
        flying.flight = true
        flying.beginSleeping(at: bed)
        let sleepingPosition = flying.player.position
        for _ in 0..<50 { flying.update(deltaTime: 0.05) }
        precondition(flying.player.position == sleepingPosition)

        let server = fixture()
        server.multiplayer = MultiplayerState(singleplayer: SingleplayerSnapshot(server))
        server.multiplayer?.localEntityID = 1
        server.multiplayer?.loadedChunks = [ChunkPosition(0, 0)]
        server.isMultiplayer = true
        server.worldTime = 6000
        server.receiveMultiplayer(.sleep(entityID: 1, mode: 0, position: bed))
        precondition(server.isSleeping && server.chatOpen && server.player.isSleeping)
        for _ in 0..<120 { server.update(deltaTime: 0.05) }
        precondition(server.isSleeping && server.sleepTicks == 100 && server.worldTime == 6120)
        server.sendChat("")
        precondition(server.chatOpen)
        server.receiveMultiplayer(.animation(entityID: 1, animation: 3))
        precondition(!server.isSleeping && !server.chatOpen && server.sleepTicks == 100)

        if let path = CommandLine.arguments.dropFirst().first {
            let directory = URL(fileURLWithPath: path)
            let saved = GameSession(
                directory: directory, loadAutomatically: false, supportDirectory: directory)
            saved.adopt(try await saved.service.load(radius: 1))
            saved.isPaused = false
            saved.isLoading = false
            saved.streaming = true
            saved.entitySimulation = EntitySimulation(seed: saved.world.seed, naturalSpawningEnabled: false)
            var beds: [BlockPosition] = []
            for (position, chunk) in saved.world.chunks {
                for x in 0..<16 {
                    for z in 0..<16 {
                        for y in 0..<128 where chunk[x, y, z]?.kind == .bed {
                            if chunk[x, y, z]!.metadata & 8 != 0 {
                                beds.append(BlockPosition(position.x * 16 + x, y, position.z * 16 + z))
                            }
                        }
                    }
                }
            }
            precondition(!beds.isEmpty, "The saved world has no loaded bed")
            for bed in beds {
                saved.worldTime = 13000
                saved.player = Player(
                    position: SIMD3(Double(bed.x) + 1.5, Double(bed.y), Double(bed.z) + 0.5))
                saved.beginSleeping(at: bed)
                for _ in 0..<110 { saved.update(deltaTime: 0.05) }
                precondition(!saved.isSleeping && saved.worldTime == 24010 && saved.bedSpawn == bed)
            }
            print("Saved-world sleep: \(beds.count) beds reached morning and set the respawn point")
        }
        print(
            "Sleep: 12 orientation/frame-rate runs; 100-tick night skip, wake fade, Escape, bed removal, flight, server authority"
        )
    }
}
