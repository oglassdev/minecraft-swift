import Foundation

public struct BetaNetherGenerator: Sendable {
    public let seed: Int64
    var random: JavaRandom
    private let lowerNoise: BetaOctaveNoise
    private let upperNoise: BetaOctaveNoise
    private let selectorNoise: BetaOctaveNoise
    private let surfaceChoiceNoise: BetaOctaveNoise
    private let surfaceDepthNoise: BetaOctaveNoise

    public init(seed: Int64) {
        self.seed = seed
        var random = JavaRandom(seed: seed)
        lowerNoise = BetaOctaveNoise(random: &random, count: 16)
        upperNoise = BetaOctaveNoise(random: &random, count: 16)
        selectorNoise = BetaOctaveNoise(random: &random, count: 8)
        surfaceChoiceNoise = BetaOctaveNoise(random: &random, count: 4)
        surfaceDepthNoise = BetaOctaveNoise(random: &random, count: 4)
        // These two unused fields still advance the original provider's random stream.
        _ = BetaOctaveNoise(random: &random, count: 10)
        _ = BetaOctaveNoise(random: &random, count: 16)
        self.random = random
    }

    public mutating func generateChunk(x: Int, z: Int) -> Chunk {
        random.setSeed(Int64(x) &* 341_873_128_712 &+ Int64(z) &* 132_897_987_541)
        var blocks = terrain(x: x, z: z)
        replaceSurface(in: &blocks, x: x, z: z)
        BetaCaveGenerator(seed: seed, nether: true).carve(chunkX: x, chunkZ: z, blocks: &blocks)
        var chunk = Chunk(position: ChunkPosition(x: x, z: z))
        chunk.skyLight = Array(repeating: 0, count: Chunk.volume)
        for bx in 0..<16 {
            for bz in 0..<16 {
                chunk.setClimate(temperature: 1, humidity: 0, x: bx, z: bz)
                for by in 0..<128 {
                    let index = Chunk.index(x: bx, y: by, z: bz)
                    if let kind = BlockKind(rawValue: blocks[index]), kind != .air {
                        chunk[bx, by, bz] = BlockState(kind)
                    }
                }
            }
        }
        return chunk
    }

    private func density(x: Int, z: Int) -> [Double] {
        let horizontalScale = 684.412
        let verticalScale = 2053.236
        let selector = selectorNoise.generate(
            x: Double(x), y: 0, z: Double(z), sizeX: 5, sizeY: 17, sizeZ: 5,
            scaleX: horizontalScale / 80, scaleY: verticalScale / 60, scaleZ: horizontalScale / 80)
        let lower = lowerNoise.generate(
            x: Double(x), y: 0, z: Double(z), sizeX: 5, sizeY: 17, sizeZ: 5,
            scaleX: horizontalScale, scaleY: verticalScale, scaleZ: horizontalScale)
        let upper = upperNoise.generate(
            x: Double(x), y: 0, z: Double(z), sizeX: 5, sizeY: 17, sizeZ: 5,
            scaleX: horizontalScale, scaleY: verticalScale, scaleZ: horizontalScale)
        let shape = (0..<17).map { y -> Double in
            var value = cos(Double(y) * .pi * 6 / 17) * 2
            var distance = Double(y > 8 ? 16 - y : y)
            if distance < 4 {
                distance = 4 - distance
                value -= distance * distance * distance * 10
            }
            return value
        }
        return selector.indices.map { index in
            let y = index % 17
            let minimum = lower[index] / 512
            let maximum = upper[index] / 512
            let blend = (selector[index] / 10 + 1) / 2
            var value: Double
            if blend < 0 {
                value = minimum
            } else if blend > 1 {
                value = maximum
            } else {
                value = minimum + (maximum - minimum) * blend
            }
            value -= shape[y]
            if y > 13 {
                let fade = Double(Float(y - 13) / 3)
                value = value * (1 - fade) + -10 * fade
            }
            return value
        }
    }

