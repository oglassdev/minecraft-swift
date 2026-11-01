import Foundation

public enum BlockCollision {
    public static func boxes(for state: BlockState, at position: BlockPosition) -> [AxisAlignedBox] {
        let metadata = Int(state.metadata)
        let local: [AxisAlignedBox]
        switch state.kind.rawValue {
        case 30, 36, 63, 68, 70, 72: local = []
        case 34:
            switch metadata & 7 {
            case 0: local = [box(0, 0, 0, 1, 0.25, 1), box(0.375, 0.25, 0.375, 0.625, 1, 0.625)]
            case 1: local = [box(0, 0.75, 0, 1, 1, 1), box(0.375, 0, 0.375, 0.625, 0.75, 0.625)]
            case 2: local = [box(0, 0, 0, 1, 1, 0.25), box(0.25, 0.375, 0.25, 0.75, 0.625, 1)]
            case 3: local = [box(0, 0, 0.75, 1, 1, 1), box(0.25, 0.375, 0, 0.75, 0.625, 0.75)]
            case 4: local = [box(0, 0, 0, 0.25, 1, 1), box(0.375, 0.25, 0.25, 0.625, 0.75, 1)]
            case 5: local = [box(0.75, 0, 0, 1, 1, 1), box(0, 0.375, 0.25, 0.75, 0.625, 0.75)]
            default: local = []
            }
        case 26: local = [box(0, 0, 0, 1, 0.5625, 1)]
        case 44: local = [box(0, 0, 0, 1, 0.5, 1)]
        case 53, 67:
            switch metadata & 3 {
            case 0: local = [box(0, 0, 0, 0.5, 0.5, 1), box(0.5, 0, 0, 1, 1, 1)]
            case 1: local = [box(0, 0, 0, 0.5, 1, 1), box(0.5, 0, 0, 1, 0.5, 1)]
            case 2: local = [box(0, 0, 0, 1, 0.5, 0.5), box(0, 0, 0.5, 1, 1, 1)]
            default: local = [box(0, 0, 0, 1, 1, 0.5), box(0, 0, 0.5, 1, 0.5, 1)]
            }
        case 60: local = [box(0, 0, 0, 1, 1, 1)]
        case 64, 71:
            let orientation = metadata & 4 == 0 ? (metadata - 1) & 3 : metadata & 3
            local = [verticalPanel(orientation: orientation, thickness: 0.1875)]
        case 65:
            switch metadata {
            case 2: local = [box(0, 0, 0.875, 1, 1, 1)]
            case 3: local = [box(0, 0, 0, 1, 1, 0.125)]
            case 4: local = [box(0.875, 0, 0, 1, 1, 1)]
            default: local = [box(0, 0, 0, 0.125, 1, 1)]
            }
        case 78: local = metadata & 7 >= 3 ? [box(0, 0, 0, 1, 0.5, 1)] : []
        case 81: local = [box(0.0625, 0, 0.0625, 0.9375, 0.9375, 0.9375)]
        case 85: local = [box(0, 0, 0, 1, 1.5, 1)]
        case 88: local = [box(0, 0, 0, 1, 0.875, 1)]
        case 92: local = [box(Double(1 + metadata * 2) / 16, 0, 0.0625, 0.9375, 0.4375, 0.9375)]
        case 93, 94: local = [box(0, 0, 0, 1, 0.125, 1)]
        case 96:
            if metadata & 4 == 0 {
                local = [box(0, 0, 0, 1, 0.1875, 1)]
            } else {
                let orientation = [2, 0, 1, 3][metadata & 3]
                local = [verticalPanel(orientation: orientation, thickness: 0.1875)]
            }
        default: local = state.kind.isSolid ? [box(0, 0, 0, 1, 1, 1)] : []
        }
        let offset = SIMD3(Double(position.x), Double(position.y), Double(position.z))
        return local.map { $0.offset(by: offset) }
    }

