import Foundation
import MinecraftCore

struct MultiplayerClickSnapshot {
    let playerSlots: [ItemStack?]
    let windowSlots: [ItemStack?]
    let cursor: ItemStack?
}

extension GameSession {
    func receiveMultiplayerInventory(_ packet: BetaPacket) -> Bool {
        guard let state = multiplayer else { return false }
        switch packet {
        case .openWindow(let id, let type, let title, let count):
            guard id > 0, (0...3).contains(type), count >= 0 else { return true }
            closeMultiplayerWindow(send: state.windowID != 0)
            state.windowID = id
            state.windowType = type
            state.windowTitle = title
            state.containerSlotCount = type == 1 ? 10 : (type == 2 ? 3 : Int(count))
            state.windowSlots = Array(repeating: nil, count: state.containerSlotCount + 36)
            for slot in 0..<36 {
                state.windowSlots[state.containerSlotCount + slot] =
                    inventory.slots[slot < 27 ? slot + 9 : slot - 27]
            }
            inventoryOpen = true
            resetInput()
        case .closeWindow(let id):
            if id == state.windowID { closeMultiplayerWindow(send: false) }
        case .windowItems(let id, let items):
            if id == 0 {
                state.playerWindow = Array(items.prefix(45)).map { $0?.stack }
                if state.playerWindow.count < 45 {
                    state.playerWindow += Array(repeating: nil, count: 45 - state.playerWindow.count)
                }
                synchronizePlayerWindow()
            } else if id == state.windowID {
                state.windowSlots = Array(items.prefix(256)).map { $0?.stack }
                synchronizeActiveWindow()
            }
        case .setSlot(let id, let slot, let item):
            if id == -1 && slot == -1 {
                cursor = item?.stack
            } else if id == 0 && state.playerWindow.indices.contains(Int(slot)) {
                state.playerWindow[Int(slot)] = item?.stack
                synchronizePlayerWindow()
            } else if id == state.windowID && state.windowSlots.indices.contains(Int(slot)) {
                state.windowSlots[Int(slot)] = item?.stack
                synchronizeActiveWindow()
            }
        case .windowProperty(let id, let property, let value):
            if id == state.windowID && state.windowType == 2 && property == 0 {
                furnaceProgress = Double(value) / 200
            }
        case .transaction(let window, let id, let accepted):
            guard window == state.windowID else { return true }
            if !accepted, let snapshot = state.pendingClicks[id] {
                state.playerWindow = snapshot.playerSlots
                state.windowSlots = snapshot.windowSlots
                cursor = snapshot.cursor
                synchronizePlayerWindow()
                synchronizeActiveWindow()
                state.pendingClicks.removeAll()
                state.client?.send(.transaction(window: window, id: id, accepted: true))
            } else {
                state.pendingClicks.removeValue(forKey: id)
            }
        default: return false
        }
        refreshHUD()
        return true
    }

    func synchronizePlayerWindow() {
        guard let state = multiplayer else { return }
        for slot in 9..<45 {
            inventory.slots[slot < 36 ? slot : slot - 36] = state.playerWindow[slot]
        }
        for slot in 5..<9 { inventory.armor[8 - slot] = state.playerWindow[slot] }
        if state.windowID == 0 {
            crafting = CraftingGrid()
            for slot in 0..<4 { crafting.slots[slot] = state.playerWindow[slot + 1] }
        } else {
            for slot in state.containerSlotCount..<state.windowSlots.count {
                let playerSlot = slot - state.containerSlotCount
                guard playerSlot < 36 else { break }
                state.windowSlots[slot] = inventory.slots[playerSlot < 27 ? playerSlot + 9 : playerSlot - 27]
            }
        }
    }

    func synchronizeActiveWindow() {
        guard let state = multiplayer, state.windowID != 0 else { return }
        for slot in state.containerSlotCount..<state.windowSlots.count {
            let playerSlot = slot - state.containerSlotCount
            guard playerSlot < 36 else { break }
            let index = playerSlot < 27 ? playerSlot + 9 : playerSlot - 27
            inventory.slots[index] = state.windowSlots[slot]
            state.playerWindow[index < 9 ? index + 36 : index] = state.windowSlots[slot]
        }
        if state.windowType == 1 {
            crafting = CraftingGrid(width: 3, height: 3)
            for slot in 0..<9 where state.windowSlots.indices.contains(slot + 1) {
                crafting.slots[slot] = state.windowSlots[slot + 1]
            }
        }
    }

