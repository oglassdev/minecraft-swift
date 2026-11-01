import Foundation

public enum StatisticCategory: String, Codable, Sendable {
    case general, achievement, mine, craft, use, depleted
}

public struct StatisticDefinition: Identifiable, Equatable, Sendable {
    public let id: Int
    public let key: String
    public let name: String
    public let checksumKey: String
    public let category: StatisticCategory
    public let itemID: UInt16?
    public let isIndependent: Bool
    public let isListed: Bool

    public func formatted(_ value: Int) -> String {
        if id == 1100 {
            let seconds = Double(value) / 20
            for (scale, unit) in [(31_536_000.0, "y"), (86_400.0, "d"), (3_600.0, "h"), (60.0, "m")] {
                if seconds / scale > 0.5 { return Self.decimal(seconds / scale) + " " + unit }
            }
            return String(seconds) + " s"
        }
        if (2000...2008).contains(id) {
            let meters = Double(value) / 100
            if meters / 1000 > 0.5 { return Self.decimal(meters / 1000) + " km" }
            if meters > 0.5 { return Self.decimal(meters) + " m" }
            return String(value) + " cm"
        }
        let digits = Array(String(value).reversed())
        return String(
            digits.enumerated().flatMap { index, digit -> [Character] in
                index > 0 && index % 3 == 0 && digit != "-" ? [",", digit] : [digit]
            }.reversed())
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

public enum StatisticRegistry {
    public static let registered = BetaStatisticsData.definitions
    public static let all = registered.filter(\.isListed)
    public static let general = all.filter { $0.category == .general }
    public static let blocks = all.filter { $0.category == .mine }
    public static let items = all.filter { $0.category == .use && ($0.itemID ?? 0) >= 256 }
    private static let byID = Dictionary(uniqueKeysWithValues: registered.map { ($0.id, $0) })

    public static func definition(for id: Int) -> StatisticDefinition? { byID[id] }
    public static func mine(blockID: UInt16) -> StatisticDefinition? { mapped(category: 0, itemID: blockID) }
    public static func craft(itemID: UInt16) -> StatisticDefinition? { mapped(category: 1, itemID: itemID) }
    public static func use(itemID: UInt16) -> StatisticDefinition? { mapped(category: 2, itemID: itemID) }
    public static func depleted(itemID: UInt16) -> StatisticDefinition? {
        mapped(category: 3, itemID: itemID)
    }

    private static func mapped(category: Int, itemID: UInt16) -> StatisticDefinition? {
        BetaStatisticsData.aliases[category][itemID].flatMap { byID[$0] }
    }
}

public struct AchievementDefinition: Identifiable, Equatable, Sendable {
    public let id: Int
    public let key: String
    public let title: String
    public let description: String
    public let column: Int
    public let row: Int
    public let parentID: Int?
    public let icon: ItemStack
    public let isSpecial: Bool
}

public enum Achievements {
    public static let all = BetaStatisticsData.achievements
    public static let takingInventory = 5_242_880
    public static let gettingWood = 5_242_881
    public static let benchmarking = 5_242_882
    public static let timeToMine = 5_242_883
    public static let hotTopic = 5_242_884
    public static let acquireHardware = 5_242_885
    public static let timeToFarm = 5_242_886
    public static let bakeBread = 5_242_887
    public static let theLie = 5_242_888
    public static let gettingAnUpgrade = 5_242_889
    public static let deliciousFish = 5_242_890
    public static let onARail = 5_242_891
    public static let timeToStrike = 5_242_892
    public static let monsterHunter = 5_242_893
    public static let cowTipper = 5_242_894
    public static let whenPigsFly = 5_242_895
    public static func definition(for id: Int) -> AchievementDefinition? { all.first { $0.id == id } }
}
