import Foundation

public struct PaintingMotive: Sendable, Equatable {
    public let name: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let textureX: Int
    public let textureY: Int
}

public enum BetaPainting {
    public static let motives: [PaintingMotive] = [
        .init(name: "Kebab", pixelWidth: 16, pixelHeight: 16, textureX: 0, textureY: 0),
        .init(name: "Aztec", pixelWidth: 16, pixelHeight: 16, textureX: 16, textureY: 0),
        .init(name: "Alban", pixelWidth: 16, pixelHeight: 16, textureX: 32, textureY: 0),
        .init(name: "Aztec2", pixelWidth: 16, pixelHeight: 16, textureX: 48, textureY: 0),
        .init(name: "Bomb", pixelWidth: 16, pixelHeight: 16, textureX: 64, textureY: 0),
        .init(name: "Plant", pixelWidth: 16, pixelHeight: 16, textureX: 80, textureY: 0),
        .init(name: "Wasteland", pixelWidth: 16, pixelHeight: 16, textureX: 96, textureY: 0),
        .init(name: "Pool", pixelWidth: 32, pixelHeight: 16, textureX: 0, textureY: 32),
        .init(name: "Courbet", pixelWidth: 32, pixelHeight: 16, textureX: 32, textureY: 32),
        .init(name: "Sea", pixelWidth: 32, pixelHeight: 16, textureX: 64, textureY: 32),
        .init(name: "Sunset", pixelWidth: 32, pixelHeight: 16, textureX: 96, textureY: 32),
        .init(name: "Creebet", pixelWidth: 32, pixelHeight: 16, textureX: 128, textureY: 32),
        .init(name: "Wanderer", pixelWidth: 16, pixelHeight: 32, textureX: 0, textureY: 64),
        .init(name: "Graham", pixelWidth: 16, pixelHeight: 32, textureX: 16, textureY: 64),
        .init(name: "Match", pixelWidth: 32, pixelHeight: 32, textureX: 0, textureY: 128),
        .init(name: "Bust", pixelWidth: 32, pixelHeight: 32, textureX: 32, textureY: 128),
        .init(name: "Stage", pixelWidth: 32, pixelHeight: 32, textureX: 64, textureY: 128),
        .init(name: "Void", pixelWidth: 32, pixelHeight: 32, textureX: 96, textureY: 128),
        .init(name: "SkullAndRoses", pixelWidth: 32, pixelHeight: 32, textureX: 128, textureY: 128),
        .init(name: "Fighters", pixelWidth: 64, pixelHeight: 32, textureX: 0, textureY: 96),
        .init(name: "Pointer", pixelWidth: 64, pixelHeight: 64, textureX: 0, textureY: 192),
        .init(name: "Pigscene", pixelWidth: 64, pixelHeight: 64, textureX: 64, textureY: 192),
        .init(name: "BurningSkull", pixelWidth: 64, pixelHeight: 64, textureX: 128, textureY: 192),
        .init(name: "Skeleton", pixelWidth: 64, pixelHeight: 48, textureX: 192, textureY: 64),
        .init(name: "DonkeyKong", pixelWidth: 64, pixelHeight: 48, textureX: 192, textureY: 112),
    ]

    public static func motive(named name: String) -> PaintingMotive? { motives.first { $0.name == name } }

    public static func configure(
        _ entity: inout GameEntity, anchor: BlockPosition, direction: UInt8, motive name: String
    ) {
        let motive = motive(named: name) ?? motives[0]
        entity.kind = "painting"
        entity.paintingMotive = motive.name
        entity.paintingAnchor = anchor
        entity.paintingFacing = direction & 3
        entity.width = Double(motive.pixelWidth) / 16
        entity.height = Double(motive.pixelHeight) / 16
        let center = center(anchor: anchor, direction: direction, motive: motive)
        entity.position = center - SIMD3(0, entity.height / 2, 0)
        entity.previousPosition = entity.position
        entity.velocity = .zero
        entity.yaw = Float(direction & 3) * BetaMath.pi / 2 - BetaMath.pi
    }

