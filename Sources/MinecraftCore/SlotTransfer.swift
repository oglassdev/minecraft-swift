public enum SlotTransfer {
    public static func exchange(cursor: inout ItemStack?, slot: inout ItemStack?, secondary: Bool = false) {
        if secondary {
            if var held = cursor {
                if var existing = slot {
                    guard existing.canStack(with: held), existing.count < existing.maximumStackSize else {
                        return
                    }
                    existing.count += 1
                    slot = existing
                } else {
                    slot = ItemStack(id: held.id, damage: held.damage)
                }
                held.count -= 1
                cursor = held.count > 0 ? held : nil
            } else if var existing = slot {
                let amount = (existing.count + 1) / 2
                cursor = ItemStack(id: existing.id, count: amount, damage: existing.damage)
                existing.count -= amount
                slot = existing.count > 0 ? existing : nil
            }
        } else if var held = cursor, var existing = slot, existing.canStack(with: held) {
            let amount = min(held.count, max(0, existing.maximumStackSize - existing.count))
            existing.count += amount
            held.count -= amount
            slot = existing
            cursor = held.count > 0 ? held : nil
        } else {
            swap(&slot, &cursor)
        }
    }
}
