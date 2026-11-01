import Foundation

public struct ItemActionResult: Sendable {
    public var handled: Bool
    public var events: [BlockEvent]
    public var changedPositions: [BlockPosition]

    public init(handled: Bool = false, events: [BlockEvent] = [], changedPositions: [BlockPosition] = []) {
        self.handled = handled
        self.events = events
        self.changedPositions = changedPositions
    }
}

public struct ItemActions: Sendable {
    private var random: JavaRandom

    public init(seed: Int64) { random = JavaRandom(seed: seed) }

    /// Call after block activation and item-on-block use have declined the action.
    public mutating func useInAir(
        world: inout BlockWorld, player: inout Player, inventory: inout PlayerInventory,
        entities: inout EntitySimulation, yaw: Float, pitch: Float
    ) -> ItemActionResult {
        guard let held = inventory.selectedStack, held.count > 0 else { return ItemActionResult() }
        switch held.id {
        case 261:
            guard
                let slot = inventory.slots.firstIndex(where: {
                    $0.map { $0.id == 262 && $0.count > 0 } ?? false
                })
            else {
                return ItemActionResult()
            }
            _ = inventory.remove(from: slot)
            let sound = bowSound(at: player.position, bow: true)
            entities.shootFromPlayer(kind: "arrow", player: player, yaw: yaw, pitch: pitch)
            return ItemActionResult(handled: true, events: [sound])
        case 332, 344:
            _ = inventory.removeSelected()
            let sound = bowSound(at: player.position, bow: false)
            entities.shootFromPlayer(
                kind: held.id == 332 ? "snowball" : "egg", player: player, yaw: yaw, pitch: pitch)
            return ItemActionResult(handled: true, events: [sound])
        case 333:
            let origin = player.position + SIMD3(0, 1.62, 0)
            guard
                let hit = BlockRaycast.hit(
                    in: world, origin: origin,
                    direction: BetaItemMath.rayDirection(yaw: yaw, pitch: pitch), includeLiquids: true)
            else {
                return ItemActionResult()
            }
            let y = hit.position.y - (world[hit.position] == .snowLayer ? 1 : 0)
            let id = entities.spawn(
                kind: "boat",
                position: SIMD3(
                    Double(hit.position.x) + 0.5,
                    Double(y) + 1, Double(hit.position.z) + 0.5))
            entities.update(id: id) {
                $0.yaw = 0
                $0.pitch = 0
            }
            _ = inventory.removeSelected()
            return ItemActionResult(handled: true)
        case 346:
            if entities.entities.contains(where: {
                $0.kind == "fishingHook" && $0.projectileOwner == 0 && $0.health > 0
            }) {
                inventory.damageSelected(by: entities.retrieveFishingHook(player: player))
                return ItemActionResult(handled: true)
            }
            let originalYaw = (yaw * 180 / Float(Double.pi) + 180) / 180 * Float(Double.pi)
            let origin =
                player.position
                + SIMD3(
                    -Double(BetaItemMath.cosine(originalYaw) * 0.16),
                    1.62 - Double(Float(0.1)), -Double(BetaItemMath.sine(originalYaw) * 0.16))
            entities.castFishingHook(
                origin: origin, direction: BetaItemMath.projectileDirection(yaw: yaw, pitch: pitch))
            return ItemActionResult(handled: true, events: [bowSound(at: player.position, bow: false)])
        case 325, 326, 327:
            let origin = player.position + SIMD3(0, 1.62, 0)
            guard
                let hit = BlockRaycast.hit(
                    in: world, origin: origin,
                    direction: BetaItemMath.rayDirection(yaw: yaw, pitch: pitch),
                    includeLiquids: held.id == 325)
            else {
                return ItemActionResult()
            }
            let result = BlockInteractions.use(
                hit: hit, holding: held, yaw: yaw, playerBounds: player.bounds,
                world: &world, health: player.health)
            return apply(result, player: &player, inventory: &inventory)
        case 335:
            guard
                BlockRaycast.hit(
                    in: world, origin: player.position + SIMD3(0, 1.62, 0),
                    direction: BetaItemMath.rayDirection(yaw: yaw, pitch: pitch)) != nil
            else {
                return ItemActionResult()
            }
            inventory.slots[inventory.selectedHotbar] = ItemStack(id: 325)
            return ItemActionResult(handled: true)
        default:
            return apply(
                BlockInteractions.useInAir(holding: held, health: player.health),
                player: &player, inventory: &inventory)
        }
    }

