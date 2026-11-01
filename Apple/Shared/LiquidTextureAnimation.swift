import Foundation
import Metal
import MinecraftCore

/// The original terrain texture effects update at the simulation tick rate.
struct LiquidTextureAnimation {
    private var elapsed: Float = 0.05
    private var tickCount = 0
    private let portalFrames = Self.makePortalFrames()
    private var fire = [FireTile(), FireTile()]
    private var tiles = [
        Tile(water: true, flowing: false, index: 205),
        Tile(water: true, flowing: true, index: 206),
        Tile(water: false, flowing: false, index: 237),
        Tile(water: false, flowing: true, index: 238),
    ]

    mutating func encode(
        deltaTime: Float, device: MTLDevice, atlas: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        elapsed += deltaTime
        guard elapsed >= 0.05 else { return }
        while elapsed >= 0.05 {
            for index in tiles.indices { tiles[index].tick() }
            for index in fire.indices { fire[index].tick() }
            tickCount += 1
            elapsed -= 0.05
        }
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else { return }
        encoder.label = "Animate Beta terrain textures"
        for tile in tiles {
            Self.upload(
                tile.pixels(), index: tile.index, repeats: tile.flowing ? 2 : 1,
                device: device, atlas: atlas, encoder: encoder)
        }
        Self.upload(portalFrames[tickCount & 31], index: 14, device: device, atlas: atlas, encoder: encoder)
        for index in fire.indices {
            Self.upload(
                fire[index].pixels(), index: 31 + index * 16, device: device, atlas: atlas, encoder: encoder)
        }
        encoder.endEncoding()
    }

