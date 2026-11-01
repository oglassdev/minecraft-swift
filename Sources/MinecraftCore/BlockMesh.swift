import Foundation

public struct BlockVertex: Sendable {
    public let position: SIMD3<Float>
    private let red: Float
    private let green: Float
    private let blue: Float
    public let lightSamples: UInt32
    public var color: SIMD3<Float> { SIMD3(red, green, blue) }
    public let uv: SIMD2<Float>
    public let opacity: Float
    public let textureWeight: Float

    public init(
        position: SIMD3<Float>, color: SIMD3<Float>, uv: SIMD2<Float> = .zero,
        opacity: Float = 1, textureWeight: Float = 1, light: UInt8 = 240, lightSamples: UInt32? = nil
    ) {
        self.position = position
        red = color.x
        green = color.y
        blue = color.z
        self.lightSamples = lightSamples ?? UInt32(light) * 0x0101_0101
        self.uv = uv
        self.opacity = opacity
        self.textureWeight = textureWeight
    }
}

public enum BlockFace: Int, CaseIterable, Sendable {
    case bottom, top, north, south, west, east

    public var offset: BlockPosition {
        switch self {
        case .bottom: BlockPosition(0, -1, 0)
        case .top: BlockPosition(0, 1, 0)
        case .north: BlockPosition(0, 0, -1)
        case .south: BlockPosition(0, 0, 1)
        case .west: BlockPosition(-1, 0, 0)
        case .east: BlockPosition(1, 0, 0)
        }
    }

    fileprivate var brightness: Float {
        switch self {
        case .bottom: 0.5
        case .top: 1
        case .north, .south: 0.8
        case .west, .east: 0.6
        }
    }

    fileprivate var corners: [SIMD3<Float>] {
        switch self {
        case .bottom: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 1), SIMD3(0, 0, 1)]
        case .top: [SIMD3(0, 1, 1), SIMD3(1, 1, 1), SIMD3(1, 1, 0), SIMD3(0, 1, 0)]
        case .north: [SIMD3(1, 0, 0), SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0)]
        case .south: [SIMD3(0, 0, 1), SIMD3(1, 0, 1), SIMD3(1, 1, 1), SIMD3(0, 1, 1)]
        case .west: [SIMD3(0, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 1, 1), SIMD3(0, 1, 0)]
        case .east: [SIMD3(1, 0, 1), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(1, 1, 1)]
        }
    }

    fileprivate func textureCoordinates(_ point: SIMD3<Float>) -> SIMD2<Float> {
        switch self {
        case .bottom: SIMD2(point.x, 1 - point.z)
        case .top: SIMD2(point.x, point.z)
        case .north: SIMD2(1 - point.x, 1 - point.y)
        case .south: SIMD2(point.x, 1 - point.y)
        case .west: SIMD2(point.z, 1 - point.y)
        case .east: SIMD2(1 - point.z, 1 - point.y)
        }
    }
}

/// Indices address the original 16-by-16 Beta terrain atlas.
public enum BlockAtlas {
    public static func textureIndex(for state: BlockState, face: BlockFace) -> Int {
        let id = Int(state.kind.rawValue)
        let metadata = Int(state.metadata)
        switch id {
        case 2: return face == .top ? 0 : (face == .bottom ? 2 : 3)
        case 6: return [15, 63, 79, 15][metadata & 3]
        case 8, 9: return face == .top || face == .bottom ? 205 : 206
        case 10, 11: return face == .top || face == .bottom ? 237 : 238
        case 17:
            if face == .top || face == .bottom { return 21 }
            return metadata == 1 ? 116 : (metadata == 2 ? 117 : 20)
        case 18: return metadata & 3 == 1 ? 132 : 52
        case 23, 61, 62:
            if face == .top || face == .bottom { return 62 }
            let front = metadata
            if face.rawValue != front { return 45 }
            return id == 23 ? 46 : (id == 62 ? 61 : 44)
        case 24: return face == .top ? 176 : (face == .bottom ? 208 : 192)
        case 26:
            if face == .bottom { return 4 }
            let rotation = [
                [1, 0, 3, 2, 5, 4], [1, 0, 5, 4, 2, 3], [1, 0, 2, 3, 4, 5], [1, 0, 4, 5, 3, 2],
            ]
            let relativeFace = rotation[metadata & 3][face.rawValue]
            if metadata & 8 != 0 {
                if relativeFace == 2 { return 152 }
                return relativeFace == 4 || relativeFace == 5 ? 151 : 135
            }
            if relativeFace == 3 { return 149 }
            return relativeFace == 4 || relativeFace == 5 ? 150 : 134
        case 27: return metadata & 8 == 0 ? 163 : 179
        case 28: return 195
        case 29, 33:
            let base = id == 29 ? 106 : 107
            if metadata & 7 > 5 { return base }
            if face.rawValue == (metadata & 7) { return metadata & 8 == 0 ? base : 110 }
            return face.rawValue == ((metadata & 7) ^ 1) ? 109 : 108
        case 34:
            if face.rawValue == (metadata & 7) { return metadata & 8 == 0 ? 107 : 106 }
            return face.rawValue == ((metadata & 7) ^ 1) ? 107 : 108
        case 31: return metadata == 0 ? 55 : (metadata == 2 ? 56 : 39)
        case 35:
            if metadata == 0 { return 64 }
            let inverted = ~metadata & 15
            return 113 + ((inverted & 8) >> 3) + (inverted & 7) * 16
        case 43, 44:
            switch metadata {
            case 0: return face == .top || face == .bottom ? 6 : 5
            case 1: return face == .top ? 176 : (face == .bottom ? 208 : 192)
            case 2: return 4
            case 3: return 16
            default: return 6
            }
        case 46: return face == .top ? 9 : (face == .bottom ? 10 : 8)
        case 47: return face == .top || face == .bottom ? 4 : 35
        case 54, 95: return face == .top || face == .bottom ? 25 : (face == .south ? 27 : 26)
        case 58:
            if face == .top { return 43 }
            if face == .bottom { return 4 }
            return face == .north || face == .west ? 60 : 59
        case 59: return 88 + metadata
        case 60: return face == .top ? (metadata > 0 ? 86 : 87) : 2
        case 64, 71:
            let base = id == 64 ? 97 : 98
            if face == .top || face == .bottom { return base }
            let orientation = metadata & 4 == 0 ? (metadata - 1) & 3 : metadata & 3
            if (orientation == 0 || orientation == 2) != (face.rawValue <= 3) { return base }
            return base - (metadata & 8) * 2
        case 66: return metadata >= 6 ? 112 : 128
        case 81: return face == .top ? 69 : (face == .bottom ? 71 : 70)
        case 84: return face == .top ? 75 : 74
        case 86, 91:
            if face == .top || face == .bottom { return 102 }
            let fronts = [BlockFace.south, .west, .north, .east]
            return metadata < 4 && face == fronts[metadata] ? (id == 91 ? 120 : 119) : 118
        case 75, 76: return face == .top ? 164 : (id == 75 ? 115 : 99)
        case 92:
            if face == .top { return 121 }
            if face == .bottom { return 124 }
            return metadata > 0 && face == .west ? 123 : 122
        case 93, 94:
            if face == .top { return id == 94 ? 147 : 131 }
            if face == .bottom { return id == 94 ? 99 : 115 }
            return 5
        default: return baseTextures.indices.contains(id) ? baseTextures[id] : 1
        }
    }