    func refreshMultiplayerHUD() {
        guard let state = multiplayer else { return }
        furnaceOpen = state.windowID != 0 && state.windowType == 2
        containerTitle = state.windowID != 0 ? state.windowTitle : ""
        if state.windowID != 0 && (state.windowType == 0 || state.windowType == 3) {
            containerItems = Array(state.windowSlots.prefix(state.containerSlotCount))
        } else {
            containerItems = []
        }
        if furnaceOpen { furnaceItems = Array(state.windowSlots.prefix(3)) }
        craftingWidth = state.windowID != 0 && state.windowType == 1 ? 3 : 2
        let slots = state.windowID == 0 ? state.playerWindow : state.windowSlots
        if !furnaceOpen && containerItems.isEmpty {
            craftingItems = Array(slots.dropFirst().prefix(craftingWidth * craftingWidth))
            craftingResultItem = slots.first ?? nil
        }
    }

    func toggleMultiplayerInventory() {
        if inventoryOpen {
            closeMultiplayerWindow(send: true)
        } else {
            inventoryOpen = true
            resetInput()
            refreshHUD()
        }
    }

    func closeMultiplayerWindow(send: Bool) {
        guard let state = multiplayer else { return }
        if send { state.client?.send(.closeWindow(state.windowID)) }
        state.windowID = 0
        state.windowType = -1
        state.containerSlotCount = 0
        state.windowTitle = ""
        state.windowSlots = []
        state.pendingClicks.removeAll()
        inventoryOpen = false
        furnaceOpen = false
        furnaceProgress = 0
        containerItems = []
        containerTitle = ""
        cursor = nil
        synchronizePlayerWindow()
        resetInput()
        refreshHUD()
    }

    func multiplayerInventoryClick(slot: Int, secondary: Bool) {
        guard let state = multiplayer, (0..<36).contains(slot) else { return }
        let wireSlot =
            state.windowID == 0
            ? (slot < 9 ? slot + 36 : slot)
            : state.containerSlotCount + (slot < 9 ? slot + 27 : slot - 9)
        multiplayerWindowClick(slot: wireSlot, secondary: secondary)
    }

    func multiplayerCraftingClick(slot: Int, secondary: Bool) {
        guard (0..<(craftingWidth * craftingWidth)).contains(slot) else { return }
        multiplayerWindowClick(slot: slot + 1, secondary: secondary)
    }

    func multiplayerWindowClick(slot: Int, secondary: Bool, shift: Bool = false) {
        guard let state = multiplayer, inventoryOpen, state.pendingClicks.count < 64 else { return }
        let slots = state.windowID == 0 ? state.playerWindow : state.windowSlots
        let kind: ContainerKind
        if state.windowID == 0 {
            kind = .player
        } else {
            switch state.windowType {
            case 1: kind = .workbench
            case 2: kind = .furnace
            case 3: kind = .dispenser
            default: kind = .chest(state.containerSlotCount)
            }
        }
        guard slots.indices.contains(slot) || slot == -999 else { return }
        let snapshot = MultiplayerClickSnapshot(
            playerSlots: state.playerWindow, windowSlots: state.windowSlots, cursor: cursor)
        var container = ContainerInventory(kind: kind, slots: slots, cursor: cursor)
        let result = container.click(slot: slot, secondary: secondary, shift: shift)
        cursor = container.cursor
        if state.windowID == 0 {
            state.playerWindow = container.slots
            synchronizePlayerWindow()
        } else {
            state.windowSlots = container.slots
            synchronizeActiveWindow()
        }
        state.transactionID &+= 1
        state.pendingClicks[state.transactionID] = snapshot
        state.client?.send(
            .windowClick(
                window: state.windowID, slot: Int16(slot), button: secondary ? 1 : 0,
                transaction: state.transactionID, shift: shift, item: result.previous.map(BetaSlot.init)))
        refreshHUD()
    }
}
