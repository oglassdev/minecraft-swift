import Foundation

private enum CaveMath {
    static let sineTable: [Float] = (0..<65536).map { Float(sin(Double($0) * .pi * 2 / 65536)) }
    static func sine(_ angle: Float) -> Float { sineTable[Int(angle * 10430.378) & 65535] }
    static func cosine(_ angle: Float) -> Float { sineTable[Int(angle * 10430.378 + 16384) & 65535] }
}

struct BetaCaveGenerator: Sendable {
    let seed: Int64
    private let nether: Bool

    init(seed: Int64, nether: Bool = false) {
        self.seed = seed
        self.nether = nether
    }

    func carve(chunkX: Int, chunkZ: Int, blocks: inout [UInt8]) {
        var random = JavaRandom(seed: seed)
        let xSeed = random.nextLong() / 2 * 2 + 1
        let zSeed = random.nextLong() / 2 * 2 + 1
        for sourceX in (chunkX - 8)...(chunkX + 8) {
            for sourceZ in (chunkZ - 8)...(chunkZ + 8) {
                random.setSeed((Int64(sourceX) &* xSeed &+ Int64(sourceZ) &* zSeed) ^ seed)
                let firstCount = random.nextInt(bound: nether ? 10 : 40) + 1
                let secondCount = random.nextInt(bound: firstCount) + 1
                var count = random.nextInt(bound: secondCount)
                if random.nextInt(bound: nether ? 5 : 15) != 0 { count = 0 }
                for _ in 0..<count {
                    let x = Double(sourceX * 16 + random.nextInt(bound: 16))
                    let y: Double
                    if nether {
                        y = Double(random.nextInt(bound: 128))
                    } else {
                        let yBound = random.nextInt(bound: 120) + 8
                        y = Double(random.nextInt(bound: yBound))
                    }
                    let z = Double(sourceZ * 16 + random.nextInt(bound: 16))
                    var tunnels = 1
                    if random.nextInt(bound: 4) == 0 {
                        let roomWidth = 1 + random.nextFloat() * 6
                        tunnel(
                            chunkX: chunkX, chunkZ: chunkZ, blocks: &blocks, x: x, y: y, z: z,
                            width: roomWidth, yaw: 0, pitch: 0, step: -1, length: -1, verticalScale: 0.5,
                            baseRandom: &random)
                        tunnels += random.nextInt(bound: 4)
                    }
                    for _ in 0..<tunnels {
                        let yaw = random.nextFloat() * Float(Double.pi) * 2
                        let pitch = (random.nextFloat() - 0.5) * 2 / 8
                        let width = random.nextFloat() * 2 + random.nextFloat()
                        tunnel(
                            chunkX: chunkX, chunkZ: chunkZ, blocks: &blocks, x: x, y: y, z: z,
                            width: nether ? width * 2 : width, yaw: yaw, pitch: pitch, step: 0, length: 0,
                            verticalScale: nether ? 0.5 : 1,
                            baseRandom: &random)
                    }
                }
            }
        }
    }

