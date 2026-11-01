import Foundation

private func javaInt(_ value: Double) -> Int32 {
    if value >= Double(Int32.max) { return .max }
    if value <= Double(Int32.min) { return .min }
    return Int32(value)
}

private func noiseFloor(_ value: Double) -> Int {
    let integer = javaInt(value)
    return Int(value < Double(integer) ? integer &- 1 : integer)
}

private func fade(_ value: Double) -> Double {
    value * value * value * (value * (value * 6 - 15) + 10)
}

private func interpolate(_ amount: Double, _ first: Double, _ second: Double) -> Double {
    first + amount * (second - first)
}

struct BetaPerlinNoise: Sendable {
    private let permutations: [Int]
    private let offset: SIMD3<Double>

    init(random: inout JavaRandom) {
        offset = SIMD3(random.nextDouble() * 256, random.nextDouble() * 256, random.nextDouble() * 256)
        var table = Array(0..<256) + Array(repeating: 0, count: 256)
        for index in 0..<256 {
            let swap = random.nextInt(bound: 256 - index) + index
            table.swapAt(index, swap)
            table[index + 256] = table[index]
        }
        permutations = table
    }

    private func gradient(_ hash: Int, _ x: Double, _ y: Double, _ z: Double) -> Double {
        let hash = hash & 15
        let first = hash < 8 ? x : y
        let second: Double
        if hash < 4 { second = y } else if hash == 12 || hash == 14 { second = x } else { second = z }
        return (hash & 1 == 0 ? first : -first) + (hash & 2 == 0 ? second : -second)
    }

    private func gradient2D(_ hash: Int, _ x: Double, _ z: Double) -> Double {
        let hash = hash & 15
        let first = Double(1 - ((hash & 8) >> 3)) * x
        let second: Double
        if hash < 4 { second = 0 } else if hash == 12 || hash == 14 { second = x } else { second = z }
        return (hash & 1 == 0 ? first : -first) + (hash & 2 == 0 ? second : -second)
    }

    func sample(x: Double, y: Double, z: Double) -> Double {
        var x = x + offset.x
        var y = y + offset.y
        var z = z + offset.z
        let floorX = noiseFloor(x)
        let floorY = noiseFloor(y)
        let floorZ = noiseFloor(z)
        let cellX = floorX & 255
        let cellY = floorY & 255
        let cellZ = floorZ & 255
        x -= Double(floorX)
        y -= Double(floorY)
        z -= Double(floorZ)
        let fadeX = fade(x)
        let fadeY = fade(y)
        let fadeZ = fade(z)
        let p = permutations
        let a = p[cellX] + cellY
        let aa = p[a] + cellZ
        let ab = p[a + 1] + cellZ
        let b = p[cellX + 1] + cellY
        let ba = p[b] + cellZ
        let bb = p[b + 1] + cellZ
        return interpolate(
            fadeZ,
            interpolate(
                fadeY,
                interpolate(fadeX, gradient(p[aa], x, y, z), gradient(p[ba], x - 1, y, z)),
                interpolate(fadeX, gradient(p[ab], x, y - 1, z), gradient(p[bb], x - 1, y - 1, z))),
            interpolate(
                fadeY,
                interpolate(fadeX, gradient(p[aa + 1], x, y, z - 1), gradient(p[ba + 1], x - 1, y, z - 1)),
                interpolate(
                    fadeX, gradient(p[ab + 1], x, y - 1, z - 1), gradient(p[bb + 1], x - 1, y - 1, z - 1))))
    }

