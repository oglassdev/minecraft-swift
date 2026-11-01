import Foundation

extension EntitySimulation {
    public func ridingEntityID(for riderID: Int64) -> Int64? {
        if let spatialIndex, let index = spatialIndex.vehicles[riderID] {
            return entities[index].id
        }
        guard spatialIndex == nil else { return nil }
        return entities.indices.first { entities[$0].riderID == riderID && entities[$0].health > 0 }
            .map { entities[$0].id }
    }

    public func mountedPosition(for riderID: Int64) -> SIMD3<Double>? {
        guard let vehicleID = ridingEntityID(for: riderID), let index = entityArrayIndex(id: vehicleID) else {
            return nil
        }
        let vehicle = entities[index]
        return Self.riderPosition(
            on: vehicle,
            isPlayer: riderID == 0
                || entityArrayIndex(id: riderID).map { entities[$0].kind == "player" } == true)
    }

    static func riderPosition(on vehicle: GameEntity, isPlayer: Bool) -> SIMD3<Double> {
        let centerOffset = ["boat", "minecart"].contains(vehicle.kind) ? vehicle.height / 2 : 0
        let ridingOffset =
            ["boat", "minecart"].contains(vehicle.kind)
            ? -Double(Float(0.3)) : vehicle.height * 0.75 - (vehicle.kind == "spider" ? 0.5 : 0)
        var position = vehicle.position + SIMD3(0, centerOffset + ridingOffset - (isPlayer ? 0.5 : 0), 0)
        if vehicle.kind == "boat" {
            let angle =
                Double(vehicle.vehicleYaw ?? ((vehicle.yaw + BetaMath.pi) * 180 / BetaMath.pi)) * .pi / 180
            position.x += cos(angle) * 0.4
            position.z += sin(angle) * 0.4
        }
        return position
    }

    public mutating func dismountPlayer(player: inout Player) {
        if let vehicle = entities.first(where: { $0.riderID == 0 }) {
            player.teleport(to: vehicle.position + SIMD3(0, vehicle.height, 0))
        }
        dismountPlayer()
        player.isMounted = false
    }

    func entityTickOrder(count: Int) -> [Int] {
        var parents: [Int64: Int] = [:]
        for index in 0..<count {
            if entities[index].health > 0, let rider = entities[index].riderID, parents[rider] == nil {
                parents[rider] = index
            }
        }
        guard !parents.isEmpty else { return Array(0..<count) }
        var result: [Int] = []
        var visiting: Set<Int> = []
        var visited: Set<Int> = []
        func visit(_ index: Int) {
            guard !visited.contains(index), visiting.insert(index).inserted else { return }
            if let parent = parents[entities[index].id] { visit(parent) }
            visiting.remove(index)
            visited.insert(index)
            result.append(index)
        }
        for index in 0..<count { visit(index) }
        return result
    }
}
