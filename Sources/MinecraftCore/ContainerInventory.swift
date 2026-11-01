public enum ContainerKind: Equatable, Sendable {
    case player, workbench, furnace
    case chest(Int)
    case dispenser

    public var playerStart: Int {
        switch self {
        case .player: 9
        case .workbench: 10
        case .furnace: 3
        case .chest(let count): count
        case .dispenser: 9
        }
    }
    public var slotCount: Int { playerStart + 36 }
    public var craftingWidth: Int? {
        switch self {
        case .player: 2
        case .workbench: 3
        default: nil
        }
    }
}

public struct ContainerClickResult: Sendable {
    public let previous: ItemStack?
    public var outputs: [ItemStack] = []
    public var dropped: [ItemStack] = []
}

/// Slots follow the original container/wire order, including the player main rows before the hotbar.
public struct ContainerInventory: Sendable {
    public let kind: ContainerKind
    public var slots: [ItemStack?]
    public var cursor: ItemStack?

    public init(kind: ContainerKind, slots: [ItemStack?]? = nil, cursor: ItemStack? = nil) {
        self.kind = kind
        self.slots = slots ?? Array(repeating: nil, count: kind.slotCount)
        self.cursor = cursor
    }

    @discardableResult
    public mutating func click(slot: Int, secondary: Bool = false, shift: Bool = false)
        -> ContainerClickResult
    {
        var result = ContainerClickResult(previous: slots.indices.contains(slot) ? slots[slot] : nil)
        if slot == -999 {
            if var held = cursor {
                let count = secondary ? 1 : held.count
                result.dropped = [ItemStack(id: held.id, count: count, damage: held.damage)]
                held.count -= count
                cursor = held.count > 0 ? held : nil
            }
            return result
        }
        guard slots.indices.contains(slot), slots.count == kind.slotCount else { return result }
        if shift {
            guard kind != .dispenser else { return result }
            while let original = slots[slot] {
                var remaining = original
                SlotTransfer.merge(&remaining, into: &slots, indices: transferIndices(from: slot))
                guard remaining.count != original.count else { break }
                slots[slot] = remaining.count > 0 ? remaining : nil
                if isOutput(slot) { takeOutput(remaining, result: &result) }
                guard let next = slots[slot], next.count < original.count else { break }
            }
            return result
        }
        let original = slots[slot]
        if slot == 0, kind.craftingWidth != nil, let output = original, cursor == nil {
            cursor = output
            slots[slot] = nil
        } else {
            let accepts: Bool
            var limit = 64
            if kind == .player && (5..<9).contains(slot) {
                accepts =
                    cursor.map { $0.definition?.armorSlot == slot - 5 || (slot == 5 && $0.id == 86) } ?? true
                limit = 1
            } else {
                accepts = !isOutput(slot)
            }
            SlotTransfer.exchange(
                cursor: &cursor, slot: &slots[slot], secondary: secondary,
                limit: limit, accepts: accepts)
        }
        if isOutput(slot), let original, (slots[slot]?.count ?? 0) < original.count, let cursor {
            takeOutput(cursor, result: &result)
        } else if let width = kind.craftingWidth, (1..<(1 + width * width)).contains(slot) {
            refreshRecipe()
        }
        return result
    }

    private func isOutput(_ slot: Int) -> Bool {
        (slot == 0 && kind.craftingWidth != nil) || (kind == .furnace && slot == 2)
    }

    private func transferIndices(from slot: Int) -> [Int] {
        let start = kind.playerStart
        let main = Array(start..<(start + 27))
        let hotbar = Array((start + 27)..<(start + 36))
        switch kind {
        case .chest(let count):
            return slot < count ? Array((start..<(start + 36)).reversed()) : Array(0..<count)
        case .player, .workbench, .furnace:
            if isOutput(slot) { return Array((start..<(start + 36)).reversed()) }
            if slot < start { return main + hotbar }
            return slot < start + 27 ? hotbar : main
        case .dispenser: return []
        }
    }

    private mutating func takeOutput(_ stack: ItemStack, result: inout ContainerClickResult) {
        result.outputs.append(stack)
        guard let width = kind.craftingWidth else { return }
        var grid = CraftingGrid(width: width, height: width)
        grid.slots = Array(slots[1..<(1 + width * width)])
        _ = grid.craft()
        for index in grid.slots.indices { slots[index + 1] = grid.slots[index] }
        slots[0] = grid.result
    }

    private mutating func refreshRecipe() {
        guard let width = kind.craftingWidth else { return }
        var grid = CraftingGrid(width: width, height: width)
        grid.slots = Array(slots[1..<(1 + width * width)])
        slots[0] = grid.result
    }
}
