import Foundation
import Testing

@testable import MinecraftCore

#if canImport(Darwin)
    import Darwin
#endif

@Suite struct SimulationParityTests {
    @Test func activeChunksMatchOriginalJavaSixHashMapTraversal() {
        var set = BetaChunkSet()
        let expected: [(Int, UInt64)] = [
            (399, 0xca9f_3eb5_3b91_d202), (398, 0x2290_5d19_48bc_1d4f), (399, 0x96a2_1343_f432_3a88),
        ]
        for pass in 0..<3 {
            set.removeAll()
            for center in [ChunkPosition(pass - 2, -pass), ChunkPosition(0, 0)] {
                for x in -9...9 { for z in -9...9 { set.insert(ChunkPosition(center.x + x, center.z + z)) } }
            }
            #expect(set.count == expected[pass].0)
            #expect(Self.orderHash(set.elements) == expected[pass].1)
        }
    }

    @Test func worldRandomAndLCGMatchOriginalInterleavedEnvironmentTicks() {
        let traces: [(Int8, [Int32], [Int32])] = [
            (
                0, [-1_432_139_760, -1_198_406_845, 1_548_732_732],
                [2_101_384_115, 1_815_943_240, -1_397_966_140]
            ),
            (
                -1, [1_862_259_688, -2_066_279_201, 1_365_135_123],
                [845_512_885, -2_122_229_815, 460_050_864]
            ),
        ]
        for (dimension, coordinates, randoms) in traces {
            var world = BlockWorld(seed: 0, dimension: dimension)
            for x in -10...10 {
                for z in -10...10 {
                    var chunk = Chunk(position: ChunkPosition(x, z))
                    for bx in 0..<16 { for bz in 0..<16 { chunk[bx, 64, bz] = BlockState(.grass) } }
                    world.setChunk(chunk, updateLighting: false)
                }
            }
            var state = WorldTickState(
                random: JavaRandom(seed: 42), updateLCG: 0x1234_5678, caveSoundCooldown: 10000)
            var weather = WorldWeather(seed: 0, rainTime: 1000, thunderTime: 1000)
            var blocks = BlockSimulation(seed: -1)
            for tick in 0..<3 {
                weather.advanceTimers(dimension: dimension, random: &state.random)
                _ = blocks.tick(
                    world: &world, players: [SIMD3(8.5, 65, 8.5)], time: Int64(tick + 1),
                    weather: &weather, tickState: &state)
                #expect(state.updateLCG == coordinates[tick])
                #expect(state.random.nextInt() == randoms[tick])
                #expect(Self.orderHash(state.activeChunks) == 0xe5ab_29f4_2c39_67d1)
            }
        }
    }

    @Test func scheduledCallbacksPreserveLivePriorityAndInitialBudget() {
        var queue = ScheduledBlockTickQueue()
        func entry(_ x: Int, _ time: Int64, _ order: Int64) -> ScheduledBlockTick {
            ScheduledBlockTick(position: BlockPosition(x, 10, 8), kind: .stone, time: time, order: order)
        }
        queue.insert(entry(8, 100, 0))
        queue.insert(entry(8, 90, 1))
        queue.insert(entry(9, 100, 2))
        queue.insert(entry(10, 105, 3))
        var cycle = queue.beginCycle()
        var positions: [Int] = []
        while let tick = cycle.next(in: &queue, through: 100) {
            positions.append(tick.position.x)
            if tick.position.x == 8 { queue.insert(entry(11, 100, 4)) }
        }
        #expect(positions == [8, 9, 11])
        #expect(queue.count == 1)
        cycle = queue.beginCycle()
        while let tick = cycle.next(in: &queue, through: 105) { positions.append(tick.position.x) }
        #expect(positions == [8, 9, 11, 10])
        #expect(queue.count == 0)
        for index in 0..<1001 { queue.insert(entry(index, 200, Int64(index))) }
        cycle = queue.beginCycle()
        var count = 0
        while cycle.next(in: &queue, through: 0, force: true) != nil { count += 1 }
        #expect(count == 1000)
        #expect(queue.count == 1)
    }

