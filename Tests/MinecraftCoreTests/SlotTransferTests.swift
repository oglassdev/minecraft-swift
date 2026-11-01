import MinecraftCore
import Testing

@Test func slotSplittingAndSinglePlacementCanArrangeCraftingIngredients() {
    var cursor: ItemStack?
    var source: ItemStack? = ItemStack(id: 5, count: 9)
    SlotTransfer.exchange(cursor: &cursor, slot: &source, secondary: true)
    #expect(cursor?.count == 5)
    #expect(source?.count == 4)
    var grid = CraftingGrid()
    SlotTransfer.exchange(cursor: &cursor, slot: &grid.slots[0], secondary: true)
    SlotTransfer.exchange(cursor: &cursor, slot: &grid.slots[2], secondary: true)
    #expect(cursor?.count == 3)
    #expect(grid.result == ItemStack(id: 280, count: 4))
}

@Test func slotMergingRespectsCapacityAndSubtype() {
    var cursor: ItemStack? = ItemStack(id: 35, count: 10, damage: 4)
    var slot: ItemStack? = ItemStack(id: 35, count: 60, damage: 4)
    SlotTransfer.exchange(cursor: &cursor, slot: &slot)
    #expect(slot?.count == 64)
    #expect(cursor?.count == 6)
    cursor?.damage = 5
    SlotTransfer.exchange(cursor: &cursor, slot: &slot, secondary: true)
    #expect(slot?.damage == 5 && slot?.count == 6)
    #expect(cursor?.damage == 4 && cursor?.count == 64)
}
