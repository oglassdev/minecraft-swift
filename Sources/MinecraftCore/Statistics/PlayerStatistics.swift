import Foundation

public enum CraftingSource: Sendable { case crafting, furnace }

public enum TravelMode: Equatable, Sendable {
    case walking, swimming, diving, climbing, flying, minecart, boat, pig, none
}

public struct PlayerStatistics: Sendable {
    public private(set) var values: [Int: Int]
    public private(set) var pendingChanges: [Int: Int]
    private var minecartOrigin: BlockPosition?

    public init() {
        values = [:]
        pendingChanges = [:]
    }

    init(baseline: [Int: Int], pending: [Int: Int]) {
        values = baseline
        pendingChanges = pending
        for (id, count) in pending { values[id] = Self.add(values[id] ?? 0, count) }
    }

    public func value(for id: Int) -> Int { values[id] ?? 0 }
    public func isUnlocked(_ id: Int) -> Bool { values[id] != nil }
    public func canUnlock(_ achievement: AchievementDefinition) -> Bool {
        achievement.parentID.map { isUnlocked($0) } ?? true
    }
    public var unlockedAchievements: [AchievementDefinition] {
        Achievements.all.filter { isUnlocked($0.id) }
    }

    @discardableResult
    public mutating func increment(_ id: Int, by amount: Int = 1) -> [AchievementDefinition] {
        guard let definition = StatisticRegistry.definition(for: id) else { return [] }
        var unlocked: [AchievementDefinition] = []
        if definition.category == .achievement, let achievement = Achievements.definition(for: id) {
            guard canUnlock(achievement) else { return [] }
            if !isUnlocked(id) { unlocked = [achievement] }
        }
        values[id] = Self.add(values[id] ?? 0, amount)
        pendingChanges[id] = Self.add(pendingChanges[id] ?? 0, amount)
        return unlocked
    }

    @discardableResult
    public mutating func recordMine(_ block: BlockKind, count: Int = 1) -> [AchievementDefinition] {
        record(StatisticRegistry.mine(blockID: UInt16(block.rawValue)), count: count)
    }

    @discardableResult
    public mutating func recordCraft(_ stack: ItemStack, source: CraftingSource = .crafting)
        -> [AchievementDefinition]
    {
        var unlocked = record(StatisticRegistry.craft(itemID: stack.id), count: stack.count)
        let achievement: Int?
        switch source {
        case .furnace:
            switch stack.id {
            case 265: achievement = Achievements.acquireHardware
            case 350: achievement = Achievements.deliciousFish
            default: achievement = nil
            }
        case .crafting:
            switch stack.id {
            case 58: achievement = Achievements.benchmarking
            case 270: achievement = Achievements.timeToMine
            case 61: achievement = Achievements.hotTopic
            case 290: achievement = Achievements.timeToFarm
            case 297: achievement = Achievements.bakeBread
            case 354: achievement = Achievements.theLie
            case 274: achievement = Achievements.gettingAnUpgrade
            case 268: achievement = Achievements.timeToStrike
            default: achievement = nil
            }
        }
        if let achievement { unlocked += increment(achievement) }
        return unlocked
    }

    @discardableResult
    public mutating func recordUse(itemID: UInt16, count: Int = 1) -> [AchievementDefinition] {
        record(StatisticRegistry.use(itemID: itemID), count: count)
    }

    @discardableResult
    public mutating func recordBreak(itemID: UInt16) -> [AchievementDefinition] {
        record(StatisticRegistry.depleted(itemID: itemID), count: 1)
    }

    @discardableResult
    public mutating func recordPickup(_ stack: ItemStack) -> [AchievementDefinition] {
        guard stack.count > 0 else { return [] }
        switch stack.id {
        case 17: return increment(Achievements.gettingWood)
        case 334: return increment(Achievements.cowTipper)
        default: return []
        }
    }