    static func upload(
        _ pixels: [UInt8], index: Int, repeats: Int = 1, device: MTLDevice,
        atlas: MTLTexture, encoder: MTLBlitCommandEncoder
    ) {
        let bgra = atlas.pixelFormat == .bgra8Unorm || atlas.pixelFormat == .bgra8Unorm_srgb
        var upload = [UInt8](repeating: 0, count: 256 * 16)
        for y in 0..<16 {
            for x in 0..<16 {
                let source = (y * 16 + x) * 4
                let destination = y * 256 + x * 4
                upload[destination] = pixels[source + (bgra ? 2 : 0)]
                upload[destination + 1] = pixels[source + 1]
                upload[destination + 2] = pixels[source + (bgra ? 0 : 2)]
                upload[destination + 3] = pixels[source + 3]
            }
        }
        let buffer = upload.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let address = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: address, length: bytes.count, options: .storageModeShared)
        }
        guard let buffer else { return }
        for y in 0..<repeats {
            for x in 0..<repeats {
                encoder.copy(
                    from: buffer, sourceOffset: 0, sourceBytesPerRow: 256,
                    sourceBytesPerImage: 256 * 16, sourceSize: MTLSize(width: 16, height: 16, depth: 1),
                    to: atlas, destinationSlice: 0, destinationLevel: 0,
                    destinationOrigin: MTLOrigin(
                        x: (index & 15) * 16 + x * 16, y: (index >> 4) * 16 + y * 16, z: 0))
            }
        }
    }

    static func makePortalFrames() -> [[UInt8]] {
        var random = JavaRandom(seed: 100)
        return (0..<32).map { frame in
            var pixels = [UInt8](repeating: 0, count: 1024)
            for x in 0..<16 {
                for y in 0..<16 {
                    var intensity: Float = 0
                    for layer in 0..<2 {
                        var u = Float(x - layer * 8) / 16 * 2
                        var v = Float(y - layer * 8) / 16 * 2
                        if u < -1 { u += 2 }
                        if u >= 1 { u -= 2 }
                        if v < -1 { v += 2 }
                        if v >= 1 { v -= 2 }
                        let radius = u * u + v * v
                        let angle =
                            Float(atan2(Double(v), Double(u)))
                            + (Float(frame) / 32 * .pi * 2 - radius * 10 + Float(layer * 2))
                            * Float(layer * 2 - 1)
                        let sineIndex = Int(angle * 10430.378) & 65535
                        let sine = Float(sin(Double(sineIndex) * .pi * 2 / 65536))
                        intensity += (sine + 1) / 2 / (radius + 1) * 0.5
                    }
                    intensity += random.nextFloat() * 0.1
                    let offset = (y * 16 + x) * 4
                    pixels[offset] = UInt8(truncatingIfNeeded: Int(intensity * intensity * 200 + 55))
                    pixels[offset + 1] = UInt8(
                        truncatingIfNeeded: Int(intensity * intensity * intensity * intensity * 255))
                    pixels[offset + 2] = UInt8(truncatingIfNeeded: Int(intensity * 100 + 155))
                    pixels[offset + 3] = pixels[offset + 2]
                }
            }
            return pixels
        }
    }

    private struct FireTile {
        var heat = [Float](repeating: 0, count: 320)
        var nextHeat = [Float](repeating: 0, count: 320)

        mutating func tick() {
            for x in 0..<16 {
                for y in 0..<20 {
                    var weight = 18
                    var total = heat[x + (y + 1) % 20 * 16] * Float(weight)
                    for nx in x - 1...x + 1 {
                        for ny in y...y + 1 {
                            if (0..<16).contains(nx) && (0..<20).contains(ny) { total += heat[nx + ny * 16] }
                            weight += 1
                        }
                    }
                    nextHeat[x + y * 16] = total / (Float(weight) * 1.06)
                    if y == 19 {
                        nextHeat[x + y * 16] = Float(
                            Double.random(in: 0..<1) * Double.random(in: 0..<1) * Double.random(in: 0..<1) * 4
                                + Double.random(in: 0..<1) * 0.1 + 0.2)
                    }
                }
            }
            swap(&heat, &nextHeat)
        }

        func pixels() -> [UInt8] {
            var result = [UInt8](repeating: 0, count: 1024)
            for index in 0..<256 {
                let intensity = min(1, max(0, heat[index] * 1.8))
                result[index * 4] = UInt8(intensity * 155 + 100)
                result[index * 4 + 1] = UInt8(intensity * intensity * 255)
                result[index * 4 + 2] = UInt8(pow(intensity, 10) * 255)
                result[index * 4 + 3] = intensity < 0.5 ? 0 : 255
            }
            return result
        }
    }

    private struct Tile {
        let water: Bool
        let flowing: Bool
        let index: Int
        private var heights = [Float](repeating: 0, count: 256)
        private var nextHeights = [Float](repeating: 0, count: 256)
        private var heat = [Float](repeating: 0, count: 256)
        private var impulses = [Float](repeating: 0, count: 256)
        private var tickCount = 0

        init(water: Bool, flowing: Bool, index: Int) {
            self.water = water
            self.flowing = flowing
            self.index = index
        }

        mutating func tick() {
            tickCount += 1
            for x in 0..<16 {
                for y in 0..<16 {
                    let index = x + y * 16
                    var total: Float = 0
                    if water {
                        if flowing {
                            for neighborY in (y - 2)...y { total += heights[x + (neighborY & 15) * 16] }
                        } else {
                            for neighborX in (x - 1)...(x + 1) { total += heights[(neighborX & 15) + y * 16] }
                        }
                        nextHeights[index] = total / (flowing ? 3.2 : 3.3) + heat[index] * 0.8
                    } else {
                        let offsetX = Int(sin(Float(y) * .pi * 2 / 16) * 1.2)
                        let offsetY = Int(sin(Float(x) * .pi * 2 / 16) * 1.2)
                        for neighborX in (x - 1)...(x + 1) {
                            for neighborY in (y - 1)...(y + 1) {
                                total +=
                                    heights[((neighborX + offsetX) & 15) + ((neighborY + offsetY) & 15) * 16]
                            }
                        }
                        let neighbors =
                            heat[index] + heat[((x + 1) & 15) + y * 16]
                            + heat[((x + 1) & 15) + ((y + 1) & 15) * 16]
                            + heat[x + ((y + 1) & 15) * 16]
                        nextHeights[index] = total / 10 + neighbors / 4 * 0.8
                        heat[index] = max(0, heat[index] + impulses[index] * 0.01)
                        impulses[index] -= 0.06
                        if Float.random(in: 0..<1) < 0.005 { impulses[index] = 1.5 }
                    }
                }
            }
            if water {
                for index in 0..<256 {
                    heat[index] = max(0, heat[index] + impulses[index] * 0.05)
                    impulses[index] -= flowing ? 0.3 : 0.1
                    if Float.random(in: 0..<1) < (flowing ? 0.2 : 0.05) { impulses[index] = 0.5 }
                }
            }
            swap(&heights, &nextHeights)
        }

        func pixels() -> [UInt8] {
            var pixels = [UInt8](repeating: 0, count: 1024)
            let scroll = flowing ? (water ? tickCount * 16 : tickCount / 3 * 16) : 0
            for index in 0..<256 {
                let intensity = min(1, max(0, heights[(index - scroll) & 255] * (water ? 1 : 2)))
                let squared = intensity * intensity
                if water {
                    pixels[index * 4] = UInt8(32 + squared * 32)
                    pixels[index * 4 + 1] = UInt8(50 + squared * 64)
                    pixels[index * 4 + 2] = 255
                    pixels[index * 4 + 3] = UInt8(146 + squared * 50)
                } else {
                    pixels[index * 4] = UInt8(intensity * 100 + 155)
                    pixels[index * 4 + 1] = UInt8(squared * 255)
                    pixels[index * 4 + 2] = UInt8(squared * squared * 128)
                    pixels[index * 4 + 3] = 255
                }
            }
            return pixels
        }
    }
}
