/// The Beta 1.7.3 overworld's unpopulated terrain and surface generation.
public struct BetaTerrainGenerator: Sendable {
    public let seed: Int64
    public let climate: BetaClimateSource
    private let lowerNoise: BetaOctaveNoise
    private let upperNoise: BetaOctaveNoise
    private let selectorNoise: BetaOctaveNoise
    private let beachNoise: BetaOctaveNoise
    private let surfaceNoise: BetaOctaveNoise
    private let scaleNoise: BetaOctaveNoise
    private let depthNoise: BetaOctaveNoise
    let treeNoise: BetaOctaveNoise

    public init(seed: Int64) {
        self.seed = seed
        climate = BetaClimateSource(seed: seed)
        var random = JavaRandom(seed: seed)
        lowerNoise = BetaOctaveNoise(random: &random, count: 16)
        upperNoise = BetaOctaveNoise(random: &random, count: 16)
        selectorNoise = BetaOctaveNoise(random: &random, count: 8)
        beachNoise = BetaOctaveNoise(random: &random, count: 4)
        surfaceNoise = BetaOctaveNoise(random: &random, count: 4)
        scaleNoise = BetaOctaveNoise(random: &random, count: 10)
        depthNoise = BetaOctaveNoise(random: &random, count: 16)
        treeNoise = BetaOctaveNoise(random: &random, count: 8)
    }

    public mutating func generateChunk(x: Int, z: Int) -> Chunk {
        let samples = climate.region(x: x * 16, z: z * 16)
        var blocks = terrain(x: x, z: z, climate: samples)
        replaceSurface(in: &blocks, x: x, z: z, climate: samples)
        BetaCaveGenerator(seed: seed).carve(chunkX: x, chunkZ: z, blocks: &blocks)
        var chunk = Chunk(position: ChunkPosition(x: x, z: z))
        for bx in 0..<16 {
            for bz in 0..<16 {
                let climate = samples[bx * 16 + bz]
                chunk.setClimate(temperature: climate.temperature, humidity: climate.humidity, x: bx, z: bz)
                var sky: UInt8 = 15
                for by in (0..<128).reversed() {
                    let index = Chunk.index(x: bx, y: by, z: bz)
                    let id = blocks[index]
                    if let kind = BlockKind(rawValue: id), kind != .air {
                        chunk[bx, by, bz] = BlockState(kind)
                        if kind.isOpaque {
                            sky = 0
                        } else if kind.isLiquid && sky > 0 {
                            sky = sky > 3 ? sky - 3 : 0
                        }
                    }
                    chunk.skyLight[index] = sky
                }
            }
        }
        return chunk
    }

    private func density(x: Int, z: Int, climate: [BetaClimateSample]) -> [Double] {
        let horizontalScale = 684.412
        let verticalScale = 684.412
        let scale = scaleNoise.generate(
            x: Double(x), y: 10, z: Double(z), sizeX: 5, sizeY: 1, sizeZ: 5,
            scaleX: 1.121, scaleY: 1, scaleZ: 1.121)
        let depth = depthNoise.generate(
            x: Double(x), y: 10, z: Double(z), sizeX: 5, sizeY: 1, sizeZ: 5,
            scaleX: 200, scaleY: 1, scaleZ: 200)
        let selector = selectorNoise.generate(
            x: Double(x), y: 0, z: Double(z), sizeX: 5, sizeY: 17, sizeZ: 5,
            scaleX: horizontalScale / 80, scaleY: verticalScale / 160, scaleZ: horizontalScale / 80)
        let lower = lowerNoise.generate(
            x: Double(x), y: 0, z: Double(z), sizeX: 5, sizeY: 17, sizeZ: 5,
            scaleX: horizontalScale, scaleY: verticalScale, scaleZ: horizontalScale)
        let upper = upperNoise.generate(
            x: Double(x), y: 0, z: Double(z), sizeX: 5, sizeY: 17, sizeZ: 5,
            scaleX: horizontalScale, scaleY: verticalScale, scaleZ: horizontalScale)
        var result = Array(repeating: 0.0, count: 5 * 17 * 5)
        var column = 0
        var index = 0
        for bx in 0..<5 {
            let climateX = bx * 3 + 1
            for bz in 0..<5 {
                let sample = climate[climateX * 16 + bz * 3 + 1]
                let wetness = sample.humidity * sample.temperature
                var aridity = 1 - wetness
                aridity *= aridity
                aridity *= aridity
                aridity = 1 - aridity
                var shape = (scale[column] + 256) / 512
                shape *= aridity
                if shape > 1 { shape = 1 }
                var elevation = depth[column] / 8000
                if elevation < 0 { elevation = -elevation * 0.3 }
                elevation = elevation * 3 - 2
                if elevation < 0 {
                    elevation /= 2
                    if elevation < -1 { elevation = -1 }
                    elevation /= 1.4
                    elevation /= 2
                    shape = 0
                } else {
                    if elevation > 1 { elevation = 1 }
                    elevation /= 8
                }
                if shape < 0 { shape = 0 }
                shape += 0.5
                elevation = elevation * 17 / 16
                let center = 17.0 / 2 + elevation * 4
                column += 1
                for by in 0..<17 {
                    var vertical = (Double(by) - center) * 12 / shape
                    if vertical < 0 { vertical *= 4 }
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
                    value -= vertical
                    if by > 13 {
                        let fade = Double(Float(by - 13) / 3)
                        value = value * (1 - fade) + -10 * fade
                    }
                    result[index] = value
                    index += 1
                }
            }
        }
        return result
    }