    fileprivate static func mirrorsTexture(for state: BlockState, face: BlockFace) -> Bool {
        guard state.kind == .woodenDoor || state.kind == .ironDoor, face.rawValue > 1 else { return false }
        let metadata = Int(state.metadata)
        let orientation = metadata & 4 == 0 ? (metadata - 1) & 3 : metadata & 3
        guard (orientation == 0 || orientation == 2) == (face.rawValue <= 3) else { return false }
        let parity = orientation / 2 + ((face.rawValue & 1) ^ orientation) + (metadata & 4) / 4
        return parity & 1 != 0
    }

    public static func textureIndex(
        for state: BlockState, face: BlockFace, at position: BlockPosition, in world: BlockWorld
    ) -> Int {
        guard state.kind == .chest || state.kind.rawValue == 95, face.rawValue > 1 else {
            return textureIndex(for: state, face: face)
        }
        func kind(_ x: Int, _ z: Int) -> BlockKind? {
            world[BlockPosition(position.x + x, position.y, position.z + z)]
        }
        func opaque(_ x: Int, _ z: Int) -> Bool { kind(x, z)?.isOpaque == true }
        let north = kind(0, -1)
        let south = kind(0, 1)
        let west = kind(-1, 0)
        let east = kind(1, 0)
        if state.kind == .chest, north == .chest || south == .chest {
            guard face != .north && face != .south else { return 26 }
            let z = north == .chest ? -1 : 1
            var offset = north == .chest ? -1 : 0
            if face == .west { offset = -1 - offset }
            var front = BlockFace.east
            if (opaque(-1, 0) || opaque(-1, z)) && !opaque(1, 0) && !opaque(1, z) { front = .east }
            if (opaque(1, 0) || opaque(1, z)) && !opaque(-1, 0) && !opaque(-1, z) { front = .west }
            return (face == front ? 42 : 58) + offset
        }
        if state.kind == .chest, west == .chest || east == .chest {
            guard face != .west && face != .east else { return 26 }
            let x = west == .chest ? -1 : 1
            var offset = west == .chest ? -1 : 0
            if face == .south { offset = -1 - offset }
            var front = BlockFace.south
            if (opaque(0, -1) || opaque(x, -1)) && !opaque(0, 1) && !opaque(x, 1) { front = .south }
            if (opaque(0, 1) || opaque(x, 1)) && !opaque(0, -1) && !opaque(x, -1) { front = .north }
            return (face == front ? 42 : 58) + offset
        }
        var front = BlockFace.south
        if opaque(0, -1) && !opaque(0, 1) { front = .south }
        if opaque(0, 1) && !opaque(0, -1) { front = .north }
        if opaque(-1, 0) && !opaque(1, 0) { front = .east }
        if opaque(1, 0) && !opaque(-1, 0) { front = .west }
        return face == front ? 27 : 26
    }

    private static let baseTextures = [
        0, 1, 3, 2, 16, 4, 15, 17, 205, 205, 237, 237, 18, 19, 32, 33,
        34, 20, 52, 48, 49, 160, 144, 45, 192, 74, 134, 179, 195, 106, 11, 39,
        55, 107, 107, 64, 0, 13, 12, 29, 28, 23, 22, 6, 6, 7, 8, 35,
        36, 37, 80, 31, 65, 4, 26, 164, 50, 24, 59, 88, 87, 45, 45, 4,
        97, 83, 128, 16, 4, 96, 1, 98, 4, 51, 51, 115, 99, 1, 66, 67,
        66, 70, 72, 73, 74, 4, 102, 103, 104, 105, 14, 102, 121, 131, 147, 26, 84,
    ]
}

