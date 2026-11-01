import MinecraftCore
import Testing

@Suite struct InventoryTests {
    @Test func betaCatalogPreservesItsOldStackAndDurabilityValues() {
        #expect(ItemDefinition.all.count == 202)
        #expect(CraftingRecipes.all.count == 151)
        #expect(ItemDefinition.definition(for: 260)?.maximumStackSize == 1)
        #expect(ItemDefinition.definition(for: 357)?.maximumStackSize == 8)
        #expect(ItemDefinition.definition(for: 344)?.maximumStackSize == 16)
        #expect(ItemDefinition.definition(for: 298)?.maximumDurability == 33)
        #expect(ItemDefinition.definition(for: 257)?.maximumDurability == 250)
        #expect(ItemDefinition.definition(for: 260)?.foodHealing == 4)
        #expect(ItemDefinition.definition(for: 351)?.iconIndex(damage: 15) == 191)
        #expect(ItemStack(id: 263, damage: 1).name == "Charcoal")
    }

    @Test func inventoryStacksBeforeFillingEmptySlotsAndReturnsOverflow() {
        var inventory = PlayerInventory()
        inventory.slots[0] = ItemStack(id: 1, count: 63)
        inventory.slots[1] = ItemStack(id: 35, count: 64, damage: 1)
        #expect(inventory.insert(ItemStack(id: 1, count: 65)) == nil)
        #expect(inventory.slots[0]?.count == 64)
        #expect(inventory.slots[2]?.count == 64)
        #expect(inventory.insert(ItemStack(id: 35, count: 2, damage: 2)) == nil)
        #expect(inventory.slots[3] == ItemStack(id: 35, count: 2, damage: 2))
        inventory.slots = Array(repeating: ItemStack(id: 4, count: 64), count: 36)
        #expect(inventory.insert(ItemStack(id: 1, count: 3)) == ItemStack(id: 1, count: 3))
    }

    @Test func shapedRecipesCanShiftAndMirrorWithoutConsumingWholeStacks() {
        var grid = CraftingGrid(width: 3, height: 3)
        for index in [1, 2, 5] { grid.slots[index] = ItemStack(id: 5, count: 3) }
        for index in [4, 7] { grid.slots[index] = ItemStack(id: 280, count: 2) }
        #expect(grid.result == ItemStack(id: 271))
        #expect(grid.craft() == ItemStack(id: 271))
        #expect(grid.slots[1]?.count == 2)
        #expect(grid.slots[4]?.count == 1)
        grid.slots[0] = ItemStack(id: 3)
        #expect(grid.result == nil)
        var small = CraftingGrid()
        small.slots = Array(repeating: ItemStack(id: 5), count: 4)
        #expect(small.craft() == ItemStack(id: 58))
        #expect(small.slots.allSatisfy { $0 == nil })
    }

    @Test func shapelessRecipesMatchMetadataAndRejectExtraIngredients() {
        var grid = CraftingGrid()
        grid.slots[0] = ItemStack(id: 351, damage: 15)
        grid.slots[3] = ItemStack(id: 351, damage: 0)
        #expect(grid.result == ItemStack(id: 351, count: 2, damage: 8))
        grid.slots[2] = ItemStack(id: 38)
        #expect(grid.result == nil)
    }

    @Test func cakeCraftingReturnsMilkBucketsAndSlabsUseBetaQuantities() {
        var grid = CraftingGrid(width: 3, height: 3)
        grid.slots = [
            ItemStack(id: 335), ItemStack(id: 335), ItemStack(id: 335),
            ItemStack(id: 353), ItemStack(id: 344), ItemStack(id: 353),
            ItemStack(id: 296), ItemStack(id: 296), ItemStack(id: 296),
        ]
        #expect(grid.craft() == ItemStack(id: 354))
        #expect(Array(grid.slots[0..<3]) == Array(repeating: ItemStack(id: 325), count: 3))
        grid.slots = Array(repeating: nil, count: 9)
        for index in 0..<3 { grid.slots[index] = ItemStack(id: 4) }
        #expect(grid.result == ItemStack(id: 44, count: 3, damage: 3))
    }

    @Test func furnaceUsesTwoHundredTicksAndContinuesBurningWhenBlocked() {
        var furnace = FurnaceState(input: ItemStack(id: 15, count: 2), fuel: ItemStack(id: 263))
        for _ in 0..<199 { furnace.tick() }
        #expect(furnace.output == nil)
        furnace.tick()
        #expect(furnace.output == ItemStack(id: 265))
        #expect(furnace.input?.count == 1)
        #expect(furnace.burnTicksRemaining == 1401)
        furnace.output = ItemStack(id: 265, count: 64)
        furnace.tick()
        #expect(furnace.cookTicks == 0)
        #expect(furnace.burnTicksRemaining == 1400)
        #expect(FurnaceRecipes.burnTime(for: ItemStack(id: 270)) == 0)
        #expect(FurnaceRecipes.result(for: ItemStack(id: 17, damage: 2)) == ItemStack(id: 263, damage: 1))
    }

    @Test func toolsKeepBetaHarvestRequirementsAndBreakAfterMaximumDamage() {
        var pickaxe = ItemStack(id: 257, damage: 249)
        let brokeAtMaximum = pickaxe.damageBy(1)
        #expect(!brokeAtMaximum)
        #expect(pickaxe.damage == 250)
        let brokeAfterMaximum = pickaxe.damageBy(1)
        #expect(brokeAfterMaximum)
        #expect(pickaxe.count == 0)
        #expect(!BlockMining.canHarvest(.diamondOre, with: ItemStack(id: 274)))
        #expect(BlockMining.canHarvest(.diamondOre, with: ItemStack(id: 257)))
        #expect(BlockMining.canHarvest(.obsidian, with: ItemStack(id: 278)))
        #expect(BlockMining.speed(for: .stone, with: ItemStack(id: 285)) == 12)
        #expect(BlockMining.drops(for: BlockState(.stone), with: nil).isEmpty)
        #expect(BlockMining.drops(for: BlockState(.stone), with: ItemStack(id: 270)) == [ItemStack(id: 4)])
        #expect(
            BlockMining.drops(for: BlockState(.leaves, metadata: 2), with: ItemStack(id: 359)) == [
                ItemStack(id: 18, damage: 2)
            ])
    }
}