    @discardableResult
    public mutating func recordKill(kind: String, isPlayer: Bool = false) -> [AchievementDefinition] {
        if isPlayer { return increment(2024) }
        var unlocked = increment(2023)
        if ["creeper", "skeleton", "spider", "giant", "zombie", "pigZombie"].contains(
            GameEntity.canonicalKind(kind))
        {
            unlocked += increment(Achievements.monsterHunter)
        }
        return unlocked
    }

    @discardableResult
    public mutating func recordInventoryOpen() -> [AchievementDefinition] {
        increment(Achievements.takingInventory)
    }

    @discardableResult
    public mutating func recordTravel(
        from: SIMD3<Double>, to: SIMD3<Double>, mode: TravelMode
    ) -> [AchievementDefinition] {
        guard [from.x, from.y, from.z, to.x, to.y, to.z].allSatisfy(\.isFinite) else { return [] }
        let change = to - from
        let horizontal = sqrt(change.x * change.x + change.z * change.z)
        let total = sqrt(change.x * change.x + change.y * change.y + change.z * change.z)
        if mode != .minecart && mode != .boat && mode != .pig { minecartOrigin = nil }
        let id: Int
        let centimeters: Int
        switch mode {
        case .walking:
            id = 2000
            centimeters = Self.centimeters(horizontal)
        case .swimming:
            id = 2001
            centimeters = Self.centimeters(horizontal)
        case .diving:
            id = 2005
            centimeters = Self.centimeters(total)
        case .climbing:
            guard change.y > 0 else { return [] }
            return increment(2003, by: Int(floor(change.y * 100 + 0.5)))
        case .flying:
            id = 2004
            centimeters = Self.centimeters(horizontal)
            if centimeters <= 25 { return [] }
        case .minecart:
            id = 2006
            centimeters = Self.centimeters(total)
        case .boat:
            id = 2007
            centimeters = Self.centimeters(total)
        case .pig:
            id = 2008
            centimeters = Self.centimeters(total)
        case .none: return []
        }
        guard centimeters > 0 else { return [] }
        var unlocked = increment(id, by: centimeters)
        if mode == .minecart {
            let position = BlockPosition(Int(floor(to.x)), Int(floor(to.y)), Int(floor(to.z)))
            if let origin = minecartOrigin {
                let dx = Double(position.x - origin.x)
                let dy = Double(position.y - origin.y)
                let dz = Double(position.z - origin.z)
                if sqrt(dx * dx + dy * dy + dz * dz) >= 1000 { unlocked += increment(Achievements.onARail) }
            } else {
                minecartOrigin = position
            }
        }
        return unlocked
    }

    public mutating func recordTick(riding: Bool = false) {
        increment(1100)
        if !riding { minecartOrigin = nil }
    }
    public mutating func recordJump() { increment(2010) }
    public mutating func recordDrop() { increment(2011) }
    public mutating func recordDamageDealt(_ amount: Int) { increment(2020, by: amount) }
    public mutating func recordDamageTaken(_ amount: Int) { increment(2021, by: amount) }
    public mutating func recordDeath() { increment(2022) }
    public mutating func recordFishCaught() { increment(2025) }
    public mutating func recordFall(distance: Float) {
        if distance >= 2 { increment(2002, by: Int(floor(Double(distance * 100) + 0.5))) }
    }
    @discardableResult
    public mutating func recordPigFall(distance: Float) -> [AchievementDefinition] {
        distance > 5 ? increment(Achievements.whenPigsFly) : []
    }

    private mutating func record(_ definition: StatisticDefinition?, count: Int) -> [AchievementDefinition] {
        guard let definition else { return [] }
        return increment(definition.id, by: count)
    }

    private static func centimeters(_ distance: Double) -> Int {
        let value = Float(distance) * 100
        if value >= Float(Int32.max) { return Int(Int32.max) }
        return Int(floor(Double(value) + 0.5))
    }

    private static func add(_ lhs: Int, _ rhs: Int) -> Int {
        Int(Int32(truncatingIfNeeded: lhs &+ rhs))
    }
}
