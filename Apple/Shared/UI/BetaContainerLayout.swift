import CoreGraphics

enum BetaContainerSlotID: Hashable {
    case player(Int)
    case armor(Int)
    case crafting(Int)
    case result
    case furnace(Int)
    case container(Int)
}

struct BetaContainerSlot: Identifiable {
    let id: BetaContainerSlotID
    let x: Int
    let y: Int
    var frame: CGRect { CGRect(x: x, y: y, width: 16, height: 16) }
}

struct BetaContainerLayout {
    enum Kind: Equatable {
        case inventory, crafting, furnace, dispenser
        case chest(rows: Int)
    }
    let kind: Kind
    var width: Int { 176 }
    var height: Int {
        if case .chest(let rows) = kind { return 114 + rows * 18 }
        return 166
    }

    var texture: String {
        switch kind {
        case .inventory: "gui/inventory.png"
        case .crafting: "gui/crafting.png"
        case .furnace: "gui/furnace.png"
        case .dispenser: "gui/trap.png"
        case .chest: "gui/container.png"
        }
    }

    var slots: [BetaContainerSlot] {
        var slots: [BetaContainerSlot] = []
        switch kind {
        case .inventory:
            slots += (0..<4).map { BetaContainerSlot(id: .armor($0), x: 8, y: 8 + $0 * 18) }
            slots += (0..<4).map {
                BetaContainerSlot(id: .crafting($0), x: 88 + $0 % 2 * 18, y: 26 + $0 / 2 * 18)
            }
            slots.append(BetaContainerSlot(id: .result, x: 144, y: 36))
        case .crafting:
            slots += (0..<9).map {
                BetaContainerSlot(id: .crafting($0), x: 30 + $0 % 3 * 18, y: 17 + $0 / 3 * 18)
            }
            slots.append(BetaContainerSlot(id: .result, x: 124, y: 35))
        case .furnace:
            slots += [
                BetaContainerSlot(id: .furnace(0), x: 56, y: 17),
                BetaContainerSlot(id: .furnace(1), x: 56, y: 53),
                BetaContainerSlot(id: .furnace(2), x: 116, y: 35),
            ]
        case .dispenser:
            slots += (0..<9).map {
                BetaContainerSlot(id: .container($0), x: 62 + $0 % 3 * 18, y: 17 + $0 / 3 * 18)
            }
        case .chest(let rows):
            slots += (0..<(rows * 9)).map {
                BetaContainerSlot(id: .container($0), x: 8 + $0 % 9 * 18, y: 18 + $0 / 9 * 18)
            }
        }
        let inventoryY: Int
        let hotbarY: Int
        if case .chest(let rows) = kind {
            inventoryY = 31 + rows * 18
            hotbarY = 89 + rows * 18
        } else {
            inventoryY = 84
            hotbarY = 142
        }
        slots += (9..<36).map {
            BetaContainerSlot(id: .player($0), x: 8 + ($0 - 9) % 9 * 18, y: inventoryY + ($0 - 9) / 9 * 18)
        }
        slots += (0..<9).map { BetaContainerSlot(id: .player($0), x: 8 + $0 * 18, y: hotbarY) }
        return slots
    }

    func slot(at point: CGPoint) -> BetaContainerSlot? {
        slots.first { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }
    }
}
