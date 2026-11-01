import Foundation

struct EntityCollisionBody: Sendable {
    var id: Int64
    var bounds: AxisAlignedBox
    var isBoat: Bool
    var isLiving: Bool
    var isVehicle: Bool
    var active: Bool
    var riderID: Int64?

    init(_ entity: borrowing GameEntity) {
        id = entity.id
        bounds = entity.bounds
        isBoat = entity.kind == "boat"
        isLiving = entity.isLiving
        isVehicle = isBoat || entity.kind == "minecart"
        active =
            entity.kind != "lightningBolt" && (entity.health > 0 || (isLiving && entity.deathTicks <= 20))
        riderID = entity.health > 0 ? entity.riderID : nil
    }
}

struct EntitySpatialIndex: Sendable {
    private struct Cells: Equatable {
        let minX: Int
        let maxX: Int
        let minZ: Int
        let maxZ: Int

        init(_ bounds: AxisAlignedBox) {
            minX = Int(floor(bounds.min.x / 8))
            maxX = Int(floor(bounds.max.x / 8))
            minZ = Int(floor(bounds.min.z / 8))
            maxZ = Int(floor(bounds.max.z / 8))
        }

        func forEachCell(_ body: (Int) -> Void) {
            for x in minX...maxX { for z in minZ...maxZ { body(x << 32 | z & 0xFFFF_FFFF) } }
        }
    }

    private(set) var bodies: [EntityCollisionBody] = []
    private(set) var indices: [Int64: Int] = [:]
    private(set) var vehicles: [Int64: Int] = [:]
    private var buckets: [Int: [Int]] = [:]

    init(_ entities: borrowing [GameEntity]) {
        bodies.reserveCapacity(entities.count)
        indices.reserveCapacity(entities.count)
        for index in entities.indices { append(EntityCollisionBody(entities[index])) }
    }

    mutating func append(_ body: EntityCollisionBody) {
        let index = bodies.count
        bodies.append(body)
        indices[body.id] = index
        if let rider = body.riderID, vehicles[rider] == nil { vehicles[rider] = index }
        Cells(body.bounds).forEachCell { buckets[$0, default: []].append(index) }
    }

    mutating func update(_ body: EntityCollisionBody, at index: Int) {
        let old = bodies[index]
        let oldCells = Cells(old.bounds)
        let newCells = Cells(body.bounds)
        if oldCells != newCells {
            oldCells.forEachCell { buckets[$0]?.removeAll { $0 == index } }
            newCells.forEachCell { buckets[$0, default: []].append(index) }
        }
        bodies[index] = body
        if old.riderID != body.riderID {
            if let rider = old.riderID, vehicles[rider] == index {
                vehicles[rider] = bodies.indices.first { bodies[$0].riderID == rider }
            }
            if let rider = body.riderID, index < (vehicles[rider] ?? Int.max) { vehicles[rider] = index }
        }
    }

    func candidates(intersecting bounds: AxisAlignedBox) -> [Int] {
        var candidates: [Int] = []
        Cells(bounds).forEachCell { candidates.append(contentsOf: buckets[$0] ?? []) }
        // Preserve entity order for collision impulses and targeting ties.
        candidates.sort()
        var previous = -1
        return candidates.filter { index in
            guard index != previous else { return false }
            previous = index
            return true
        }
    }
}

struct EntityCollisionView {
    var index: EntitySpatialIndex?
    var fallback: [GameEntity] = []
    var player: EntityCollisionBody?

    func boxes(movingID: Int64, vehicle: Bool, intersecting bounds: AxisAlignedBox) -> [AxisAlignedBox] {
        guard let index else {
            var result = EntityCollision.boxes(
                movingID: movingID, vehicle: vehicle, among: fallback, intersecting: bounds)
            if vehicle, let player, player.active, player.bounds.intersects(bounds) {
                result.append(player.bounds)
            }
            return result
        }
        var result: [AxisAlignedBox] = []
        for candidate in index.candidates(intersecting: bounds) {
            let body = index.bodies[candidate]
            guard body.id != movingID, body.active, body.bounds.intersects(bounds) else { continue }
            if body.isBoat { result.append(body.bounds) }
            if vehicle { result.append(body.bounds) }
        }
        if vehicle, let player, player.active, player.bounds.intersects(bounds) {
            result.append(player.bounds)
        }
        return result
    }
}

extension EntitySimulation {
    func collisionView(player: Player? = nil) -> EntityCollisionView {
        var body: EntityCollisionBody?
        if let player {
            var entity = GameEntity(id: 0, kind: "player", position: player.position)
            entity.health = player.health
            body = EntityCollisionBody(entity)
        }
        return EntityCollisionView(
            index: spatialIndex, fallback: spatialIndex == nil ? entities : [], player: body)
    }

    func entityArrayIndex(id: Int64) -> Int? {
        if let spatialIndex { return spatialIndex.indices[id] }
        return entities.indices.first { entities[$0].id == id }
    }

    func contactCandidates(in bounds: AxisAlignedBox) -> [Int] {
        spatialIndex?.candidates(intersecting: bounds) ?? Array(entities.indices)
    }

    mutating func refreshSpatialBody(at index: Int) {
        guard spatialIndex != nil else { return }
        spatialIndex?.update(EntityCollisionBody(entities[index]), at: index)
    }
}