    public static func boxes(in world: BlockWorld, intersecting bounds: AxisAlignedBox) -> [AxisAlignedBox] {
        guard bounds.min.x.isFinite, bounds.min.y.isFinite, bounds.min.z.isFinite,
            bounds.max.x.isFinite, bounds.max.y.isFinite, bounds.max.z.isFinite
        else { return [] }
        var result: [AxisAlignedBox] = []
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in (Int(floor(bounds.min.y)) - 1)...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    let position = BlockPosition(x, y, z)
                    guard let state = world.state(at: position) else { continue }
                    for box in boxes(for: state, at: position, in: world) where box.intersects(bounds) {
                        result.append(box)
                    }
                }
            }
        }
        return result
    }

    public static func boxes(for state: BlockState, at position: BlockPosition, in world: BlockWorld)
        -> [AxisAlignedBox]
    {
        guard state.kind.rawValue == 36 else {
            return boxes(for: resolvedState(state, at: position, in: world), at: position)
        }
        guard case .piston(let piston) = world.blockEntity(at: position), piston.block.kind.rawValue != 36
        else { return [] }
        return piston.storedCollisionBounds(at: position).map { [$0.offset(by: piston.collisionOffset)] }
            ?? []
    }

    public static func selectionBoxes(for state: BlockState, at position: BlockPosition, in world: BlockWorld)
        -> [AxisAlignedBox]
    {
        selectionBoxes(for: resolvedState(state, at: position, in: world), at: position)
    }

    private static func resolvedState(_ state: BlockState, at position: BlockPosition, in world: BlockWorld)
        -> BlockState
    {
        if state.kind == .woodenDoor || state.kind == .ironDoor, state.metadata & 8 != 0 {
            return BlockState(
                state.kind,
                metadata: world.state(at: BlockPosition(position.x, position.y - 1, position.z))?.metadata
                    ?? 0)
        }
        return state
    }

    public static func selectionBoxes(for state: BlockState, at position: BlockPosition) -> [AxisAlignedBox] {
        let metadata = Int(state.metadata)
        let local: AxisAlignedBox?
        switch state.kind.rawValue {
        case 0, 51, 90: return []
        case 29 where metadata & 8 != 0, 33 where metadata & 8 != 0:
            switch metadata & 7 {
            case 0: local = box(0, 0.25, 0, 1, 1, 1)
            case 1: local = box(0, 0, 0, 1, 0.75, 1)
            case 2: local = box(0, 0, 0.25, 1, 1, 1)
            case 3: local = box(0, 0, 0, 1, 1, 0.75)
            case 4: local = box(0.25, 0, 0, 1, 1, 1)
            default: local = box(0, 0, 0, 0.75, 1, 1)
            }
        case 34: return Array(boxes(for: state, at: position).prefix(1))
        case 6, 31, 32: local = box(0.1, 0, 0.1, 0.9, 0.8, 0.9)
        case 37, 38: local = box(0.3, 0, 0.3, 0.7, 0.6, 0.7)
        case 39, 40: local = box(0.3, 0, 0.3, 0.7, 0.4, 0.7)
        case 59: local = box(0, 0, 0, 1, 0.25, 1)
        case 83: local = box(0.125, 0, 0.125, 0.875, 1, 0.875)
        case 27, 28, 66: local = box(0, 0, 0, 1, (2...5).contains(metadata) ? 0.625 : 0.125, 1)
        case 55: local = box(0, 0, 0, 1, 0.0625, 1)
        case 50, 75, 76:
            local =
                wallFixture(metadata: metadata & 7, depth: 0.3, halfWidth: 0.15, bottom: 0.2, top: 0.8)
                ?? box(0.4, 0, 0.4, 0.6, 0.6, 0.6)
        case 63: local = box(0.25, 0, 0.25, 0.75, 1, 0.75)
        case 68:
            switch metadata {
            case 2: local = box(0, 0.28125, 0.875, 1, 0.78125, 1)
            case 3: local = box(0, 0.28125, 0, 1, 0.78125, 0.125)
            case 4: local = box(0.875, 0.28125, 0, 1, 0.78125, 1)
            default: local = box(0, 0.28125, 0, 0.125, 0.78125, 1)
            }
        case 69:
            local =
                wallFixture(metadata: metadata & 7, depth: 0.375, halfWidth: 0.1875, bottom: 0.2, top: 0.8)
                ?? box(0.25, 0, 0.25, 0.75, 0.6, 0.75)
        case 77:
            local = wallFixture(
                metadata: metadata & 7, depth: metadata & 8 == 0 ? 0.125 : 0.0625,
                halfWidth: 0.1875, bottom: 0.375, top: 0.625)
        case 70, 72: local = box(0.0625, 0, 0.0625, 0.9375, metadata == 1 ? 0.03125 : 0.0625, 0.9375)
        case 78: local = box(0, 0, 0, 1, Double(1 + (state.metadata & 7)) / 8, 1)
        case 60: local = box(0, 0, 0, 1, 0.9375, 1)
        case 81: local = box(0.0625, 0, 0.0625, 0.9375, 1, 0.9375)
        case 92: local = box(Double(1 + Int(state.metadata) * 2) / 16, 0, 0.0625, 0.9375, 0.5, 0.9375)
        case 30, 53, 67, 85, 8...11: local = box(0, 0, 0, 1, 1, 1)
        default: local = nil
        }
        if let local {
            return [local.offset(by: SIMD3(Double(position.x), Double(position.y), Double(position.z)))]
        }
        return boxes(for: state, at: position)
    }

    private static func box(
        _ x0: Double, _ y0: Double, _ z0: Double, _ x1: Double, _ y1: Double, _ z1: Double
    ) -> AxisAlignedBox {
        AxisAlignedBox(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    private static func verticalPanel(orientation: Int, thickness: Double) -> AxisAlignedBox {
        switch orientation {
        case 0: box(0, 0, 0, 1, 1, thickness)
        case 1: box(1 - thickness, 0, 0, 1, 1, 1)
        case 2: box(0, 0, 1 - thickness, 1, 1, 1)
        default: box(0, 0, 0, thickness, 1, 1)
        }
    }

    private static func wallFixture(
        metadata: Int, depth: Double, halfWidth: Double, bottom: Double, top: Double
    ) -> AxisAlignedBox? {
        switch metadata {
        case 1: box(0, bottom, 0.5 - halfWidth, depth, top, 0.5 + halfWidth)
        case 2: box(1 - depth, bottom, 0.5 - halfWidth, 1, top, 0.5 + halfWidth)
        case 3: box(0.5 - halfWidth, bottom, 0, 0.5 + halfWidth, top, depth)
        case 4: box(0.5 - halfWidth, bottom, 1 - depth, 0.5 + halfWidth, top, 1)
        default: nil
        }
    }
}