    private func tunnel(
        chunkX: Int, chunkZ: Int, blocks: inout [UInt8], x: Double, y: Double, z: Double,
        width: Float, yaw: Float, pitch: Float, step: Int, length: Int, verticalScale: Double,
        baseRandom: inout JavaRandom
    ) {
        var x = x
        var y = y
        var z = z
        var yaw = yaw
        var pitch = pitch
        var step = step
        var length = length
        let centerX = Double(chunkX * 16 + 8)
        let centerZ = Double(chunkZ * 16 + 8)
        var yawVelocity: Float = 0
        var pitchVelocity: Float = 0
        var random = JavaRandom(seed: baseRandom.nextLong())
        if length <= 0 { length = 112 - random.nextInt(bound: 28) }
        let isRoom = step == -1
        if isRoom { step = length / 2 }
        let branch = random.nextInt(bound: length / 2) + length / 4
        let gentlePitch = random.nextInt(bound: 6) == 0
        while step < length {
            let radius = 1.5 + Double(CaveMath.sine(Float(step) * Float(Double.pi) / Float(length)) * width)
            let verticalRadius = radius * verticalScale
            let horizontalDirection = CaveMath.cosine(pitch)
            x += Double(CaveMath.cosine(yaw) * horizontalDirection)
            y += Double(CaveMath.sine(pitch))
            z += Double(CaveMath.sine(yaw) * horizontalDirection)
            pitch *= gentlePitch ? 0.92 : 0.7
            pitch += pitchVelocity * 0.1
            yaw += yawVelocity * 0.1
            pitchVelocity *= 0.9
            yawVelocity *= 0.75
            pitchVelocity += (random.nextFloat() - random.nextFloat()) * random.nextFloat() * 2
            yawVelocity += (random.nextFloat() - random.nextFloat()) * random.nextFloat() * 4
            if !isRoom && step == branch && width > 1 {
                let firstWidth = random.nextFloat() * 0.5 + 0.5
                tunnel(
                    chunkX: chunkX, chunkZ: chunkZ, blocks: &blocks, x: x, y: y, z: z,
                    width: firstWidth, yaw: yaw - Float(Double.pi / 2), pitch: pitch / 3,
                    step: step, length: length, verticalScale: 1, baseRandom: &baseRandom)
                let secondWidth = random.nextFloat() * 0.5 + 0.5
                tunnel(
                    chunkX: chunkX, chunkZ: chunkZ, blocks: &blocks, x: x, y: y, z: z,
                    width: secondWidth, yaw: yaw + Float(Double.pi / 2), pitch: pitch / 3,
                    step: step, length: length, verticalScale: 1, baseRandom: &baseRandom)
                return
            }
            if isRoom || random.nextInt(bound: 4) != 0 {
                let dx = x - centerX
                let dz = z - centerZ
                let remaining = Double(length - step)
                let padding = Double(width + 2 + 16)
                if dx * dx + dz * dz - remaining * remaining > padding * padding { return }
                if x >= centerX - 16 - radius * 2 && z >= centerZ - 16 - radius * 2
                    && x <= centerX + 16 + radius * 2 && z <= centerZ + 16 + radius * 2
                {
                    let minX = max(0, Int(floor(x - radius)) - chunkX * 16 - 1)
                    let maxX = min(16, Int(floor(x + radius)) - chunkX * 16 + 1)
                    let minY = max(1, Int(floor(y - verticalRadius)) - 1)
                    let maxY = min(120, Int(floor(y + verticalRadius)) + 1)
                    let minZ = max(0, Int(floor(z - radius)) - chunkZ * 16 - 1)
                    let maxZ = min(16, Int(floor(z + radius)) - chunkZ * 16 + 1)
                    if minX < maxX && minY < maxY && minZ < maxZ {
                        var water = false
                        for bx in minX..<maxX where !water {
                            for bz in minZ..<maxZ where !water {
                                var by = maxY + 1
                                while !water && by >= minY - 1 {
                                    if by >= 0 && by < 128 {
                                        let id = blocks[Chunk.index(x: bx, y: by, z: bz)]
                                        if nether ? (id == 10 || id == 11) : (id == 8 || id == 9) {
                                            water = true
                                        }
                                        if by != minY - 1 && bx != minX && bx != maxX - 1 && bz != minZ
                                            && bz != maxZ - 1
                                        {
                                            by = minY
                                        }
                                    }
                                    by -= 1
                                }
                            }
                        }
                        if !water {
                            for bx in minX..<maxX {
                                let nx = (Double(bx + chunkX * 16) + 0.5 - x) / radius
                                for bz in minZ..<maxZ {
                                    let nz = (Double(bz + chunkZ * 16) + 0.5 - z) / radius
                                    var index = Chunk.index(x: bx, y: maxY, z: bz)
                                    var removedGrass = false
                                    if nx * nx + nz * nz < 1 {
                                        for by in (minY..<maxY).reversed() {
                                            let ny = (Double(by) + 0.5 - y) / verticalRadius
                                            if ny > -0.7 && nx * nx + ny * ny + nz * nz < 1 {
                                                let id = blocks[index]
                                                if !nether && id == 2 { removedGrass = true }
                                                if id == (nether ? 87 : 1) || id == 3 || id == 2 {
                                                    if !nether && by < 10 {
                                                        blocks[index] = 10
                                                    } else {
                                                        blocks[index] = 0
                                                        if removedGrass && blocks[index - 1] == 3 {
                                                            blocks[index - 1] = 2
                                                        }
                                                    }
                                                }
                                            }
                                            index -= 1
                                        }
                                    }
                                }
                            }
                            if isRoom { break }
                        }
                    } else if isRoom {
                        break
                    }
                }
            }
            step += 1
        }
    }
}
