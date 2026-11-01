public enum BlockEntity: Codable, Equatable, Sendable {
    case chest(slots: [ItemStack?])
    case furnace(FurnaceState)
    case dispenser(slots: [ItemStack?])
    case sign(lines: [String])
    case spawner(mobID: String, delay: Int)
    case note(pitch: UInt8)
    case jukebox(record: UInt16?)
    case piston(PistonState)

    public static func initial(for block: BlockKind) -> Self? {
        switch block.rawValue {
        case 23: .dispenser(slots: Array(repeating: nil, count: 9))
        case 25: .note(pitch: 0)
        case 52: .spawner(mobID: "Pig", delay: 20)
        case 54: .chest(slots: Array(repeating: nil, count: 27))
        case 61, 62: .furnace(FurnaceState())
        case 63, 68: .sign(lines: ["", "", "", ""])
        case 84: .jukebox(record: nil)
        default: nil
        }
    }

    public static func initial(for state: BlockState) -> Self? {
        return initial(for: state.kind)
    }

    public var contents: [ItemStack?] {
        switch self {
        case .chest(let slots), .dispenser(let slots): slots
        case .furnace(let state): [state.input, state.fuel, state.output]
        case .jukebox(let record): [record.map { ItemStack(id: $0) }]
        default: []
        }
    }
}

public enum BlockEvent: Sendable {
    case dropItem(position: SIMD3<Double>, stack: ItemStack)
    case dropItemMoving(position: SIMD3<Double>, stack: ItemStack, velocity: SIMD3<Double>)
    case stepped(at: BlockPosition, position: SIMD3<Double>? = nil)
    case fishCaught
    case pigFall(distance: Float)
    case sound(name: String, position: SIMD3<Double>, volume: Float, pitch: Float)
    case spawnEntity(kind: String, position: SIMD3<Double>)
    case projectile(kind: String, position: SIMD3<Double>, velocity: SIMD3<Double>)
    case explosion(position: SIMD3<Double>, power: Float)
    case particle(name: String, position: SIMD3<Double>)
    case displace(bounds: AxisAlignedBox, delta: SIMD3<Double>)
}

public struct BlockUseResult: Sendable {
    public var handled = false
    public var itemUsed = false
    public var consumed = 0
    public var durabilityDamage = 0
    public var replacement: ItemStack?
    public var replaceHeldStack = false
    public var openContainer: BlockPosition?
    public var sleepAt: BlockPosition?
    public var healthRestored = 0
    public var changedPositions: [BlockPosition] = []
    public var events: [BlockEvent] = []

    public init() {}
}

extension BlockPosition {
    func adding(_ offset: BlockPosition) -> Self { Self(x + offset.x, y + offset.y, z + offset.z) }
    var center: SIMD3<Double> { SIMD3(Double(x) + 0.5, Double(y) + 0.5, Double(z) + 0.5) }
    static let neighbors = [
        BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0), BlockPosition(0, -1, 0),
        BlockPosition(0, 1, 0), BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
    ]
    static let horizontal = [
        BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0), BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
    ]
}
