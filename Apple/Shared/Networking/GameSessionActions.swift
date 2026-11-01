import Foundation
import MinecraftCore

extension GameSession {
    func multiplayerPrimaryAction(isPressed: Bool) {
        guard let state = multiplayer else { return }
        guard isPressed else {
            miningPressed = false
            stopMultiplayerMining()
            return
        }
        guard !isLoading, !inventoryOpen, !isPaused, !chatOpen, !signEditorOpen, player.health > 0 else {
            return
        }
        if !miningPressed {
            state.client?.send(.animation(entityID: state.localEntityID, animation: 1))
            if let entity = entitySimulation.target(
                origin: player.eyePositionDouble, direction: SIMD3<Double>(camera.forward), reach: 4,
                world: world)
            {
                state.client?.send(
                    .useEntity(user: state.localEntityID, target: Int32(clamping: entity.id), attack: true))
                return
            }
        }
        miningPressed = true
    }

    func stopMultiplayerMining() {
        if let state = multiplayer, let position = state.digPosition {
            state.client?.send(.dig(status: 1, position: position, face: state.digFace))
            state.digPosition = nil
        }
        multiplayer?.awaitingDig = nil
        miningTarget = nil
        miningProgress = 0
    }

    func advanceMultiplayerMining() {
        guard let state = multiplayer else { return }
        if blockHitDelay > 0 {
            blockHitDelay -= 1
            return
        }
        guard miningPressed, !inventoryOpen, !isPaused, let hit = selectedBlock,
            hit.distance <= 5, let block = world.state(at: hit.position)
        else {
            stopMultiplayerMining()
            return
        }
        if let waiting = state.awaitingDig {
            if waiting == hit.position { return }
            state.awaitingDig = nil
        }
        if state.digPosition != hit.position {
            stopMultiplayerMining()
            state.digPosition = hit.position
            state.digFace = networkFace(hit.face)
            miningTarget = hit.position
            miningProgress = 0
            state.client?.send(.dig(status: 0, position: hit.position, face: state.digFace))
        }
        miningProgress += BlockMining.progressPerTick(
            for: block.kind, with: inventory.selectedStack,
            underwater: player.isInWater, onGround: player.onGround)
        if tickCount % 4 == 0 {
            state.client?.send(.animation(entityID: state.localEntityID, animation: 1))
            play(stepSound(block.kind), at: hit.position.vector, volume: 0.5)
        }
        if miningProgress >= 1 {
            state.client?.send(.dig(status: 2, position: hit.position, face: state.digFace))
            state.awaitingDig = hit.position
            state.digPosition = nil
            miningTarget = nil
            miningProgress = 0
            blockHitDelay = 5
        }
    }

    func multiplayerSecondaryAction() {
        guard let state = multiplayer, !isLoading, !isPaused, !inventoryOpen, !chatOpen, !signEditorOpen
        else { return }
        if let entity = entitySimulation.target(
            origin: player.eyePositionDouble, direction: SIMD3<Double>(camera.forward), reach: 4, world: world
        ) {
            state.client?.send(
                .useEntity(user: state.localEntityID, target: Int32(clamping: entity.id), attack: false))
            return
        }
        let held = inventory.selectedStack
        var activated = false
        if let hit = selectedBlock {
            state.client?.send(
                .place(position: hit.position, face: networkFace(hit.face), item: held.map(BetaSlot.init)))
            if held?.id == 323 { state.pendingSign = hit.adjacentPosition }
            if let kind = world[hit.position] {
                activated = [
                    .craftingTable, .chest, .furnace, .burningFurnace, .dispenser, .woodenDoor, .ironDoor,
                    .lever, .stoneButton, .trapdoor, .bed, .cake, .noteBlock, .jukebox, .repeaterOff,
                    .repeaterOn,
                ].contains(kind)
            }
        }
        if !activated, let held,
            selectedBlock == nil || [261, 325, 326, 327, 332, 333, 335, 344, 346].contains(held.id)
                || (held.definition?.foodHealing ?? 0) > 0
        {
            state.client?.send(.place(position: BlockPosition(-1, 255, -1), face: 255, item: BetaSlot(held)))
        }
        state.client?.send(.animation(entityID: state.localEntityID, animation: 1))
    }

    func networkFace(_ face: BlockPosition) -> UInt8 {
        if face.y == -1 { return 0 }
        if face.y == 1 { return 1 }
        if face.z == -1 { return 2 }
        if face.z == 1 { return 3 }
        return face.x == -1 ? 4 : 5
    }

    func beginChat() {
        guard isMultiplayer, !isLoading, !inventoryOpen, !signEditorOpen else { return }
        chatOpen = true
        resetInput()
    }

    func sendChat(_ message: String) {
        let text = limitedJavaString(message.trimmingCharacters(in: .whitespacesAndNewlines), limit: 119)
        if !text.isEmpty { multiplayer?.client?.send(.chat(text)) }
        chatOpen = false
        resetInput()
    }

    func beginSignEditing(at position: BlockPosition) {
        signPosition = position
        if case .sign(let lines) = world.blockEntity(at: position) {
            signLines = Array((lines + ["", "", "", ""]).prefix(4))
        } else {
            signLines = ["", "", "", ""]
        }
        inventoryOpen = false
        signEditorOpen = true
        resetInput()
    }

    func finishSignEditing() {
        defer {
            signEditorOpen = false
            signPosition = nil
            resetInput()
        }
        guard let position = signPosition else { return }
        let lines = Array((signLines + ["", "", "", ""]).prefix(4)).map { limitedJavaString($0, limit: 15) }
        world.setBlockEntity(.sign(lines: lines), at: position)
        if isMultiplayer { multiplayer?.client?.send(.updateSign(position: position, lines: lines)) }
    }

    func dismissOverlay() {
        if signEditorOpen {
            finishSignEditing()
        } else if chatOpen {
            chatOpen = false
            resetInput()
        } else if inventoryOpen {
            toggleInventory()
        } else {
            togglePause()
        }
    }

    func limitedJavaString(_ text: String, limit: Int) -> String {
        var result = ""
        for character in text where character != "\n" && character != "\r" {
            guard result.utf16.count + String(character).utf16.count <= limit else { break }
            result.append(character)
        }
        return result
    }
}