    private func terrain(x: Int, z: Int, climate: [BetaClimateSample]) -> [UInt8] {
        let values = density(x: x * 4, z: z * 4, climate: climate)
        var blocks = Array(repeating: UInt8(0), count: 32768)
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
                                var id: UInt8 = 0
                                if by < 64 {
                                    id = climate[bx * 16 + bz].temperature < 0.5 && by >= 63 ? 79 : 9
                                }
                                if value > 0 { id = 1 }
                                blocks[Chunk.index(x: bx, y: by, z: bz)] = id
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

    private func replaceSurface(in blocks: inout [UInt8], x: Int, z: Int, climate: [BetaClimateSample]) {
        let sand = beachNoise.generate(
            x: Double(x * 16), y: Double(z * 16), z: 0,
            sizeX: 16, sizeY: 16, sizeZ: 1, scaleX: 0.03125, scaleY: 0.03125, scaleZ: 1)
        let gravel = beachNoise.generate(
            x: Double(x * 16), y: 109.0134, z: Double(z * 16),
            sizeX: 16, sizeY: 1, sizeZ: 16, scaleX: 0.03125, scaleY: 1, scaleZ: 0.03125)
        let thickness = surfaceNoise.generate(
            x: Double(x * 16), y: Double(z * 16), z: 0,
            sizeX: 16, sizeY: 16, sizeZ: 1, scaleX: 0.0625, scaleY: 0.0625, scaleZ: 0.0625)
        var random = JavaRandom(seed: Int64(x) &* 341_873_128_712 &+ Int64(z) &* 132_897_987_541)
        for bz in 0..<16 {
            for bx in 0..<16 {
                let biome = climate[bz + bx * 16].biome
                let beachSand = sand[bz + bx * 16] + random.nextDouble() * 0.2 > 0
                let beachGravel = gravel[bz + bx * 16] + random.nextDouble() * 0.2 > 3
                let depth = Int(thickness[bz + bx * 16] / 3 + 3 + random.nextDouble() * 0.25)
                var remaining = -1
                var top = biome.surface.rawValue
                var filler = biome.filler.rawValue
                for by in (0..<128).reversed() {
                    let index = Chunk.index(x: bx, y: by, z: bz)
                    if by <= random.nextInt(bound: 5) {
                        blocks[index] = 7
                    } else if blocks[index] == 0 {
                        remaining = -1
                    } else if blocks[index] == 1 {
                        if remaining == -1 {
                            if depth <= 0 {
                                top = 0
                                filler = 1
                            } else if by >= 60 && by <= 65 {
                                top = biome.surface.rawValue
                                filler = biome.filler.rawValue
                                if beachGravel {
                                    top = 0
                                    filler = 13
                                }
                                if beachSand {
                                    top = 12
                                    filler = 12
                                }
                            }
                            if by < 64 && top == 0 { top = 9 }
                            remaining = depth
                            blocks[index] = by >= 63 ? top : filler
                        } else if remaining > 0 {
                            remaining -= 1
                            blocks[index] = filler
                            if remaining == 0 && filler == 12 {
                                remaining = random.nextInt(bound: 4)
                                filler = 24
                            }
                        }
                    }
                }
            }
        }
    }
}
