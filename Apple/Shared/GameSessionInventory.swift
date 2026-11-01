import Foundation
import MinecraftCore

extension GameSession {
    var activeContainerKind: ContainerKind {
        if furnaceOpen { return .furnace }
        if currentContainerEntity != nil { return .chest(containerItems.count) }
        if !containerPositions.isEmpty {
            if let position = currentContainer, case .dispenser = world.blockEntity(at: position) {
                return .dispenser
            }
            return .chest(containerItems.count)
        }
        return craftingWidth == 3 ? .workbench : .player
    }

    func inventoryClick(slot: Int, secondary: Bool = false, shift: Bool = false) {
        guard (0..<36).contains(slot) else { return }
        let wire = activeContainerKind.playerStart + (slot < 9 ? slot + 27 : slot - 9)
        clickContainerSlot(wire, secondary: secondary, shift: shift)
    }

    func craftingClick(slot: Int, secondary: Bool = false, shift: Bool = false) {
        clickContainerSlot(slot + 1, secondary: secondary, shift: shift)
    }

    func armorClick(slot: Int, secondary: Bool = false, shift: Bool = false) {
        guard (0..<4).contains(slot) else { return }
        clickContainerSlot(slot + 5, secondary: secondary, shift: shift)
    }

    func containerClick(slot: Int, secondary: Bool = false, shift: Bool = false) {
        clickContainerSlot(slot, secondary: secondary, shift: shift)
    }

    func furnaceClick(slot: Int, secondary: Bool = false, shift: Bool = false) {
        clickContainerSlot(slot, secondary: secondary, shift: shift)
    }

    func takeCraftingResult(secondary: Bool = false, shift: Bool = false) {
        clickContainerSlot(0, secondary: secondary, shift: shift)
    }

    func inventoryOutsideClick(secondary: Bool = false) {
        clickContainerSlot(-999, secondary: secondary, shift: false)
    }

    func clickContainerSlot(_ slot: Int, secondary: Bool, shift: Bool) {
        if isMultiplayer {
            multiplayerWindowClick(slot: slot, secondary: secondary, shift: shift)
            return
        }
        let kind = activeContainerKind
        var contents: [ItemStack?]
        switch kind {
        case .player: contents = [crafting.result] + crafting.slots + inventory.armor.reversed()
        case .workbench: contents = [crafting.result] + crafting.slots
        case .furnace:
            guard let position = currentContainer,
                case .furnace(let furnace) = world.blockEntity(at: position)
            else { return }
            contents = [furnace.input, furnace.fuel, furnace.output]
        case .chest, .dispenser: contents = containerItems
        }
        contents += inventory.slots[9..<36] + inventory.slots[0..<9]
        var container = ContainerInventory(kind: kind, slots: contents, cursor: cursor)
        let result = container.click(slot: slot, secondary: secondary, shift: shift)
        for output in result.outputs {
            if output.id == 358 {
                let created = maps.craft(at: player.position, dimension: world.dimension)
                if !shift { container.cursor?.damage = created.damage }
            }
            notifyAchievements(
                statistics.recordCraft(output, source: kind == .furnace ? .furnace : .crafting))
        }
        cursor = container.cursor
        for index in 0..<36 {
            inventory.slots[index < 27 ? index + 9 : index - 27] = container.slots[kind.playerStart + index]
        }
        if let width = kind.craftingWidth {
            for index in 0..<(width * width) { crafting.slots[index] = container.slots[index + 1] }
            if kind == .player {
                for index in 0..<4 { inventory.armor[3 - index] = container.slots[index + 5] }
            }
        } else if kind == .furnace, let position = currentContainer,
            case .furnace(var furnace) = world.blockEntity(at: position)
        {
            furnace.input = container.slots[0]
            furnace.fuel = container.slots[1]
            furnace.output = container.slots[2]
            world.setBlockEntity(.furnace(furnace), at: position)
        } else if let id = currentContainerEntity {
            entitySimulation.update(id: id) { $0.contents = Array(container.slots.prefix(kind.playerStart)) }
        } else {
            var offset = 0
            for position in containerPositions {
                guard let tile = world.blockEntity(at: position) else { continue }
                let slots = Array(container.slots[offset..<(offset + tile.contents.count)])
                switch tile {
                case .chest: world.setBlockEntity(.chest(slots: slots), at: position)
                case .dispenser: world.setBlockEntity(.dispenser(slots: slots), at: position)
                default: break
                }
                offset += slots.count
            }
        }
        for stack in result.dropped { dropFromPlayer(stack) }
        refreshHUD()
    }

    func returnCursorAndCrafting() {
        guard !isMultiplayer else { return }
        for stack in ([cursor] + crafting.slots).compactMap({ $0 }) { dropFromPlayer(stack) }
        cursor = nil
        crafting = CraftingGrid(width: craftingWidth, height: craftingWidth)
    }

    func resizeCrafting(to width: Int) {
        if crafting.width != width {
            returnCursorAndCrafting()
            crafting = CraftingGrid(width: width, height: width)
        }
        craftingWidth = width
    }

    func dropFromPlayer(_ stack: ItemStack, scatter: Bool = false) {
        let velocity = PlayerDrop.velocity(
            yaw: camera.yaw, pitch: camera.pitch, random: &player.random, scatter: scatter)
        let origin = player.eyePositionDouble + SIMD3(0, -Double(Float(0.3)) + Double(Float(0.12)), 0)
        entitySimulation.drop(stack, at: origin, velocity: velocity, pickupDelay: 40)
        statistics.recordDrop()
    }
}

extension GameSession {
    func animateHotbarPickups(previous: [ItemStack?]) {
        for index in 0..<9 {
            guard let current = inventory.slots[index] else { continue }
            let old = previous.indices.contains(index) ? previous[index] : nil
            if old?.id != current.id || (old?.count ?? 0) < current.count { hotbarPickupTicks[index] = 5 }
        }
    }
}