public struct BlockColorMaps: Sendable {
    public let grass: [UInt32]
    public let foliage: [UInt32]

    public init(grass: [UInt32], foliage: [UInt32]) {
        precondition(grass.count == 65536 && foliage.count == 65536)
        self.grass = grass
        self.foliage = foliage
    }

    fileprivate func color(foliage: Bool, temperature: Double, humidity: Double) -> SIMD3<Float> {
        let temperature = min(max(temperature, 0), 1)
        let humidity = min(max(humidity, 0), 1) * temperature
        let x = Int((1 - temperature) * 255)
        let y = Int((1 - humidity) * 255)
        return Self.rgb((foliage ? self.foliage : grass)[y * 256 + x])
    }

    fileprivate static func rgb(_ packed: UInt32) -> SIMD3<Float> {
        SIMD3(Float((packed >> 16) & 255), Float((packed >> 8) & 255), Float(packed & 255)) / 255
    }
}

public struct TranslucentBlockFace: Sendable {
    public let center: SIMD3<Float>
    public let vertices: [BlockVertex]
}

public struct BlockMeshOptions: Equatable, Sendable {
    public var smoothLighting: Bool
    public var fancyLeaves: Bool

    public init(smoothLighting: Bool = true, fancyLeaves: Bool = true) {
        self.smoothLighting = smoothLighting
        self.fancyLeaves = fancyLeaves
    }
}

public struct BlockMesh: Sendable {
    public let opaqueVertices: [BlockVertex]
    public let cutoutVertices: [BlockVertex]
    public let translucentFaces: [TranslucentBlockFace]

    public var vertices: [BlockVertex] {
        opaqueVertices + cutoutVertices + translucentFaces.flatMap(\.vertices)
    }

    public init(
        world: BlockWorld, chunk: ChunkPosition? = nil, colorMaps: BlockColorMaps? = nil,
        relativeTo origin: BlockPosition = BlockPosition(0, 0, 0), options: BlockMeshOptions = .init()
    ) {
        var builder = MeshBuilder(world: world, colorMaps: colorMaps, origin: origin, options: options)
        if let chunk {
            world.forEachBlock(in: chunk) { builder.append(position: $0, state: $1) }
        } else {
            world.forEachBlock { builder.append(position: $0, state: $1) }
        }
        opaqueVertices = builder.opaque
        cutoutVertices = builder.cutout
        translucentFaces = builder.translucent
    }

    public init(
        world: BlockWorld, blockAt position: BlockPosition, colorMaps: BlockColorMaps? = nil,
        relativeTo origin: BlockPosition = BlockPosition(0, 0, 0), options: BlockMeshOptions = .init()
    ) {
        var builder = MeshBuilder(world: world, colorMaps: colorMaps, origin: origin, options: options)
        if let state = world.state(at: position) { builder.append(position: position, state: state) }
        opaqueVertices = builder.opaque
        cutoutVertices = builder.cutout
        translucentFaces = builder.translucent
    }
}

private struct MeshBounds {
    var minimum: SIMD3<Float>
    var maximum: SIMD3<Float>

    init(_ minimum: SIMD3<Float> = .zero, _ maximum: SIMD3<Float> = SIMD3(repeating: 1)) {
        self.minimum = minimum
        self.maximum = maximum
    }

    func touchesBoundary(_ face: BlockFace) -> Bool {
        switch face {
        case .bottom: minimum.y == 0
        case .top: maximum.y == 1
        case .north: minimum.z == 0
        case .south: maximum.z == 1
        case .west: minimum.x == 0
        case .east: maximum.x == 1
        }
    }
}

private enum MeshLayer { case opaque, cutout, translucent }

private struct MeshBuilder {
    let world: BlockWorld
    let colorMaps: BlockColorMaps?
    let origin: BlockPosition
    let options: BlockMeshOptions
    var opaque: [BlockVertex] = []
    var cutout: [BlockVertex] = []
    var translucent: [TranslucentBlockFace] = []

    private func vector(_ position: BlockPosition) -> SIMD3<Float> {
        SIMD3(Float(position.x - origin.x), Float(position.y - origin.y), Float(position.z - origin.z))
    }

