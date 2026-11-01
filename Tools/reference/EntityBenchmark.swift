import Foundation
import MinecraftCore

let count = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 400
let ticks = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 40
var world = BlockWorld(seed: 1234)
for x in -72...72 { for z in -72...72 { world[BlockPosition(x, 0, z)] = .grass } }
var player = Player(position: SIMD3(0.5, 1, 0.5))
var inventory = PlayerInventory()
var simulation = EntitySimulation(seed: 1234, naturalSpawningEnabled: false)
let kinds = ["cow", "pig", "sheep", "chicken", "zombie", "skeleton", "spider", "squid", "item", "item"]
for index in 0..<count {
    let kind = kinds[index % kinds.count]
    let position = SIMD3(Double(index % 20) * 5.5 - 52, 1, Double(index / 20) * 5.5 - 52)
    let id = simulation.spawn(kind: kind, position: position)
    simulation.setEntityRandomSeed(Int64(index) * 7919 + 1234, for: id)
    if kind == "item" { simulation.update(id: id) { $0.itemStack = ItemStack(id: 4) } }
}
var events = 0
for tick in 0..<5 {
    events +=
        simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(18000 + tick))
        .count
}
let start = ContinuousClock.now
for tick in 0..<ticks {
    events +=
        simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(18005 + tick))
        .count
}
let duration = start.duration(to: .now)
let milliseconds = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
var digest: UInt64 = 14_695_981_039_346_656_037
func mix(_ value: UInt64) { digest = (digest ^ value) &* 1_099_511_628_211 }
for entity in simulation.entities {
    mix(UInt64(bitPattern: entity.id))
    for axis in 0..<3 {
        mix(entity.position[axis].bitPattern)
        mix(entity.velocity[axis].bitPattern)
    }
    mix(UInt64(entity.yaw.bitPattern))
    mix(UInt64(bitPattern: Int64(entity.health)))
    mix(UInt64(entity.ageTicks))
}
print(
    "entities=\(count) ticks=\(ticks) msPerTick=\(milliseconds / Double(ticks)) remaining=\(simulation.entities.count) events=\(events) digest=\(String(digest, radix: 16))"
)