    func add(
        to values: inout [Double], x: Double, y: Double, z: Double,
        sizeX: Int, sizeY: Int, sizeZ: Int,
        scaleX: Double, scaleY: Double, scaleZ: Double, amplitude: Double
    ) {
        let p = permutations
        var index = 0
        let inverseAmplitude = 1 / amplitude
        if sizeY == 1 {
            for xi in 0..<sizeX {
                var px = (x + Double(xi)) * scaleX + offset.x
                let floorX = noiseFloor(px)
                let cellX = floorX & 255
                px -= Double(floorX)
                let fx = fade(px)
                for zi in 0..<sizeZ {
                    var pz = (z + Double(zi)) * scaleZ + offset.z
                    let floorZ = noiseFloor(pz)
                    let cellZ = floorZ & 255
                    pz -= Double(floorZ)
                    let fz = fade(pz)
                    let a = p[p[cellX]] + cellZ
                    let b = p[p[cellX + 1]] + cellZ
                    let first = interpolate(fx, gradient2D(p[a], px, pz), gradient(p[b], px - 1, 0, pz))
                    let second = interpolate(
                        fx, gradient(p[a + 1], px, 0, pz - 1), gradient(p[b + 1], px - 1, 0, pz - 1))
                    values[index] += interpolate(fz, first, second) * inverseAmplitude
                    index += 1
                }
            }
            return
        }
        var previousCellY = -1
        var lowerNear = 0.0
        var upperNear = 0.0
        var lowerFar = 0.0
        var upperFar = 0.0
        for xi in 0..<sizeX {
            var px = (x + Double(xi)) * scaleX + offset.x
            let floorX = noiseFloor(px)
            let cellX = floorX & 255
            px -= Double(floorX)
            let fx = fade(px)
            for zi in 0..<sizeZ {
                var pz = (z + Double(zi)) * scaleZ + offset.z
                let floorZ = noiseFloor(pz)
                let cellZ = floorZ & 255
                pz -= Double(floorZ)
                let fz = fade(pz)
                for yi in 0..<sizeY {
                    var py = (y + Double(yi)) * scaleY + offset.y
                    let floorY = noiseFloor(py)
                    let cellY = floorY & 255
                    py -= Double(floorY)
                    let fy = fade(py)
                    // Beta reuses these gradients throughout each integer Y cell.
                    if yi == 0 || cellY != previousCellY {
                        previousCellY = cellY
                        let a = p[cellX] + cellY
                        let aa = p[a] + cellZ
                        let ab = p[a + 1] + cellZ
                        let b = p[cellX + 1] + cellY
                        let ba = p[b] + cellZ
                        let bb = p[b + 1] + cellZ
                        lowerNear = interpolate(
                            fx, gradient(p[aa], px, py, pz), gradient(p[ba], px - 1, py, pz))
                        upperNear = interpolate(
                            fx, gradient(p[ab], px, py - 1, pz), gradient(p[bb], px - 1, py - 1, pz))
                        lowerFar = interpolate(
                            fx, gradient(p[aa + 1], px, py, pz - 1), gradient(p[ba + 1], px - 1, py, pz - 1))
                        upperFar = interpolate(
                            fx, gradient(p[ab + 1], px, py - 1, pz - 1),
                            gradient(p[bb + 1], px - 1, py - 1, pz - 1))
                    }
                    values[index] +=
                        interpolate(
                            fz, interpolate(fy, lowerNear, upperNear), interpolate(fy, lowerFar, upperFar))
                        * inverseAmplitude
                    index += 1
                }
            }
        }
    }
}

struct BetaOctaveNoise: Sendable {
    private let octaves: [BetaPerlinNoise]

    init(random: inout JavaRandom, count: Int) {
        octaves = (0..<count).map { _ in BetaPerlinNoise(random: &random) }
    }

    func sample(x: Double, z: Double) -> Double {
        var result = 0.0
        var frequency = 1.0
        for octave in octaves {
            result += octave.sample(x: x * frequency, y: z * frequency, z: 0) / frequency
            frequency /= 2
        }
        return result
    }

    func generate(
        x: Double, y: Double, z: Double, sizeX: Int, sizeY: Int, sizeZ: Int,
        scaleX: Double, scaleY: Double, scaleZ: Double
    ) -> [Double] {
        var values = Array(repeating: 0.0, count: sizeX * sizeY * sizeZ)
        var frequency = 1.0
        for octave in octaves {
            octave.add(
                to: &values, x: x, y: y, z: z, sizeX: sizeX, sizeY: sizeY, sizeZ: sizeZ,
                scaleX: scaleX * frequency, scaleY: scaleY * frequency, scaleZ: scaleZ * frequency,
                amplitude: frequency)
            frequency /= 2
        }
        return values
    }
}