    private func terrain(x: Int, z: Int) -> [UInt8] {
        let values = density(x: x * 4, z: z * 4)
        var blocks = Array(repeating: UInt8(0), count: Chunk.volume)
        for cellX in 0..<4 {
            for cellZ in 0..<4 {
                for cellY in 0..<16 {
                    let near = (cellX * 5 + cellZ) * 17 + cellY
                    let far = ((cellX + 1) * 5 + cellZ) * 17 + cellY
                    var first = values[near]
                    var second = values[near + 17]
                    var third = values[far]
                    var fourth = values[far + 17]
                    let dy1 = (values[near + 1] - first) * 0.125
                    let dy2 = (values[near + 18] - second) * 0.125
                    let dy3 = (values[far + 1] - third) * 0.125
                    let dy4 = (values[far + 18] - fourth) * 0.125
                    for subY in 0..<8 {
                        var start = first
                        var end = second
                        let dx1 = (third - first) * 0.25
                        let dx2 = (fourth - second) * 0.25
                        for subX in 0..<4 {
                            let bx = cellX * 4 + subX
                            let by = cellY * 8 + subY
                            var value = start
                            let dz = (end - start) * 0.25
                            for subZ in 0..<4 {
                                let bz = cellZ * 4 + subZ
                                blocks[Chunk.index(x: bx, y: by, z: bz)] = value > 0 ? 87 : (by < 32 ? 11 : 0)
                                value += dz
                            }
                            start += dx1
                            end += dx2
                        }
                        first += dy1
                        second += dy2
                        third += dy3
                        fourth += dy4
                    }
                }
            }
        }
        return blocks
    }

    private mutating func replaceSurface(in blocks: inout [UInt8], x: Int, z: Int) {
        let soulSand = surfaceChoiceNoise.generate(
            x: Double(x * 16), y: Double(z * 16), z: 0,
            sizeX: 16, sizeY: 16, sizeZ: 1, scaleX: 0.03125, scaleY: 0.03125, scaleZ: 1)
        let gravel = surfaceChoiceNoise.generate(
            x: Double(x * 16), y: 109.0134, z: Double(z * 16),
            sizeX: 16, sizeY: 1, sizeZ: 16, scaleX: 0.03125, scaleY: 1, scaleZ: 0.03125)
        let thickness = surfaceDepthNoise.generate(
            x: Double(x * 16), y: Double(z * 16), z: 0,
            sizeX: 16, sizeY: 16, sizeZ: 1, scaleX: 0.0625, scaleY: 0.0625, scaleZ: 0.0625)
        for bz in 0..<16 {
            for bx in 0..<16 {
                let index = bx * 16 + bz
                let hasSoulSand = soulSand[index] + random.nextDouble() * 0.2 > 0
                let hasGravel = gravel[index] + random.nextDouble() * 0.2 > 0
                let depth = Int(thickness[index] / 3 + 3 + random.nextDouble() * 0.25)
                var remaining = -1
                var top: UInt8 = 87
                var filler: UInt8 = 87
                for by in (0..<128).reversed() {
                    let blockIndex = Chunk.index(x: bx, y: by, z: bz)
                    if by >= 127 - random.nextInt(bound: 5) {
                        blocks[blockIndex] = 7
                    } else if by <= random.nextInt(bound: 5) {
                        blocks[blockIndex] = 7
                    } else if blocks[blockIndex] == 0 {
                        remaining = -1
                    } else if blocks[blockIndex] == 87 {
                        if remaining == -1 {
                            if depth <= 0 {
                                top = 0
                                filler = 87
                            } else if by >= 60 && by <= 65 {
                                top = 87
                                filler = 87
                                if hasGravel { top = 13 }
                                if hasSoulSand {
                                    top = 88
                                    filler = 88
                                }
                            }
                            if by < 64 && top == 0 { top = 11 }
                            remaining = depth
                            blocks[blockIndex] = by >= 63 ? top : filler
                        } else if remaining > 0 {
                            remaining -= 1
                            blocks[blockIndex] = filler
                        }
                    }
                }
            }
        }
    }
}
