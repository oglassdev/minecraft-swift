public struct PlayerInventory: Codable, Equatable, Sendable {
    public static let slotCount = 36
    public var slots: [ItemStack?]
    public var armor: [ItemStack?]
    public var selectedHotbar: Int

    public init() {
        slots = Array(repeating: nil, count: Self.slotCount)
        armor = Array(repeating: nil, count: 4)
        selectedHotbar = 0
    }

    public var selectedStack: ItemStack? {
        guard (0..<9).contains(selectedHotbar) else { return nil }
        return slots[selectedHotbar]
    }

    /// Returns the portion that could not fit, preserving metadata and damaged tools.
    @discardableResult
    public mutating func insert(_ stack: ItemStack) -> ItemStack? {
        guard stack.count > 0 else { return nil }
        guard let definition = stack.definition else { return stack }
        if definition.maximumDurability > 0 && stack.damage > 0 {
            guard let index = slots.firstIndex(where: { $0 == nil }) else { return stack }
            slots[index] = stack
            return nil
        }
        var remaining = stack
        for index in slots.indices {
            guard var existing = slots[index], existing.canStack(with: remaining) else { continue }
            let amount = min(remaining.count, max(0, existing.maximumStackSize - existing.count))
            existing.count += amount
            remaining.count -= amount
            slots[index] = existing
            if remaining.count == 0 { return nil }
        }
        for index in slots.indices where slots[index] == nil {
            let amount = min(remaining.count, remaining.maximumStackSize)
            slots[index] = ItemStack(id: remaining.id, count: amount, damage: remaining.damage)
            remaining.count -= amount
            if remaining.count == 0 { return nil }
        }
        return remaining
    }

    public mutating func removeSelected(count: Int = 1) -> ItemStack? {
        guard (0..<9).contains(selectedHotbar) else { return nil }
        return remove(from: selectedHotbar, count: count)
    }

    public mutating func remove(from index: Int, count: Int = 1) -> ItemStack? {
        guard slots.indices.contains(index), count > 0, var stack = slots[index] else { return nil }
        let removed = ItemStack(id: stack.id, count: min(count, stack.count), damage: stack.damage)
        stack.count -= removed.count
        slots[index] = stack.count > 0 ? stack : nil
        return removed
    }

    public mutating func damageSelected(by amount: Int) {
        guard (0..<9).contains(selectedHotbar), var stack = slots[selectedHotbar] else { return }
        stack.damageBy(amount)
        slots[selectedHotbar] = stack.count > 0 ? stack : nil
    }

    public mutating func scrollHotbar(_ direction: Int) {
        let step = direction == 0 ? 0 : (direction > 0 ? 1 : -1)
        selectedHotbar = (selectedHotbar - step + 9) % 9
    }

    public var armorProtection: Int {
        var protection = 0
        var remaining = 0
        var total = 0
        for stack in armor.compactMap({ $0 }) {
            guard let definition = stack.definition, definition.armorSlot != nil else { continue }
            protection += definition.armorPoints
            remaining += max(0, definition.maximumDurability - Int(stack.damage))
            total += definition.maximumDurability
        }
        guard total > 0 else { return 0 }
        return (protection - 1) * remaining / total + 1
    }

    public mutating func damageArmor(by amount: Int) {
        for index in armor.indices {
            guard var stack = armor[index], stack.definition?.armorSlot != nil else { continue }
            stack.damageBy(amount)
            armor[index] = stack.count > 0 ? stack : nil
        }
    }
}