    public mutating func useOnBlock(
        hit: BlockHit, world: inout BlockWorld, player: inout Player, inventory: inout PlayerInventory,
        entities: inout EntitySimulation, yaw: Float, pitch: Float
    ) -> ItemActionResult {
        guard let held = inventory.selectedStack, held.count > 0 else { return ItemActionResult() }
        switch held.id {
        case 328, 342, 343:
            guard let kind = world[hit.position], [.rail, .poweredRail, .detectorRail].contains(kind) else {
                return ItemActionResult()
            }
            let type: UInt8 = held.id == 342 ? 1 : (held.id == 343 ? 2 : 0)
            let id = entities.spawn(kind: "minecart", position: hit.position.center, metadata: type)
            entities.update(id: id) {
                $0.yaw = 0
                $0.pitch = 0
            }
            _ = inventory.removeSelected()
            return ItemActionResult(handled: true)
        case 321:
            guard hit.face.y == 0 else { return ItemActionResult() }
            if entities.placePainting(at: hit.position, facing: hit.face, world: world) {
                _ = inventory.removeSelected()
            }
            return ItemActionResult(handled: true)
        default: return ItemActionResult()
        }
    }

    private mutating func bowSound(at position: SIMD3<Double>, bow: Bool) -> BlockEvent {
        .sound(
            name: "random.bow", position: position, volume: bow ? 1 : 0.5,
            pitch: (bow ? 1 : 0.4) / (random.nextFloat() * 0.4 + 0.8))
    }

    private func apply(_ result: BlockUseResult, player: inout Player, inventory: inout PlayerInventory)
        -> ItemActionResult
    {
        guard result.handled else { return ItemActionResult() }
        if result.replaceHeldStack {
            inventory.slots[inventory.selectedHotbar] = result.replacement
        } else if result.consumed > 0 {
            _ = inventory.removeSelected(count: result.consumed)
        }
        if result.durabilityDamage > 0 { inventory.damageSelected(by: result.durabilityDamage) }
        if result.healthRestored > 0 { player.heal(result.healthRestored) }
        return ItemActionResult(
            handled: true, events: result.events, changedPositions: result.changedPositions)
    }
}

enum BetaItemMath {
    private static let sines: [Float] = (0..<65536).map { Float(sin(Double($0) * .pi * 2 / 65536)) }
    static func sine(_ angle: Float) -> Float { sines[Int(angle * 10430.378) & 65535] }
    static func cosine(_ angle: Float) -> Float { sines[Int(angle * 10430.378 + 16384) & 65535] }
    static func rayDirection(yaw: Float, pitch: Float) -> SIMD3<Double> {
        let degrees = yaw * 180 / Float(Double.pi) + 180
        let yaw = -degrees * Float(Double.pi / 180) - Float(Double.pi)
        let pitch = pitch * 180 / Float(Double.pi) * Float(Double.pi / 180)
        let horizontal = -cosine(pitch)
        return SIMD3(Double(sine(yaw) * horizontal), Double(sine(pitch)), Double(cosine(yaw) * horizontal))
    }
    static func projectileDirection(yaw: Float, pitch: Float) -> SIMD3<Double> {
        let yaw = (yaw * 180 / Float(Double.pi) + 180) / 180 * Float(Double.pi)
        let pitch = -pitch * 180 / Float(Double.pi) / 180 * Float(Double.pi)
        return SIMD3(
            Double(-sine(yaw) * cosine(pitch) * 0.4), Double(-sine(pitch) * 0.4),
            Double(cosine(yaw) * cosine(pitch) * 0.4))
    }
}
