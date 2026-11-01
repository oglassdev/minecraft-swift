public enum SlotTransfer {
    public static func matches(_ first: ItemStack, _ second: ItemStack) -> Bool {
        first.id == second.id && (first.definition?.hasSubtypes != true || first.damage == second.damage)
    }

    public static func exchange(
        cursor: inout ItemStack?, slot: inout ItemStack?, secondary: Bool = false,
        limit: Int = 64, accepts: Bool = true
    ) {
        guard var held = cursor else {
            guard var existing = slot else { return }
            let count = secondary ? (existing.count + 1) / 2 : existing.count
            cursor = ItemStack(id: existing.id, count: count, damage: existing.damage)
            existing.count -= count
            slot = existing.count > 0 ? existing : nil
            return
        }
        guard var existing = slot else {
            guard accepts else { return }
            let count = min(secondary ? 1 : held.count, limit)
            slot = ItemStack(id: held.id, count: count, damage: held.damage)
            held.count -= count
            cursor = held.count > 0 ? held : nil
            return
        }
        if accepts {
            if matches(existing, held) {
                let count = max(
                    0,
                    min(
                        secondary ? 1 : held.count, limit - existing.count,
                        held.maximumStackSize - existing.count))
                existing.count += count
                held.count -= count
                slot = existing
                cursor = held.count > 0 ? held : nil
            } else if held.count <= limit {
                swap(&cursor, &slot)
            }
        } else if matches(existing, held), held.maximumStackSize > 1,
            held.count + existing.count <= held.maximumStackSize
        {
            held.count += existing.count
            cursor = held
            slot = nil
        }
    }

    /// Container.mergeItemStack uses item limits for merges and the first empty slot for the remainder.
    public static func merge(_ stack: inout ItemStack, into slots: inout [ItemStack?], indices: [Int]) {
        if stack.canStack(with: stack) {
            for index in indices where slots.indices.contains(index) {
                guard stack.count > 0, var existing = slots[index], matches(stack, existing) else { continue }
                let count = max(0, min(stack.count, stack.maximumStackSize - existing.count))
                existing.count += count
                stack.count -= count
                slots[index] = existing
            }
        }
        if stack.count > 0,
            let index = indices.first(where: { slots.indices.contains($0) && slots[$0] == nil })
        {
            slots[index] = stack
            stack.count = 0
        }
    }
}