    static func center(anchor: BlockPosition, direction: UInt8, motive: PaintingMotive) -> SIMD3<Double> {
        var center = SIMD3(Float(anchor.x) + 0.5, Float(anchor.y) + 0.5, Float(anchor.z) + 0.5)
        let widthOffset: Float = motive.pixelWidth == 32 || motive.pixelWidth == 64 ? 0.5 : 0
        let heightOffset: Float = motive.pixelHeight == 32 || motive.pixelHeight == 64 ? 0.5 : 0
        switch direction & 3 {
        case 0:
            center.z -= 0.5625
            center.x -= widthOffset
        case 1:
            center.x -= 0.5625
            center.z += widthOffset
        case 2:
            center.z += 0.5625
            center.x += widthOffset
        default:
            center.x += 0.5625
            center.z -= widthOffset
        }
        center.y += heightOffset
        return SIMD3<Double>(center)
    }

    static func bounds(anchor: BlockPosition, direction: UInt8, motive: PaintingMotive) -> AxisAlignedBox {
        let center = SIMD3<Float>(center(anchor: anchor, direction: direction, motive: motive))
        var half = SIMD3(
            Float(motive.pixelWidth) / 32, Float(motive.pixelHeight) / 32, Float(motive.pixelWidth) / 32)
        if direction & 1 == 0 { half.z = 0.5 / 32 } else { half.x = 0.5 / 32 }
        let inset = Float(0.00625)
        return AxisAlignedBox(
            min: SIMD3<Double>(center - half + SIMD3(repeating: inset)),
            max: SIMD3<Double>(center + half - SIMD3(repeating: inset)))
    }
}

extension EntitySimulation {
    public mutating func placePainting(at anchor: BlockPosition, facing: BlockPosition, world: BlockWorld)
        -> Bool
    {
        let direction: UInt8
        if facing == BlockPosition(0, 0, -1) {
            direction = 0
        } else if facing == BlockPosition(-1, 0, 0) {
            direction = 1
        } else if facing == BlockPosition(0, 0, 1) {
            direction = 2
        } else if facing == BlockPosition(1, 0, 0) {
            direction = 3
        } else {
            return false
        }
        var probe = GameEntity(id: 0, kind: "painting", position: .zero)
        var fitting: [PaintingMotive] = []
        for motive in BetaPainting.motives {
            BetaPainting.configure(&probe, anchor: anchor, direction: direction, motive: motive.name)
            if paintingFits(probe, world: world) { fitting.append(motive) }
        }
        guard !fitting.isEmpty else { return false }
        let selected = fitting[random.nextInt(bound: fitting.count)]
        let id = spawn(kind: "painting", position: .zero)
        update(id: id) {
            BetaPainting.configure(&$0, anchor: anchor, direction: direction, motive: selected.name)
        }
        return true
    }

    func paintingFits(_ entity: GameEntity, world: BlockWorld) -> Bool {
        guard let anchor = entity.paintingAnchor,
            let motive = BetaPainting.motive(named: entity.paintingMotive ?? "Kebab"),
            BlockCollision.boxes(in: world, intersecting: entity.bounds).isEmpty
        else { return false }
        let center = BetaPainting.center(anchor: anchor, direction: entity.paintingFacing, motive: motive)
        let x = Int(floor(center.x - Double(Float(motive.pixelWidth) / 32)))
        let y = Int(floor(center.y - Double(Float(motive.pixelHeight) / 32)))
        let z = Int(floor(center.z - Double(Float(motive.pixelWidth) / 32)))
        for horizontal in 0..<(motive.pixelWidth / 16) {
            for vertical in 0..<(motive.pixelHeight / 16) {
                let p =
                    entity.paintingFacing & 1 == 0
                    ? BlockPosition(x + horizontal, y + vertical, anchor.z)
                    : BlockPosition(anchor.x, y + vertical, z + horizontal)
                guard world[p]?.isSolid == true else { return false }
            }
        }
        return !entities.contains {
            $0.id != entity.id && $0.kind == "painting" && $0.health > 0
                && $0.bounds.intersects(entity.bounds)
        }
    }
}
