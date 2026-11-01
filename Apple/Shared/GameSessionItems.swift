import Foundation
import MinecraftCore

extension GameSession {
    func applyItemAction(_ result: ItemActionResult, itemID: UInt16? = nil, countUse: Bool = false) {
        if result.handled && countUse, let itemID { notifyAchievements(statistics.recordUse(itemID: itemID)) }
        dispatch(result.events)
        for position in result.changedPositions {
            dispatch(blockSimulation.blockChanged(at: position, world: &world, time: worldTime))
        }
    }

    func tickItemState() {
        if !isMultiplayer { maps.update(world: world, player: player, inventory: &inventory, spawn: spawn) }
        compassDial.tickCompass(
            position: player.position, yaw: camera.yaw, spawn: spawn, dimension: world.dimension,
            random: &dialRandom)
        clockDial.tickClock(
            celestialAngle: weather.celestialAngle(time: worldTime, dimension: world.dimension),
            dimension: world.dimension, random: &dialRandom)
    }
}
