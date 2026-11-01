import MinecraftCore
import SwiftUI

struct InventoryPanel: View {
    @ObservedObject var session: GameSession
    var interactionEnabled = true
    @ObservedObject private var rendered = InventoryRenderImages.shared
    @State private var pointer: CGPoint?

    var body: some View {
        BetaGUI(option: session.options.guiScale) { resolution in
            let origin = CGPoint(
                x: (resolution.width - layout.width) / 2, y: (resolution.height - layout.height) / 2)
            ZStack(alignment: .topLeading) {
                BetaScreenShade()
                panel(origin: origin, rasterScale: resolution.scale).offset(x: origin.x, y: origin.y)
                    .allowsHitTesting(false)
                if let pointer {
                    let local = CGPoint(x: pointer.x - origin.x, y: pointer.y - origin.y)
                    if let held = session.cursorItem {
                        GameItemIcon(stack: held, size: 16).offset(x: pointer.x - 8, y: pointer.y - 8)
                            .allowsHitTesting(false)
                    } else if let slot = layout.slot(at: local), let stack = stack(slot.id) {
                        let width = BetaBitmapFont.shared.width(stack.name)
                        ZStack(alignment: .topLeading) {
                            Color.black.opacity(0.75).frame(width: CGFloat(width + 6), height: 14).offset(
                                x: -3, y: -3)
                            BetaText(stack.name)
                        }.offset(x: pointer.x + 12, y: pointer.y - 12).allowsHitTesting(false)
                    }
                }
                if interactionEnabled {
                    BetaMouseSurface(
                        moved: { pointer = $0.map { CGPoint(x: floor($0.x), y: floor($0.y)) } },
                        clicked: { point, secondary, shift in
                            let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
                            if let slot = layout.slot(at: local) {
                                click(slot.id, secondary: secondary, shift: shift)
                            } else if !CGRect(x: 0, y: 0, width: layout.width, height: layout.height)
                                .contains(
                                    local)
                            {
                                session.inventoryOutsideClick(secondary: secondary)
                            }
                        })
                }
                #if os(iOS)
                    BetaButton(title: "Done", width: 50, session: session) { session.toggleInventory() }
                        .offset(x: CGFloat(resolution.width - 58), y: 8)
                #endif
            }
        }
    }

    private var layout: BetaContainerLayout {
        if session.furnaceOpen { return BetaContainerLayout(kind: .furnace) }
        if session.containerItems.count == 9 { return BetaContainerLayout(kind: .dispenser) }
        if !session.containerItems.isEmpty {
            return BetaContainerLayout(kind: .chest(rows: max(1, session.containerItems.count / 9)))
        }
        return BetaContainerLayout(kind: session.craftingWidth == 3 ? .crafting : .inventory)
    }

    private func panel(origin: CGPoint, rasterScale: Int) -> some View {
        ZStack(alignment: .topLeading) {
            background
            if layout.kind == .inventory {
                let relative = SIMD2<Float>(
                    Float((pointer?.x ?? (origin.x + 51)) - origin.x - 51),
                    Float((pointer?.y ?? (origin.y + 75)) - origin.y - 75))
                if let image = rendered.playerPreview(
                    armor: Array(session.armorItems.reversed()), heldItem: session.heldItem,
                    pointer: relative,
                    rasterScale: rasterScale
                ) {
                    Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
                        width: 64, height: 80
                    ).offset(x: 19)
                }
            }
            labels
            ForEach(layout.slots) { slot in
                GameItemIcon(stack: stack(slot.id), size: 16).offset(x: CGFloat(slot.x), y: CGFloat(slot.y))
                if let pointer,
                    layout.slot(at: CGPoint(x: pointer.x - origin.x, y: pointer.y - origin.y))?.id == slot.id
                {
                    Rectangle().fill(.white.opacity(0.5)).frame(width: 16, height: 16).offset(
                        x: CGFloat(slot.x), y: CGFloat(slot.y))
                }
            }
            if session.furnaceOpen {
                let burn = Int(session.furnaceBurnProgress * 12)
                if burn > 0 {
                    BetaSprite(
                        name: "gui/furnace.png",
                        rect: CGRect(x: 176, y: 12 - burn, width: 14, height: burn + 2)
                    )
                    .offset(x: 56, y: CGFloat(48 - burn))
                }
                BetaSprite(
                    name: "gui/furnace.png",
                    rect: CGRect(x: 176, y: 14, width: Int(session.furnaceProgress * 24) + 1, height: 16)
                )
                .offset(x: 79, y: 34)
            }
        }.frame(width: CGFloat(layout.width), height: CGFloat(layout.height), alignment: .topLeading)
    }

    @ViewBuilder private var background: some View {
        if case .chest(let rows) = layout.kind {
            BetaSprite(name: layout.texture, rect: CGRect(x: 0, y: 0, width: 176, height: rows * 18 + 17))
            BetaSprite(name: layout.texture, rect: CGRect(x: 0, y: 126, width: 176, height: 96)).offset(
                y: CGFloat(rows * 18 + 17))
        } else {
            BetaSprite(name: layout.texture, rect: CGRect(x: 0, y: 0, width: 176, height: 166))
        }
    }

    @ViewBuilder private var labels: some View {
        switch layout.kind {
        case .inventory: BetaText("Crafting", color: 0x404040, shadow: false).offset(x: 86, y: 16)
        case .crafting: BetaText("Crafting", color: 0x404040, shadow: false).offset(x: 28, y: 6)
        case .furnace: BetaText("Furnace", color: 0x404040, shadow: false).offset(x: 60, y: 6)
        case .dispenser: BetaText("Dispenser", color: 0x404040, shadow: false).offset(x: 60, y: 6)
        case .chest: BetaText(session.containerTitle, color: 0x404040, shadow: false).offset(x: 8, y: 6)
        }
        if layout.kind != .inventory {
            BetaText("Inventory", color: 0x404040, shadow: false).offset(x: 8, y: CGFloat(layout.height - 94))
        }
    }

    private func stack(_ id: BetaContainerSlotID) -> ItemStack? {
        switch id {
        case .player(let index): return item(session.inventoryItems, index)
        case .armor(let index): return item(session.armorItems, index)
        case .crafting(let index): return item(session.craftingItems, index)
        case .result: return session.craftingResultItem
        case .furnace(let index): return item(session.furnaceItems, index)
        case .container(let index): return item(session.containerItems, index)
        }
    }

    private func item(_ items: [ItemStack?], _ index: Int) -> ItemStack? {
        items.indices.contains(index) ? items[index] : nil
    }

    private func click(_ id: BetaContainerSlotID, secondary: Bool, shift: Bool) {
        switch id {
        case .player(let slot): session.inventoryClick(slot: slot, secondary: secondary, shift: shift)
        case .armor(let slot): session.armorClick(slot: slot, secondary: secondary, shift: shift)
        case .crafting(let slot): session.craftingClick(slot: slot, secondary: secondary, shift: shift)
        case .result: session.takeCraftingResult(secondary: secondary, shift: shift)
        case .furnace(let slot): session.furnaceClick(slot: slot, secondary: secondary, shift: shift)
        case .container(let slot): session.containerClick(slot: slot, secondary: secondary, shift: shift)
        }
    }
}

struct BetaScreenShade: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 16.0 / 255, green: 16.0 / 255, blue: 16.0 / 255).opacity(192.0 / 255),
                Color(red: 16.0 / 255, green: 16.0 / 255, blue: 16.0 / 255).opacity(208.0 / 255),
            ], startPoint: .top, endPoint: .bottom)
    }
}