    mutating func append(position: BlockPosition, state: BlockState) {
        let id = state.kind.rawValue
        guard id != 0 && id != 36 && id != 63 && id != 68 else { return }
        if state.kind.isLiquid {
            appendLiquid(position: position, state: state)
            return
        }
        switch id {
        case 6, 30, 31, 32, 37...40, 51, 59, 83: appendCross(position: position, state: state)
        case 27, 28, 55, 66: appendGroundPlane(position: position, state: state)
        case 65: appendLadder(position: position, state: state)
        case 50, 75, 76:
            var center = SIMD3<Float>(0.5, 0, 0.5)
            var tilt = SIMD2<Float>.zero
            switch state.metadata {
            case 1:
                center += SIMD3(-0.1, 0.2, 0)
                tilt.x = -0.4
            case 2:
                center += SIMD3(0.1, 0.2, 0)
                tilt.x = 0.4
            case 3:
                center += SIMD3(0, 0.2, -0.1)
                tilt.y = -0.4
            case 4:
                center += SIMD3(0, 0.2, 0.1)
                tilt.y = 0.4
            default: break
            }
            appendTorch(position: position, state: state, center: center, tilt: tilt)
        case 69: appendLever(position: position, state: state)
        default:
            for bounds in modelBounds(position: position, state: state) {
                appendBox(position: position, state: state, bounds: bounds)
            }
            if id == 93 || id == 94 {
                let delays: [Float] = [-1 / 16, 1 / 16, 3 / 16, 5 / 16]
                let delay = delays[Int(state.metadata >> 2 & 3)]
                let direction = Int(state.metadata & 3)
                let front: [SIMD2<Float>] = [
                    SIMD2(0, -5 / 16), SIMD2(5 / 16, 0), SIMD2(0, 5 / 16), SIMD2(-5 / 16, 0),
                ]
                let back: [SIMD2<Float>] = [
                    SIMD2(0, delay), SIMD2(-delay, 0), SIMD2(0, -delay), SIMD2(delay, 0),
                ]
                for offset in [front[direction], back[direction]] {
                    appendTorch(
                        position: position, state: state,
                        center: SIMD3(0.5 + offset.x, -3 / 16, 0.5 + offset.y))
                }
            }
        }
    }

