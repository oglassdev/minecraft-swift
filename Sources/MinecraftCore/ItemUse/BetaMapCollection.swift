import Foundation

public struct BetaMapCollection: Equatable, Sendable {
    public private(set) var maps: [Int16: BetaMapData]
    public private(set) var idCounts: [String: Int16]

    public init(maps: [Int16: BetaMapData] = [:], idCounts: [String: Int16] = [:]) {
        self.maps = maps
        self.idCounts = idCounts
    }

    public subscript(id: Int16) -> BetaMapData? { maps[id] }

    public mutating func craft(at position: SIMD3<Double>, dimension: Int8) -> ItemStack {
        let id = allocate()
        maps[id] = BetaMapData(
            id: id, centerX: Int32(floor(position.x)), centerZ: Int32(floor(position.z)),
            dimension: dimension)
        return ItemStack(id: 358, damage: UInt16(bitPattern: id))
    }

    public mutating func update(
        world: BlockWorld, player: Player, inventory: inout PlayerInventory, spawn: BlockPosition
    ) {
        for slot in inventory.slots.indices {
            guard var stack = inventory.slots[slot], stack.id == 358 else { continue }
            var id = Int16(bitPattern: stack.damage)
            if maps[id] == nil {
                id = allocate()
                stack.damage = UInt16(bitPattern: id)
                inventory.slots[slot] = stack
                maps[id] = BetaMapData(
                    id: id, centerX: Int32(spawn.x), centerZ: Int32(spawn.z), dimension: world.dimension)
            }
            if slot == inventory.selectedHotbar { maps[id]?.update(world: world, position: player.position) }
        }
    }

    public mutating func applyNetwork(id: Int16, bytes: [UInt8]) {
        if maps[id] == nil { maps[id] = BetaMapData(id: id, centerX: 0, centerZ: 0, dimension: 0) }
        maps[id]?.applyNetwork(bytes)
    }

    private mutating func allocate() -> Int16 {
        let id = idCounts["map"].map { $0 &+ 1 } ?? 0
        idCounts["map"] = id
        return id
    }
}
