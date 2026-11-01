import Foundation
import MinecraftCore

extension GameSession {
    func applyItemAction(_ result: ItemActionResult, itemID: UInt16? = nil, countUse: Bool = false) {
        if result.handled && countUse, let itemID { notifyAchievements(statistics.recordUse(itemID: itemID)) }
        dispatch(result.events)
        for position in result.changedPositions {
            notifyBlockChanged(at: position)
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

extension GameSession {
    func notifyBlockChanged(at position: BlockPosition, previousState: BlockState?) {
        let events = blockSimulation.withWorldRandom(&worldTickState.random) {
            $0.blockChanged(at: position, previousState: previousState, world: &world, time: worldTime)
        }
        dispatch(events)
    }

    func notifyBlockChanged(at position: BlockPosition) {
        let events = blockSimulation.withWorldRandom(&worldTickState.random) {
            $0.blockChanged(at: position, world: &world, time: worldTime)
        }
        dispatch(events)
    }
}