    @Test func caveAmbianceSharesWorldRandomAndCoordinateSequence() {
        var world = BlockWorld()
        for x in -9...9 {
            for z in -9...9 {
                var chunk = Chunk(position: ChunkPosition(x, z))
                chunk.skyLight = Array(repeating: 0, count: Chunk.volume)
                world.setChunk(chunk, updateLighting: false)
            }
        }
        var state = WorldTickState(random: JavaRandom(seed: 42), updateLCG: 0x1234_5678, caveSoundCooldown: 0)
        var weather = WorldWeather(seed: 0, rainTime: 1000, thunderTime: 1000)
        var blocks = BlockSimulation(seed: 0)
        for (index, vector) in [
            (Int32(2_125_307_620), Int32(-1_353_717_645)), (-1_641_778_640, -989_696_805),
            (-1_999_931_416, 753_318_891),
        ].enumerated() {
            weather.advanceTimers(dimension: 0, random: &state.random)
            _ = blocks.tick(
                world: &world, players: [SIMD3(8.5, 65, 8.5)], time: Int64(index + 1),
                weather: &weather, tickState: &state, includeBlockEntities: false)
            #expect(state.updateLCG == vector.0)
            #expect(state.random.nextInt() == vector.1)
            #expect(state.caveSoundCooldown == 0)
        }
        state = WorldTickState(random: JavaRandom(seed: 42), updateLCG: 1_099_108_075, caveSoundCooldown: 0)
        var random = state.random
        let changes = weather.tickChunk(
            ChunkPosition(0, 0), world: &world, players: [SIMD3(8.5, 65, 8.5)], tickState: &state,
            random: &random)
        for _ in 0..<80 { _ = state.nextPosition(in: ChunkPosition(0, 0)) }
        #expect(state.updateLCG == 1_565_649_408)
        #expect(state.caveSoundCooldown == 13248)
        #expect(random.nextInt() == -248_792_245)
        guard case .sound(let name, let position, let volume, let pitch) = changes.events.first else {
            Issue.record("Missing cave sound")
            return
        }
        #expect(name == "ambient.cave.cave")
        #expect(position == SIMD3(8.5, 62.5, 8.5))
        #expect(volume == 0.7)
        #expect(pitch.bitPattern == 0x3f4f_994f)
    }

    @Test func scheduledUpdatesRequireLoadedHaloAndDiscardUnloadedDueEntries() {
        var world = BlockWorld()
        var blocks = BlockSimulation(seed: 0)
        let p = BlockPosition(8, 10, 8)
        world[p] = .litRedstoneOre
        blocks.scheduleUpdate(at: p, kind: .litRedstoneOre, after: 0, world: world, time: 100)
        #expect(blocks.scheduledTicks.isEmpty)
        for x in 0...1 {
            for z in 0...1 where world.chunks[ChunkPosition(x, z)] == nil {
                world.setChunk(Chunk(position: ChunkPosition(x, z)))
            }
        }
        blocks.scheduleUpdate(at: p, kind: .litRedstoneOre, after: 0, world: world, time: 100)
        #expect(blocks.scheduledTicks.count == 1)
        world.removeChunk(at: ChunkPosition(1, 0))
        _ = blocks.tick(world: &world, players: [], time: 100)
        #expect(world[p] == .litRedstoneOre)
        #expect(blocks.scheduledTicks.isEmpty)
    }

    @Test func containerScatterKeepsItsPrivateRandomSeparateFromWorld() {
        var blocks = BlockSimulation(seed: 0)
        var random = JavaRandom(seed: 42)
        var original = random
        let events = blocks.withWorldRandom(&random) { simulation in
            simulation.containerDrops(
                .chest(slots: [ItemStack(id: 35, count: 64, damage: 2)]),
                at: BlockPosition(8, 1, 8), kind: .chest)
        }
        #expect(random.nextLong() == original.nextLong())
        let stacks = events.compactMap { event -> ItemStack? in
            if case .dropItemMoving(_, let stack, _) = event { return stack }
            return nil
        }
        #expect(stacks.reduce(0) { $0 + $1.count } == 64)
        #expect(stacks.allSatisfy { $0.damage == 2 })
    }