    private mutating func appendTorch(
        position: BlockPosition, state: BlockState, center: SIMD3<Float>, tilt: SIMD2<Float> = .zero
    ) {
        let tile = BlockAtlas.textureIndex(for: state, face: .bottom)
        let light: UInt8 =
            state.kind.lightEmission > 0 ? 255 : self.light(position: position, state: state, face: .top)
        let low = center + SIMD3(tilt.x, 0, tilt.y)
        let high = center + SIMD3(0, 1, 0)
        let r: Float = 1 / 16
        let cap = center + SIMD3(tilt.x * 0.375, 0.625, tilt.y * 0.375)
        let top = [
            cap + SIMD3(-r, 0, -r), cap + SIMD3(-r, 0, r), cap + SIMD3(r, 0, r), cap + SIMD3(r, 0, -r),
        ]
        appendQuad(
            points: top.map { $0 + vector(position) },
            uv: [SIMD2(7 / 16, 6 / 16), SIMD2(7 / 16, 8 / 16), SIMD2(9 / 16, 8 / 16), SIMD2(9 / 16, 6 / 16)],
            tile: tile, color: SIMD3(repeating: 1), layer: .cutout, light: light)
        let quads = [
            [
                high + SIMD3(-r, 0, -0.5), low + SIMD3(-r, 0, -0.5), low + SIMD3(-r, 0, 0.5),
                high + SIMD3(-r, 0, 0.5),
            ],
            [
                high + SIMD3(r, 0, 0.5), low + SIMD3(r, 0, 0.5), low + SIMD3(r, 0, -0.5),
                high + SIMD3(r, 0, -0.5),
            ],
            [
                high + SIMD3(-0.5, 0, r), low + SIMD3(-0.5, 0, r), low + SIMD3(0.5, 0, r),
                high + SIMD3(0.5, 0, r),
            ],
            [
                high + SIMD3(0.5, 0, -r), low + SIMD3(0.5, 0, -r), low + SIMD3(-0.5, 0, -r),
                high + SIMD3(-0.5, 0, -r),
            ],
        ]
        for quad in quads {
            appendQuad(
                points: quad.map { $0 + vector(position) },
                uv: [SIMD2(0, 0), SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0)],
                tile: tile, color: SIMD3(repeating: 1), layer: .cutout, light: light)
        }
    }

    private mutating func appendLever(position: BlockPosition, state: BlockState) {
        let orientation = Int(state.metadata & 7)
        let base: MeshBounds
        switch orientation {
        case 1: base = MeshBounds(SIMD3(0, 0.25, 0.3125), SIMD3(0.1875, 0.75, 0.6875))
        case 2: base = MeshBounds(SIMD3(0.8125, 0.25, 0.3125), SIMD3(1, 0.75, 0.6875))
        case 3: base = MeshBounds(SIMD3(0.3125, 0.25, 0), SIMD3(0.6875, 0.75, 0.1875))
        case 4: base = MeshBounds(SIMD3(0.3125, 0.25, 0.8125), SIMD3(0.6875, 0.75, 1))
        case 6: base = MeshBounds(SIMD3(0.25, 0, 0.3125), SIMD3(0.75, 0.1875, 0.6875))
        default: base = MeshBounds(SIMD3(0.3125, 0, 0.25), SIMD3(0.6875, 0.1875, 0.75))
        }
        appendBox(position: position, state: BlockState(.cobblestone), bounds: base)
        func rotateX(_ point: SIMD3<Float>, _ angle: Float) -> SIMD3<Float> {
            SIMD3(
                point.x, point.y * cos(angle) - point.z * sin(angle),
                point.y * sin(angle) + point.z * cos(angle))
        }
        func rotateY(_ point: SIMD3<Float>, _ angle: Float) -> SIMD3<Float> {
            SIMD3(
                point.x * cos(angle) + point.z * sin(angle), point.y,
                -point.x * sin(angle) + point.z * cos(angle))
        }
        for face in BlockFace.allCases {
            let points = face.corners.map { corner -> SIMD3<Float> in
                var point = SIMD3<Float>((corner.x - 0.5) / 8, corner.y * 0.625, (corner.z - 0.5) / 8)
                point.z += state.metadata & 8 != 0 ? -0.0625 : 0.0625
                point = rotateX(point, state.metadata & 8 != 0 ? -.pi * 2 / 9 : .pi * 2 / 9)
                if orientation == 6 { point = rotateY(point, .pi / 2) }
                if orientation < 5 {
                    point.y -= 0.375
                    point = rotateX(point, -.pi / 2)
                    point = rotateY(point, [Float(0), -.pi / 2, .pi / 2, .pi, 0][orientation])
                    point.y += 0.5
                } else {
                    point.y += 0.125
                }
                return point + SIMD3(0.5, 0, 0.5) + vector(position)
            }
            let v0: Float = 6 / 16
            let v1: Float = face == .top || face == .bottom ? 8 / 16 : 1
            appendQuad(
                points: points,
                uv: [SIMD2(7 / 16, v1), SIMD2(9 / 16, v1), SIMD2(9 / 16, v0), SIMD2(7 / 16, v0)],
                tile: 96, color: SIMD3(repeating: 1), layer: .cutout,
                light: light(position: position, state: state, face: .top))
        }
    }

    private func layer(for kind: BlockKind) -> MeshLayer {
        if kind == .leaves && !options.fancyLeaves { return .opaque }
        return switch kind.rawValue {
        case 8, 9, 79, 90: .translucent
        case 6, 18, 20, 26...32, 34, 37...40, 50...52, 55, 59, 63...66, 68...72, 75...78, 81, 83, 85, 93, 94,
            96:
            .cutout
        default: .opaque
        }
    }

    private func tint(position: BlockPosition, state: BlockState, face: BlockFace) -> SIMD3<Float> {
        let id = state.kind.rawValue
        if id == 18 {
            if state.metadata & 1 != 0 { return BlockColorMaps.rgb(6_396_257) }
            if state.metadata & 2 != 0 { return BlockColorMaps.rgb(8_431_445) }
        }
        let grass = id == 2 && face == .top || id == 31 && state.metadata != 0
        guard grass || id == 18 else { return SIMD3(repeating: 1) }
        let climate = world.climate(atX: position.x, z: position.z)
        return colorMaps?.color(
            foliage: id == 18, temperature: climate.temperature, humidity: climate.humidity)
            ?? BlockColorMaps.rgb(id == 18 ? 4_764_952 : 9_551_193)
    }

    private func isOccluded(position: BlockPosition, state: BlockState, face: BlockFace) -> Bool {
        let normal = face.offset
        guard
            let neighbor = world.state(
                at: BlockPosition(
                    position.x + normal.x, position.y + normal.y, position.z + normal.z
                ))
        else { return false }
        if neighbor.kind.isOpaque || neighbor.kind == .leaves && !options.fancyLeaves { return true }
        switch state.kind.rawValue {
        case 20, 79, 90: return neighbor.kind == state.kind
        default: return false
        }
    }

    private func light(position: BlockPosition, state: BlockState, face: BlockFace) -> UInt8 {
        let normal = face.offset
        let sample = world.light(
            at: BlockPosition(position.x + normal.x, position.y + normal.y, position.z + normal.z))
        return sample.sky << 4 | max(sample.block, state.kind.lightEmission)
    }

    private func ambientLight(
        position: BlockPosition, state: BlockState, face: BlockFace, corner: SIMD3<Float>
    ) -> UInt32 {
        let n = face.offset
        let p = BlockPosition(position.x + n.x, position.y + n.y, position.z + n.z)
        let a: BlockPosition
        let b: BlockPosition
        switch face {
        case .bottom, .top:
            a = BlockPosition(corner.x == 0 ? -1 : 1, 0, 0)
            b = BlockPosition(0, 0, corner.z == 0 ? -1 : 1)
        case .north, .south:
            a = BlockPosition(corner.x == 0 ? -1 : 1, 0, 0)
            b = BlockPosition(0, corner.y == 0 ? -1 : 1, 0)
        case .west, .east:
            a = BlockPosition(0, 0, corner.z == 0 ? -1 : 1)
            b = BlockPosition(0, corner.y == 0 ? -1 : 1, 0)
        }
        let edgeA = BlockPosition(p.x + a.x, p.y + a.y, p.z + a.z)
        let edgeB = BlockPosition(p.x + b.x, p.y + b.y, p.z + b.z)
        let diagonal =
            blocksGrass(at: edgeA) && blocksGrass(at: edgeB)
            ? edgeA : BlockPosition(edgeA.x + b.x, edgeA.y + b.y, edgeA.z + b.z)
        return [p, edgeA, edgeB, diagonal].enumerated().reduce(0) { packed, entry in
            let sample = world.light(at: entry.element)
            let level = sample.sky << 4 | max(sample.block, state.kind.lightEmission)
            return packed | UInt32(level) << (entry.offset * 8)
        }
    }

    private func blocksGrass(at position: BlockPosition) -> Bool {
        guard let kind = world[position], kind.rawValue != 0 else { return false }
        return !Self.nonGrassBlockingMaterials.contains(kind.rawValue)
    }

    private static let nonGrassBlockingMaterials: Set<UInt8> = [
        6, 27, 28, 31, 32, 37, 38, 39, 40, 50, 51, 55, 59, 65, 66, 69, 75, 76, 77, 78,
        83, 90, 93, 94,
    ]

    private mutating func appendBox(position: BlockPosition, state: BlockState, bounds: MeshBounds) {
        for face in BlockFace.allCases {
            if bounds.touchesBoundary(face) && isOccluded(position: position, state: state, face: face) {
                continue
            }
            let points = face.corners.map { bounds.minimum + $0 * (bounds.maximum - bounds.minimum) }
            let smooth =
                options.smoothLighting && state.kind.lightEmission == 0
                && ![26, 29, 33, 34, 50, 63, 64, 68, 71, 75, 76, 81].contains(state.kind.rawValue)
            let lightSamples =
                smooth
                ? face.corners.map { ambientLight(position: position, state: state, face: face, corner: $0) }
                : nil
            var uv = points.map(face.textureCoordinates)
            if BlockAtlas.mirrorsTexture(for: state, face: face) { uv = uv.map { SIMD2(1 - $0.x, $0.y) } }
            var tile = BlockAtlas.textureIndex(for: state, face: face, at: position, in: world)
            if state.kind == .leaves && !options.fancyLeaves { tile += 1 }
            if state.kind == .grass && face != .top && face != .bottom {
                if world[BlockPosition(position.x, position.y + 1, position.z)] == .snowLayer { tile = 68 }
            }
            appendQuad(
                points: points.map { $0 + vector(position) }, uv: uv,
                tile: tile, color: tint(position: position, state: state, face: face) * face.brightness,
                layer: layer(for: state.kind), light: light(position: position, state: state, face: face),
                lightSamples: lightSamples)
            if state.kind == .grass && face != .top && face != .bottom && tile == 3 {
                let climate = world.climate(atX: position.x, z: position.z)
                let color =
                    colorMaps?.color(
                        foliage: false, temperature: climate.temperature, humidity: climate.humidity)
                    ?? BlockColorMaps.rgb(9_551_193)
                let normal = face.offset.vector * 0.0002
                appendQuad(
                    points: points.map { $0 + vector(position) + normal },
                    uv: points.map(face.textureCoordinates),
                    tile: 38, color: color * face.brightness, layer: .cutout,
                    light: light(position: position, state: state, face: face), lightSamples: lightSamples)
            }
        }
    }

    private mutating func appendCross(position: BlockPosition, state: BlockState) {
        let minimum: Float = 0.05
        let maximum: Float = 0.95
        let points: [[SIMD3<Float>]] = [
            [
                SIMD3(minimum, 0, minimum), SIMD3(maximum, 0, maximum), SIMD3(maximum, 1, maximum),
                SIMD3(minimum, 1, minimum),
            ],
            [
                SIMD3(minimum, 0, maximum), SIMD3(maximum, 0, minimum), SIMD3(maximum, 1, minimum),
                SIMD3(minimum, 1, maximum),
            ],
        ]
        for quad in points {
            appendQuad(
                points: quad.map { $0 + vector(position) }, uv: Self.fullUV,
                tile: BlockAtlas.textureIndex(for: state, face: .top),
                color: tint(position: position, state: state, face: .top), layer: .cutout,
                light: light(position: position, state: state, face: .top))
        }
    }

    private mutating func appendGroundPlane(position: BlockPosition, state: BlockState) {
        var points = BlockFace.top.corners
        for index in points.indices {
            points[index].y = 1 / 16
            if state.kind == .rail || state.kind == .poweredRail || state.kind == .detectorRail {
                switch state.metadata & 7 {
                case 2: points[index].y += points[index].x
                case 3: points[index].y += 1 - points[index].x
                case 4: points[index].y += 1 - points[index].z
                case 5: points[index].y += points[index].z
                default: break
                }
            }
        }
        var uv = BlockFace.top.corners.map(BlockFace.top.textureCoordinates)
        if state.kind == .rail && (state.metadata == 1 || state.metadata == 2 || state.metadata == 3) {
            uv = [uv[1], uv[2], uv[3], uv[0]]
        }
        var color = SIMD3<Float>(repeating: 1)
        if state.kind == .redstoneWire {
            let power = Float(state.metadata) / 15
            color = SIMD3(
                power * 0.6 + (power > 0 ? 0.4 : 0.3), max(0, power * power * 0.7 - 0.5),
                max(0, power * power * 0.6 - 0.7))
        }
        appendQuad(
            points: points.map { $0 + vector(position) }, uv: uv,
            tile: BlockAtlas.textureIndex(for: state, face: .top), color: color, layer: .cutout,
            light: light(position: position, state: state, face: .top))
    }

    private mutating func appendLadder(position: BlockPosition, state: BlockState) {
        let inset: Float = 0.05
        let points: [SIMD3<Float>]
        switch state.metadata {
        case 2:
            points = [
                SIMD3(1, 0, 1 - inset), SIMD3(0, 0, 1 - inset), SIMD3(0, 1, 1 - inset),
                SIMD3(1, 1, 1 - inset),
            ]
        case 4:
            points = [
                SIMD3(1 - inset, 0, 0), SIMD3(1 - inset, 0, 1), SIMD3(1 - inset, 1, 1),
                SIMD3(1 - inset, 1, 0),
            ]
        case 5: points = [SIMD3(inset, 0, 1), SIMD3(inset, 0, 0), SIMD3(inset, 1, 0), SIMD3(inset, 1, 1)]
        default: points = [SIMD3(0, 0, inset), SIMD3(1, 0, inset), SIMD3(1, 1, inset), SIMD3(0, 1, inset)]
        }
        appendQuad(
            points: points.map { $0 + vector(position) }, uv: Self.fullUV, tile: 83,
            color: SIMD3(repeating: 1), layer: .cutout,
            light: light(position: position, state: state, face: .top))
    }

    private mutating func appendLiquid(position: BlockPosition, state: BlockState) {
        let water = state.kind == .water || state.kind == .stillWater
        func sameMaterial(_ other: BlockKind?) -> Bool {
            if water { return other == .water || other == .stillWater }
            return other == .lava || other == .stillLava
        }
        func height(x: Int, z: Int) -> Float {
            var weight: Float = 0
            var total: Float = 0
            for dx in 0...1 {
                for dz in 0...1 {
                    let p = BlockPosition(x - dx, position.y, z - dz)
                    if sameMaterial(world[BlockPosition(p.x, p.y + 1, p.z)]) { return 1 }
                    if let other = world.state(at: p), sameMaterial(other.kind) {
                        let level = other.metadata >= 8 ? 0 : other.metadata
                        let depth = Float(level + 1) / 9
                        if other.metadata == 0 || other.metadata >= 8 {
                            total += depth * 10
                            weight += 10
                        }
                        total += depth
                        weight += 1
                    } else if world[p]?.isSolid != true {
                        total += 1
                        weight += 1
                    }
                }
            }
            return weight == 0 ? 1 : 1 - total / weight
        }
        let heights = [
            height(x: position.x, z: position.z), height(x: position.x + 1, z: position.z),
            height(x: position.x, z: position.z + 1), height(x: position.x + 1, z: position.z + 1),
        ]
        for face in BlockFace.allCases {
            let normal = face.offset
            let neighbor = world[
                BlockPosition(position.x + normal.x, position.y + normal.y, position.z + normal.z)]
            if sameMaterial(neighbor) || neighbor?.isOpaque == true { continue }
            var points = face.corners
            for index in points.indices where points[index].y == 1 {
                let corner = Int(points[index].x) + Int(points[index].z) * 2
                points[index].y = heights[corner] - 0.001
            }
            appendQuad(
                points: points.map { $0 + vector(position) }, uv: points.map(face.textureCoordinates),
                tile: BlockAtlas.textureIndex(for: state, face: face),
                color: SIMD3(repeating: face.brightness), layer: water ? .translucent : .opaque,
                light: light(position: position, state: state, face: face))
        }
    }

    private func modelBounds(position: BlockPosition, state: BlockState) -> [MeshBounds] {
        let metadata = Int(state.metadata)
        switch state.kind.rawValue {
        case 26: return [MeshBounds(.zero, SIMD3(1, 9 / 16, 1))]
        case 29, 33:
            guard metadata & 8 != 0 else { return [MeshBounds()] }
            var bounds = MeshBounds()
            switch metadata & 7 {
            case 0: bounds.minimum.y = 0.25
            case 1: bounds.maximum.y = 0.75
            case 2: bounds.minimum.z = 0.25
            case 3: bounds.maximum.z = 0.75
            case 4: bounds.minimum.x = 0.25
            case 5: bounds.maximum.x = 0.75
            default: break
            }
            return [bounds]
        case 34:
            switch metadata & 7 {
            case 0:
                return [
                    MeshBounds(.zero, SIMD3(1, 0.25, 1)),
                    MeshBounds(SIMD3(0.375, 0.25, 0.375), SIMD3(0.625, 1, 0.625)),
                ]
            case 1:
                return [
                    MeshBounds(SIMD3(0, 0.75, 0), SIMD3(repeating: 1)),
                    MeshBounds(SIMD3(0.375, 0, 0.375), SIMD3(0.625, 0.75, 0.625)),
                ]
            case 2:
                return [
                    MeshBounds(.zero, SIMD3(1, 1, 0.25)),
                    MeshBounds(SIMD3(0.375, 0.375, 0.25), SIMD3(0.625, 0.625, 1)),
                ]
            case 3:
                return [
                    MeshBounds(SIMD3(0, 0, 0.75), SIMD3(repeating: 1)),
                    MeshBounds(SIMD3(0.375, 0.375, 0), SIMD3(0.625, 0.625, 0.75)),
                ]
            case 4:
                return [
                    MeshBounds(.zero, SIMD3(0.25, 1, 1)),
                    MeshBounds(SIMD3(0.25, 0.375, 0.375), SIMD3(1, 0.625, 0.625)),
                ]
            default:
                return [
                    MeshBounds(SIMD3(0.75, 0, 0), SIMD3(repeating: 1)),
                    MeshBounds(SIMD3(0, 0.375, 0.375), SIMD3(0.75, 0.625, 0.625)),
                ]
            }
        case 44: return [MeshBounds(.zero, SIMD3(1, 0.5, 1))]
        case 50, 75, 76: return [MeshBounds(SIMD3(7 / 16, 0, 7 / 16), SIMD3(9 / 16, 10 / 16, 9 / 16))]
        case 53, 67:
            let base = MeshBounds(.zero, SIMD3(1, 0.5, 1))
            switch metadata & 3 {
            case 0: return [base, MeshBounds(SIMD3(0.5, 0.5, 0), SIMD3(1, 1, 1))]
            case 1: return [base, MeshBounds(SIMD3(0, 0.5, 0), SIMD3(0.5, 1, 1))]
            case 2: return [base, MeshBounds(SIMD3(0, 0.5, 0.5), SIMD3(1, 1, 1))]
            default: return [base, MeshBounds(SIMD3(0, 0.5, 0), SIMD3(1, 1, 0.5))]
            }
        case 60: return [MeshBounds(.zero, SIMD3(1, 15 / 16, 1))]
        case 64, 71:
            let orientation = metadata & 4 == 0 ? (metadata - 1) & 3 : metadata & 3
            switch orientation {
            case 0: return [MeshBounds(.zero, SIMD3(1, 1, 3 / 16))]
            case 1: return [MeshBounds(SIMD3(13 / 16, 0, 0), SIMD3(repeating: 1))]
            case 2: return [MeshBounds(SIMD3(0, 0, 13 / 16), SIMD3(repeating: 1))]
            default: return [MeshBounds(.zero, SIMD3(3 / 16, 1, 1))]
            }
        case 70, 72:
            return [
                MeshBounds(SIMD3(1 / 16, 0, 1 / 16), SIMD3(15 / 16, metadata == 0 ? 1 / 16 : 1 / 32, 15 / 16))
            ]
        case 77:
            let thickness: Float = metadata & 8 == 0 ? 1 / 8 : 1 / 16
            switch metadata & 7 {
            case 1: return [MeshBounds(SIMD3(0, 0.375, 0.3125), SIMD3(thickness, 0.625, 0.6875))]
            case 2: return [MeshBounds(SIMD3(1 - thickness, 0.375, 0.3125), SIMD3(1, 0.625, 0.6875))]
            case 3: return [MeshBounds(SIMD3(0.3125, 0.375, 0), SIMD3(0.6875, 0.625, thickness))]
            default: return [MeshBounds(SIMD3(0.3125, 0.375, 1 - thickness), SIMD3(0.6875, 0.625, 1))]
            }
        case 78: return [MeshBounds(.zero, SIMD3(1, Float(1 + (metadata & 7)) / 8, 1))]
        case 81: return [MeshBounds(SIMD3(1 / 16, 0, 1 / 16), SIMD3(15 / 16, 1, 15 / 16))]
        case 85:
            var boxes = [MeshBounds(SIMD3(6 / 16, 0, 6 / 16), SIMD3(10 / 16, 1, 10 / 16))]
            for direction in [BlockFace.north, .south, .west, .east] {
                let offset = direction.offset
                let neighbor = world[BlockPosition(position.x + offset.x, position.y, position.z + offset.z)]
                guard neighbor == .fence || neighbor?.isOpaque == true else { continue }
                for y in [Float(6) / 16, Float(12) / 16] {
                    var minimum = SIMD3<Float>(7 / 16, y, 7 / 16)
                    var maximum = SIMD3<Float>(9 / 16, y + 3 / 16, 9 / 16)
                    switch direction {
                    case .north: minimum.z = 0
                    case .south: maximum.z = 1
                    case .west: minimum.x = 0
                    case .east: maximum.x = 1
                    default: break
                    }
                    boxes.append(MeshBounds(minimum, maximum))
                }
            }
            return boxes
        case 90:
            let xNeighbor =
                world[BlockPosition(position.x - 1, position.y, position.z)] == .portal
                || world[BlockPosition(position.x + 1, position.y, position.z)] == .portal
            if xNeighbor { return [MeshBounds(SIMD3(0, 0, 6 / 16), SIMD3(1, 1, 10 / 16))] }
            return [MeshBounds(SIMD3(6 / 16, 0, 0), SIMD3(10 / 16, 1, 1))]
        case 92:
            return [MeshBounds(SIMD3(Float(1 + metadata * 2) / 16, 0, 1 / 16), SIMD3(15 / 16, 0.5, 15 / 16))]
        case 93, 94: return [MeshBounds(.zero, SIMD3(1, 1 / 8, 1))]
        case 96:
            if metadata & 4 == 0 { return [MeshBounds(.zero, SIMD3(1, 3 / 16, 1))] }
            switch metadata & 3 {
            case 0: return [MeshBounds(SIMD3(0, 0, 13 / 16), SIMD3(repeating: 1))]
            case 1: return [MeshBounds(.zero, SIMD3(1, 1, 3 / 16))]
            case 2: return [MeshBounds(SIMD3(13 / 16, 0, 0), SIMD3(repeating: 1))]
            default: return [MeshBounds(.zero, SIMD3(3 / 16, 1, 1))]
            }
        default: return [MeshBounds()]
        }
    }

    private mutating func appendQuad(
        points: [SIMD3<Float>], uv: [SIMD2<Float>], tile: Int,
        color: SIMD3<Float>, layer: MeshLayer, light: UInt8 = 240, lightSamples: [UInt32]? = nil
    ) {
        let tileOrigin = SIMD2<Float>(Float(tile & 15), Float(tile >> 4)) * 16
        let vertices = [0, 1, 2, 0, 2, 3].map { index in
            BlockVertex(
                position: points[index], color: color,
                uv: (tileOrigin + uv[index] * 15.98 + SIMD2(repeating: 0.01)) / 256,
                light: light, lightSamples: lightSamples?[index])
        }
        switch layer {
        case .opaque: opaque.append(contentsOf: vertices)
        case .cutout: cutout.append(contentsOf: vertices)
        case .translucent:
            translucent.append(
                TranslucentBlockFace(
                    center: (points[0] + points[1] + points[2] + points[3]) / 4, vertices: vertices))
        }
    }

    private static let fullUV: [SIMD2<Float>] = [SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 0)]
}
