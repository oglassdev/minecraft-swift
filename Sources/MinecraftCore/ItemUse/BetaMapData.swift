import Foundation

public struct BetaMapMarker: Equatable, Sendable {
    public var type: UInt8
    public var x: Int8
    public var y: Int8
    public var rotation: UInt8
    public var pixelPosition: SIMD2<Float> { SIMD2(64 + Float(x) / 2, 64 + Float(y) / 2) }
}

public struct BetaMapData: Equatable, Sendable {
    public let id: Int16
    public var centerX: Int32
    public var centerZ: Int32
    public var dimension: Int8
    public let scale: UInt8
    public private(set) var colors: [UInt8]
    public private(set) var updateCounter: Int32 = 0
    public private(set) var revision: UInt64 = 0
    public private(set) var networkMarkers: [BetaMapMarker] = []
    var originalFields: [String: NBTTag] = [:]

    public init(
        id: Int16, centerX: Int32, centerZ: Int32, dimension: Int8, scale: UInt8 = 3,
        colors: [UInt8] = Array(repeating: 0, count: 16384)
    ) {
        precondition(colors.count == 16384)
        self.id = id
        self.centerX = centerX
        self.centerZ = centerZ
        self.dimension = dimension
        self.scale = min(4, scale)
        self.colors = colors
    }

    public func marker(position: SIMD3<Double>, yaw: Float, dimension: Int8) -> BetaMapMarker? {
        guard dimension == self.dimension else { return nil }
        let factor = Float(1 << scale)
        let x = Float(position.x - Double(centerX)) / factor
        let z = Float(position.z - Double(centerZ)) / factor
        guard x >= -64, x <= 64, z >= -64, z <= 64 else { return nil }
        var rotation = Int(Double((yaw * 180 / Float(Double.pi) + 180) * 16 / 360) + 0.5)
        if self.dimension < 0 {
            let time = updateCounter / 10
            rotation = Int((time &* time &* 34_187_121 &+ time &* 121) >> 15 & 15)
        }
        return BetaMapMarker(
            type: 0, x: Int8(truncatingIfNeeded: Int(Double(x * 2) + 0.5)),
            y: Int8(truncatingIfNeeded: Int(Double(z * 2) + 0.5)),
            rotation: UInt8(truncatingIfNeeded: rotation) & 15)
    }

    public var rgbaPixels: [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(16384 * 4)
        for (index, value) in colors.enumerated() {
            let color = Int(value) / 4
            guard color > 0, color < Self.palette.count else {
                result += [0, 0, 0, UInt8(((index + index / 128) & 1) * 8 + 16)]
                continue
            }
            let rgb = Self.palette[color]
            let shade = value & 3 == 2 ? 255 : (value & 3 == 0 ? 180 : 220)
            result += [
                UInt8((rgb >> 16 & 255) * shade / 255), UInt8((rgb >> 8 & 255) * shade / 255),
                UInt8((rgb & 255) * shade / 255), 255,
            ]
        }
        return result
    }