    @Test func notificationsMatchOriginalNestedAndMetadataCallbacks() {
        let p = BlockPosition(8, 10, 8)
        let west = BlockPosition(7, 10, 8)
        let nested = BlockPosition(6, 10, 8)
        var cells = Dictionary(
            uniqueKeysWithValues: (BlockNotificationStack<Int>.offsets.map { p.adding($0) } + [nested])
                .map { ($0, BlockState(.dirt)) })
        var stack = BlockNotificationStack<Int>()
        var trace: [String] = []
        var replaced = false
        func label(_ state: BlockState, at p: BlockPosition) -> String {
            "\(state.kind == .stone ? 99 : 98)@\(p.x),\(p.y),\(p.z)"
        }
        func drain() {
            while let step = stack.next() {
                switch step {
                case .added(let p, let state): trace.append("add:" + label(state, at: p))
                case .removed(let p, let state): trace.append("remove:" + label(state, at: p))
                case .neighbor(let at, let kind):
                    guard let state = cells[at] else { continue }
                    trace.append("neighbor:" + label(state, at: at) + "<-\(kind == .stone ? 99 : 98)")
                    if at == west && !replaced {
                        replaced = true
                        let old = cells[nested]
                        cells[nested] = BlockState(.stone)
                        stack.changed(at: nested, previous: old, current: cells[nested])
                    }
                case .continuation: break
                }
            }
        }
        cells[p] = BlockState(.stone)
        stack.changed(at: p, previous: nil, current: cells[p])
        drain()
        let neighbors = [
            "neighbor:98@7,10,8<-99", "neighbor:98@9,10,8<-99",
            "neighbor:98@8,9,8<-99", "neighbor:98@8,11,8<-99",
            "neighbor:98@8,10,7<-99", "neighbor:98@8,10,9<-99",
        ]
        #expect(
            trace == [
                "add:99@8,10,8", "neighbor:98@7,10,8<-99",
                "remove:98@6,10,8", "add:99@6,10,8",
            ] + neighbors)
        trace.removeAll()
        stack.notify(at: p, changedKind: .stone)
        drain()
        #expect(trace == neighbors)
        trace.removeAll()
        let old = cells[p]
        cells[p] = BlockState(.stone, metadata: 2)
        stack.changed(at: p, previous: old, current: cells[p])
        drain()
        #expect(trace == ["remove:99@8,10,8", "add:99@8,10,8"] + neighbors)
    }

    @Test func supportRemovalCompletesPast4096CallbacksOnCooperativeStack() async {
        let result = await Task.detached {
            var world = BlockWorld()
            for x in 0..<5 {
                for z in 0..<5 {
                    var chunk = Chunk(position: ChunkPosition(x, z))
                    for bx in 0..<16 {
                        for bz in 0..<16 { chunk[bx, 10, bz] = BlockState(.dandelion) }
                    }
                    world.setChunk(chunk, updateLighting: false)
                }
            }
            let p = BlockPosition(0, 10, 0)
            world[p] = .stone
            var simulation = BlockSimulation(seed: 42)
            let events = simulation.blockChanged(
                at: p, previousState: BlockState(.dandelion), world: &world, time: 0)
            let drops = events.filter {
                if case .dropItem = $0 { return true }
                return false
            }.count
            let remaining = world.chunks.values.reduce(0) { $0 + $1.blockCount }
            #if canImport(Darwin)
                let stackSize = pthread_get_stacksize_np(pthread_self())
            #else
                let stackSize = 0
            #endif
            return (remaining, drops, stackSize)
        }.value
        #expect(result.0 == 1)
        #expect(result.1 == 6399)
        #if canImport(Darwin)
            #expect(result.2 < 1024 * 1024)
        #endif
    }

    private static func orderHash(_ values: [ChunkPosition]) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for p in values {
            hash = (hash ^ UInt64(UInt32(truncatingIfNeeded: p.x))) &* 0x100_0000_01b3
            hash = (hash ^ UInt64(UInt32(truncatingIfNeeded: p.z))) &* 0x100_0000_01b3
        }
        return hash
    }
}
