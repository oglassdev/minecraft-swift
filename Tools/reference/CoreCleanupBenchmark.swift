import Foundation
import MinecraftCore

// Block random-tick and lighting workloads on generated terrain. The digest covers every block ID and
// metadata value, so a faster run must report the same digest and revision.
let radius = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 10
let ticks = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 100

func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}

var generator = BetaTerrainGenerator(seed: 4242)
var world = BlockWorld(seed: 4242)
for x in -radius...radius {
    for z in -radius...radius { world.setChunk(generator.generateChunk(x: x, z: z)) }
}
let relightStart = ContinuousClock.now
WorldLighting.rebuild(world: &world)
let relight = milliseconds(relightStart.duration(to: .now))

var simulation = BlockSimulation(seed: 4242)
var weather = WorldWeather(seed: 4242)
var tickState = WorldTickState(randomSeed: 4242, coordinateSeed: 4242)
var events = 0
func tick(_ time: Int64) {
    events +=
        simulation.tick(
            world: &world, players: [SIMD3(8, 80, 8)], time: time, weather: &weather, tickState: &tickState,
            includeBlockEntities: false
        ).count
}
for time in 0..<10 { tick(Int64(time)) }
let start = ContinuousClock.now
for time in 0..<ticks { tick(Int64(10 + time)) }
let tickMilliseconds = milliseconds(start.duration(to: .now)) / Double(ticks)

var digest: UInt64 = 14_695_981_039_346_656_037
for key in world.chunks.keys.sorted(by: { ($0.x, $0.z) < ($1.x, $1.z) }) {
    guard let chunk = world.chunks[key] else { continue }
    for value in chunk.blockIDs + chunk.metadata { digest = (digest ^ UInt64(value)) &* 1_099_511_628_211 }
}
print(
    "chunks=\(world.chunks.count) ticks=\(ticks) fullRelightMs=\(relight) msPerTick=\(tickMilliseconds) events=\(events) revision=\(world.revision) digest=\(String(digest, radix: 16))"
)
