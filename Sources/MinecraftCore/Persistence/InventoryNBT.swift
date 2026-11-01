import Foundation

enum InventoryNBT {
    static func stack(_ tag: NBTTag) -> ItemStack? {
        guard let values = tag.compoundValue,
            let id = values["id"]?.integerValue,
            let count = values["Count"]?.integerValue, count > 0
        else { return nil }
        return ItemStack(
            id: UInt16(truncatingIfNeeded: id), count: Int(count),
            damage: UInt16(truncatingIfNeeded: values["Damage"]?.integerValue ?? 0))
    }

    static func encodeStack(_ stack: ItemStack, previous: [String: NBTTag] = [:]) -> NBTTag {
        var values = previous
        values["id"] = .short(Int16(bitPattern: stack.id))
        values["Count"] = .byte(Int8(clamping: stack.count))
        values["Damage"] = .short(Int16(bitPattern: stack.damage))
        return .compound(values)
    }

    static func decode(_ entries: [NBTTag], slotCount: Int, offset: Int = 0) -> [ItemStack?] {
        var result = [ItemStack?](repeating: nil, count: slotCount)
        for entry in entries {
            guard let storedSlot = entry.compoundValue?["Slot"]?.integerValue else { continue }
            let slot = Int(UInt8(truncatingIfNeeded: storedSlot)) - offset
            if result.indices.contains(slot) { result[slot] = stack(entry) }
        }
        return result
    }

    static func encode(_ slots: [ItemStack?], previous: [NBTTag]) -> NBTTag {
        encodeSlots(
            Dictionary(
                uniqueKeysWithValues: slots.enumerated().compactMap { index, stack in
                    stack.map { (index, $0) }
                }), knownSlots: Set(slots.indices), previous: previous)
    }

    static func encodePlayer(_ inventory: PlayerInventory, previous: [NBTTag]) -> NBTTag {
        var slots = Dictionary(
            uniqueKeysWithValues: inventory.slots.enumerated().compactMap { index, stack in
                stack.map { (index, $0) }
            })
        for (index, stack) in inventory.armor.enumerated() {
            if let stack { slots[index + 100] = stack }
        }
        return encodeSlots(slots, knownSlots: Set(0..<36).union(100..<104), previous: previous)
    }

    private static func encodeSlots(_ slots: [Int: ItemStack], knownSlots: Set<Int>, previous: [NBTTag])
        -> NBTTag
    {
        var old: [Int: [String: NBTTag]] = [:]
        var entries: [NBTTag] = []
        for entry in previous {
            guard let values = entry.compoundValue, let id = values["Slot"]?.integerValue else {
                entries.append(entry)
                continue
            }
            let slot = Int(UInt8(truncatingIfNeeded: id))
            old[slot] = values
            if !knownSlots.contains(slot) { entries.append(entry) }
        }
        for slot in slots.keys.sorted() {
            guard let stack = slots[slot], stack.count > 0 else { continue }
            var fields = old[slot] ?? [:]
            fields["Slot"] = .byte(Int8(truncatingIfNeeded: slot))
            entries.append(encodeStack(stack, previous: fields))
        }
        return .list(entries.isEmpty ? .byte : .compound, entries)
    }
}