    /// Missing chunks are left unexplored; storage must load them before this update.
    public mutating func update(world: BlockWorld, position: SIMD3<Double>) {
        guard world.dimension == dimension else { return }
        let factor = 1 << scale
        let playerX = Int(floor(position.x - Double(centerX))) / factor + 64
        let playerZ = Int(floor(position.z - Double(centerZ))) / factor + 64
        let radius = 128 / factor / (world.dimension == -1 ? 2 : 1)
        updateCounter &+= 1
        var changed = false
        for px in (playerX - radius + 1)..<(playerX + radius) where (px & 15) == (Int(updateCounter) & 15) {
            var previousHeight = 0.0
            for pz in (playerZ - radius - 1)..<(playerZ + radius) {
                guard px >= 0, px < 128, pz >= -1, pz < 128 else { continue }
                let dx = px - playerX
                let dz = pz - playerZ
                let edge = dx * dx + dz * dz > (radius - 2) * (radius - 2)
                let x = (Int(centerX) / factor + px - 64) * factor
                let z = (Int(centerZ) / factor + pz - 64) * factor
                guard let chunk = world.chunks[ChunkPosition(x >> 4, z >> 4)] else { continue }
                var counts = Array(repeating: 0, count: 256)
                var depth = 0
                var height = 0.0
                if world.dimension == -1 {
                    var value = Int32(truncatingIfNeeded: x) &+ Int32(truncatingIfNeeded: z) &* 231871
                    value = value &* value &* 31_287_121 &+ value &* 11
                    counts[(value >> 20 & 1) == 0 ? 3 : 1] += 10
                    height = 100
                } else {
                    for sx in 0..<factor {
                        for sz in 0..<factor {
                            let bx = (x & 15) + sx
                            let bz = (z & 15) + sz
                            var y = Self.height(chunk, x: bx, z: bz) + 1
                            var block: UInt8 = 0
                            if y > 1 {
                                while y > 0 {
                                    block = chunk[bx, y - 1, bz]?.kind.rawValue ?? 0
                                    if block != 0 && Self.materialColors[Int(block)] != 0 { break }
                                    y -= 1
                                }
                                if BlockKind(rawValue: block)?.isLiquid == true {
                                    var liquidY = y - 1
                                    var liquid: BlockKind?
                                    repeat {
                                        liquid = chunk[bx, liquidY, bz]?.kind
                                        liquidY -= 1
                                        depth += 1
                                    } while liquidY > 0 && liquid?.isLiquid == true
                                }
                            }
                            height += Double(y) / Double(factor * factor)
                            counts[Int(block)] += 1
                        }
                    }
                }
                depth /= factor * factor
                var mostCommon = 0
                for block in 1..<256 where counts[block] > counts[mostCommon] { mostCommon = block }
                var slope =
                    (height - previousHeight) * 4 / Double(factor + 4) + (Double((px + pz) & 1) - 0.5) * 0.4
                var shade: UInt8 = slope > 0.6 ? 2 : (slope < -0.6 ? 0 : 1)
                let color = Self.materialColors[mostCommon]
                if color == 12 {
                    slope = Double(depth) * 0.1 + Double((px + pz) & 1) * 0.2
                    shade = slope < 0.5 ? 2 : (slope > 0.9 ? 0 : 1)
                }
                previousHeight = height
                if pz >= 0 && dx * dx + dz * dz < radius * radius && (!edge || (px + pz) & 1 != 0) {
                    let index = px + pz * 128
                    let value = UInt8(color * 4) + shade
                    if colors[index] != value {
                        colors[index] = value
                        changed = true
                    }
                }
            }
        }
        if changed { revision &+= 1 }
    }

    public mutating func applyNetwork(_ bytes: [UInt8]) {
        if bytes.first == 1 {
            networkMarkers = stride(from: 1, to: bytes.count - 2, by: 3).map { index in
                BetaMapMarker(
                    type: bytes[index] & 15, x: Int8(bitPattern: bytes[index + 1]),
                    y: Int8(bitPattern: bytes[index + 2]), rotation: bytes[index] >> 4)
            }
            revision &+= 1
            return
        }
        guard bytes.count >= 3, bytes[0] == 0 else { return }
        let x = Int(bytes[1])
        let y = Int(bytes[2])
        guard x < 128, y < 128, bytes.count - 3 <= 128 - y else { return }
        for i in 3..<bytes.count { colors[x + (y + i - 3) * 128] = bytes[i] }
        revision &+= 1
    }

    private static func height(_ chunk: Chunk, x: Int, z: Int) -> Int {
        for y in (0..<128).reversed() where chunk[x, y, z]?.kind.lightOpacity ?? 0 > 0 { return y + 1 }
        return 0
    }

    private static let palette = [
        0, 8_368_696, 16_247_203, 10_987_431, 16_711_680, 10_526_975, 10_987_431,
        31744, 16_777_215, 10_791_096, 12_020_271, 7_368_816, 4_210_943, 6_837_042,
    ]
    private static let materialColors: [Int] =
        [
            0, 11, 1, 10, 11, 13, 7, 11, 12, 12, 4, 4, 2, 2, 11, 11, 11, 13, 7, 3, 0, 11, 11, 11, 11,
            13, 3, 0, 0, 11, 3, 7, 7, 11, 11, 3, 11, 7, 7, 7, 7, 6, 6, 11, 11, 11, 4, 13, 11, 11,
            0, 0, 11, 13, 13, 0, 11, 6, 13, 7, 10, 11, 11, 13, 13, 0, 0, 11, 13, 0, 11, 6, 13, 11,
            11, 0, 0, 0, 8, 5, 8, 7, 9, 7, 13, 13, 7, 11, 2, 11, 0, 7, 0, 0, 0, 13, 13,
        ] + Array(repeating: 0, count: 159)
}
