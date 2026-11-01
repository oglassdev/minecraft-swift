public struct ItemStack: Codable, Hashable, Sendable {
    public var id: UInt16
    public var count: Int
    public var damage: UInt16

    public init(id: UInt16, count: Int = 1, damage: UInt16 = 0) {
        self.id = id
        self.count = count
        self.damage = damage
    }

    public var definition: ItemDefinition? { ItemDefinition.definition(for: id) }
    public var name: String { definition?.name(damage: damage) ?? "Unknown item" }
    public var maximumStackSize: Int { definition?.maximumStackSize ?? 64 }
    public var isEmpty: Bool { count <= 0 }

    public func canStack(with other: Self) -> Bool {
        guard id == other.id, maximumStackSize > 1 else { return false }
        return definition?.hasSubtypes != true || damage == other.damage
    }

    /// Beta breaks a tool when its accumulated damage exceeds its maximum.
    @discardableResult
    public mutating func damageBy(_ amount: Int) -> Bool {
        guard let maximum = definition?.maximumDurability, maximum > 0, amount > 0, count > 0 else {
            return false
        }
        let total = Int(damage) + amount
        if total > maximum {
            count -= 1
            damage = 0
            return true
        }
        damage = UInt16(total)
        return false
    }
}
