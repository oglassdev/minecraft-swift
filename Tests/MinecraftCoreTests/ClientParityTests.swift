import MinecraftCore
import Testing

struct ClientParityTests {
    @Test func containerClicksMatchOriginalSwapAndPartialCraftVectors() {
        var container = ContainerInventory(kind: .player)
        container.slots[36] = ItemStack(id: 35, count: 60, damage: 4)
        container.cursor = ItemStack(id: 35, count: 6, damage: 5)
        container.click(slot: 36, secondary: true)
        #expect(container.slots[36] == ItemStack(id: 35, count: 6, damage: 5))
        #expect(container.cursor == ItemStack(id: 35, count: 60, damage: 4))
        container.slots[36] = ItemStack(id: 267, damage: 2)
        container.cursor = ItemStack(id: 267, damage: 3)
        container.click(slot: 36, secondary: true)
        #expect(container.slots[36]?.damage == 2 && container.cursor?.damage == 3)
        for slot in 9..<45 { container.slots[slot] = ItemStack(id: 1, count: 64) }
        container.slots[44] = ItemStack(id: 5, count: 63)
        container.slots[1] = ItemStack(id: 17, count: 2)
        container.slots[0] = ItemStack(id: 5, count: 4)
        container.cursor = nil
        let result = container.click(slot: 0, shift: true)
        #expect(container.slots[44] == ItemStack(id: 5, count: 64))
        #expect(container.slots[1] == ItemStack(id: 17))
        #expect(container.slots[0] == ItemStack(id: 5, count: 4))
        #expect(result.outputs == [ItemStack(id: 5, count: 3)])
    }

    @Test func sourceContainerRoutingAndOutputRulesRemainDistinct() {
        var furnace = ContainerInventory(kind: .furnace)
        furnace.slots[3] = ItemStack(id: 15, count: 3)
        furnace.click(slot: 3, shift: true)
        #expect(furnace.slots[0] == nil && furnace.slots[30] == ItemStack(id: 15, count: 3))
        furnace.slots[2] = ItemStack(id: 265, count: 5)
        furnace.click(slot: 2, secondary: true)
        #expect(furnace.cursor?.count == 3 && furnace.slots[2]?.count == 2)
        var dispenser = ContainerInventory(kind: .dispenser)
        dispenser.slots[0] = ItemStack(id: 4, count: 7)
        dispenser.click(slot: 0, shift: true)
        #expect(dispenser.slots[0]?.count == 7 && dispenser.slots[9] == nil)
        var chest = ContainerInventory(kind: .chest(27))
        chest.slots[0] = ItemStack(id: 5, count: 10)
        chest.slots[62] = ItemStack(id: 5, count: 63)
        chest.click(slot: 0, shift: true)
        #expect(chest.slots[0] == nil && chest.slots[62]?.count == 64 && chest.slots[61]?.count == 9)
    }

    @Test func originalMouseFilterAndSwingProgressBitsMatch() {
        var filter = BetaMouseFilter()
        let deltas: [Float] = [8, 0, 0, -4, 0, 12, 0, 0]
        let bits: [UInt32] = [
            1_045_220_557, 1_050_085_950, 1_051_432_322, 1_042_435_119, 1_041_903_303, 1_055_986_997,
            1_058_561_483, 1_059_354_686,
        ]
        #expect(deltas.map { filter.filter($0, factor: 0.05).bitPattern } == bits)
        var player = Player(position: SIMD3(0.5, 65, 0.5))
        player.swing()
        let swing: [UInt32] = [
            0, 1_040_187_392, 1_048_576_000, 1_052_770_304, 1_056_964_608, 1_059_061_760, 1_061_158_912,
            1_063_256_064, 0, 0,
        ]
        for value in swing {
            player.tick(input: PlayerInput(), yaw: 0, world: BlockWorld())
            #expect(player.swingProgress.bitPattern == value)
        }
        let damaged = player.damage(4)
        #expect(damaged)
        #expect(player.health == 16 && player.previousHealth == 20)
        #expect(player.hurtTime == 10 && player.maxHurtTime == 10 && player.healthFlashTime == 20)
    }

    @Test func timerRetainsFractionAndLimitsCatchupLikeBeta() {
        var timer = BetaTimer()
        let steps = [0.025, 0.025, 1.0, 0.0].map { seconds in
            let ticks = timer.advance(seconds: seconds)
            return SIMD2(Float(ticks), timer.partialTick)
        }
        #expect(steps == [SIMD2(0, 0.5), SIMD2(1, 0), SIMD2(10, 0), SIMD2(0, 0)])
    }
}
