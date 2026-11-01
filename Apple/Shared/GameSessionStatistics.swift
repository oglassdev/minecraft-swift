import Foundation
import MinecraftCore

extension GameSession {
    func notifyAchievements(_ achievements: [AchievementDefinition]) {
        if let achievement = achievements.last {
            achievementNotice = achievement.title
            achievementNoticeTicks = 100
        }
    }

    func tickAchievementNotice() {
        if achievementNoticeTicks > 0 {
            achievementNoticeTicks -= 1
        } else if achievementNotice != nil {
            achievementNotice = nil
        }
    }

    func saveStatistics() {
        do {
            try StatisticsStorage(directory: gameDirectory.appendingPathComponent("stats")).save(statistics)
        } catch { errorMessage = "Could not save statistics: \(error.localizedDescription)" }
    }

    func recordStatisticsTick(
        previous: SIMD3<Double>, healthBefore: Int, inventoryBefore: PlayerInventory, groundedBefore: Bool
    ) {
        let riding = entitySimulation.playerRidingEntityID.flatMap { id in entities.first { $0.id == id } }
        statistics.recordTick(riding: riding != nil)
        let mode: TravelMode
        if let riding {
            switch riding.kind {
            case "minecart": mode = .minecart
            case "boat": mode = .boat
            default: mode = .pig
            }
        } else if player.isInWater {
            mode = .swimming
        } else if player.onGround {
            mode = .walking
        } else {
            mode = .flying
        }
        notifyAchievements(statistics.recordTravel(from: previous, to: player.position, mode: mode))
        if groundedBefore && pressed.contains(.jump) && player.velocity.y > 0 { statistics.recordJump() }
        let damage = player.damageTakenTotal - recordedDamageTaken
        if damage > 0 { statistics.recordDamageTaken(damage) }
        recordedDamageTaken = player.damageTakenTotal
        statisticsFallDistance += max(0, Float(previous.y - player.position.y))
        if player.onGround {
            statistics.recordFall(distance: statisticsFallDistance)
            statisticsFallDistance = 0
        } else if player.isInWater || player.velocity.y > 0 {
            statisticsFallDistance = 0
        }
        for id in [UInt16(17), 334] {
            let gained = count(of: id, in: inventory) - count(of: id, in: inventoryBefore)
            if gained > 0 { notifyAchievements(statistics.recordPickup(ItemStack(id: id, count: gained))) }
        }
        tickAchievementNotice()
    }

    private func count(of id: UInt16, in inventory: PlayerInventory) -> Int {
        inventory.slots.reduce(0) { total, slot in
            guard let slot, slot.id == id else { return total }
            return total + slot.count
        }
    }
}