struct BetaSimplexNoise: Sendable {
    private let permutations: [Int]
    private let offset: SIMD2<Double>
    private static let gradients: [SIMD2<Double>] = [
        SIMD2(1, 1), SIMD2(-1, 1), SIMD2(1, -1), SIMD2(-1, -1),
        SIMD2(1, 0), SIMD2(-1, 0), SIMD2(1, 0), SIMD2(-1, 0),
        SIMD2(0, 1), SIMD2(0, -1), SIMD2(0, 1), SIMD2(0, -1),
    ]

    init(random: inout JavaRandom) {
        offset = SIMD2(random.nextDouble() * 256, random.nextDouble() * 256)
        _ = random.nextDouble()
        var table = Array(0..<256) + Array(repeating: 0, count: 256)
        for index in 0..<256 {
            table.swapAt(index, random.nextInt(bound: 256 - index) + index)
            table[index + 256] = table[index]
        }
        permutations = table
    }

    func add(
        to values: inout [Double], x: Double, z: Double, sizeX: Int, sizeZ: Int,
        scaleX: Double, scaleZ: Double, amplitude: Double
    ) {
        let skew = 0.5 * (sqrt(3) - 1)
        let unskew = (3 - sqrt(3)) / 6
        let p = permutations
        func fastFloor(_ value: Double) -> Int {
            Int(value > 0 ? javaInt(value) : javaInt(value) &- 1)
        }
        func contribution(_ hash: Int, _ px: Double, _ pz: Double) -> Double {
            var attenuation = 0.5 - px * px - pz * pz
            if attenuation < 0 { return 0 }
            attenuation *= attenuation
            let gradient = Self.gradients[hash % 12]
            return attenuation * attenuation * (gradient.x * px + gradient.y * pz)
        }
        var index = 0
        for xi in 0..<sizeX {
            let px = (x + Double(xi)) * scaleX + offset.x
            for zi in 0..<sizeZ {
                let pz = (z + Double(zi)) * scaleZ + offset.y
                let displacement = (px + pz) * skew
                let gridX = fastFloor(px + displacement)
                let gridZ = fastFloor(pz + displacement)
                let inverse = Double(gridX + gridZ) * unskew
                let x0 = px - (Double(gridX) - inverse)
                let z0 = pz - (Double(gridZ) - inverse)
                let stepX = x0 > z0 ? 1 : 0
                let stepZ = x0 > z0 ? 0 : 1
                let x1 = x0 - Double(stepX) + unskew
                let z1 = z0 - Double(stepZ) + unskew
                let x2 = x0 - 1 + 2 * unskew
                let z2 = z0 - 1 + 2 * unskew
                let hashX = gridX & 255
                let hashZ = gridZ & 255
                let first = contribution(p[hashX + p[hashZ]], x0, z0)
                let second = contribution(p[hashX + stepX + p[hashZ + stepZ]], x1, z1)
                let third = contribution(p[hashX + 1 + p[hashZ + 1]], x2, z2)
                values[index] += 70 * (first + second + third) * amplitude
                index += 1
            }
        }
    }
}

struct BetaClimateNoise: Sendable {
    private let octaves: [BetaSimplexNoise]

    init(random: inout JavaRandom, count: Int) {
        octaves = (0..<count).map { _ in BetaSimplexNoise(random: &random) }
    }

    func generate(
        x: Double, z: Double, sizeX: Int, sizeZ: Int, scaleX: Double, scaleZ: Double,
        frequencyMultiplier: Double, amplitudeMultiplier: Double = 0.5
    ) -> [Double] {
        var values = Array(repeating: 0.0, count: sizeX * sizeZ)
        var frequency = 1.0
        var amplitude = 1.0
        for octave in octaves {
            octave.add(
                to: &values, x: x, z: z, sizeX: sizeX, sizeZ: sizeZ,
                scaleX: scaleX / 1.5 * frequency, scaleZ: scaleZ / 1.5 * frequency,
                amplitude: 0.55 / amplitude)
            frequency *= frequencyMultiplier
            amplitude *= amplitudeMultiplier
        }
        return values
    }
}
