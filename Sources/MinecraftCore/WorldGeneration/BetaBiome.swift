public enum BetaBiome: String, Sendable, Codable {
    case rainforest, swampland, seasonalForest, forest, savanna, shrubland, taiga, desert, plains, tundra

    public var surface: BlockKind { self == .desert ? .sand : .grass }
    public var filler: BlockKind { self == .desert ? .sand : .dirt }
    public var hasSnow: Bool { self == .taiga || self == .tundra }

    static func lookup(temperature: Double, humidity: Double) -> Self {
        // The original lookup table quantizes each axis to 64 float entries.
        let temperature = Float(Int(temperature * 63)) / 63
        let wetness = Float(Int(humidity * 63)) / 63 * temperature
        if temperature < 0.1 { return .tundra }
        if wetness < 0.2 {
            if temperature < 0.5 { return .tundra }
            return temperature < 0.95 ? .savanna : .desert
        }
        if wetness > 0.5 && temperature < 0.7 { return .swampland }
        if temperature < 0.5 { return .taiga }
        if temperature < 0.97 { return wetness < 0.35 ? .shrubland : .forest }
        if wetness < 0.45 { return .plains }
        return wetness < 0.9 ? .seasonalForest : .rainforest
    }
}

public struct BetaClimateSample: Sendable {
    public let temperature: Double
    public let humidity: Double
    public let biome: BetaBiome
}

public struct BetaClimateSource: Sendable {
    private let temperatureNoise: BetaClimateNoise
    private let humidityNoise: BetaClimateNoise
    private let variationNoise: BetaClimateNoise

    public init(seed: Int64) {
        var temperatureRandom = JavaRandom(seed: seed &* 9871)
        var humidityRandom = JavaRandom(seed: seed &* 39811)
        var variationRandom = JavaRandom(seed: seed &* 543321)
        temperatureNoise = BetaClimateNoise(random: &temperatureRandom, count: 4)
        humidityNoise = BetaClimateNoise(random: &humidityRandom, count: 4)
        variationNoise = BetaClimateNoise(random: &variationRandom, count: 2)
    }

    public func sample(x: Int, z: Int) -> BetaClimateSample { region(x: x, z: z, size: 1)[0] }

    public func region(x: Int, z: Int, size: Int = 16) -> [BetaClimateSample] {
        let temperatures = temperatureNoise.generate(
            x: Double(x), z: Double(z), sizeX: size, sizeZ: size,
            scaleX: Double(Float(0.025)), scaleZ: Double(Float(0.025)), frequencyMultiplier: 0.25)
        let humidities = humidityNoise.generate(
            x: Double(x), z: Double(z), sizeX: size, sizeZ: size,
            scaleX: Double(Float(0.05)), scaleZ: Double(Float(0.05)), frequencyMultiplier: 1 / 3)
        let variation = variationNoise.generate(
            x: Double(x), z: Double(z), sizeX: size, sizeZ: size,
            scaleX: 0.25, scaleZ: 0.25, frequencyMultiplier: 0.5882352941176471)
        return temperatures.indices.map { index in
            let adjustment = variation[index] * 1.1 + 0.5
            var temperature = (temperatures[index] * 0.15 + 0.7) * 0.99 + adjustment * 0.01
            temperature = 1 - (1 - temperature) * (1 - temperature)
            temperature = min(1, max(0, temperature))
            let humidity = min(1, max(0, (humidities[index] * 0.15 + 0.5) * 0.998 + adjustment * 0.002))
            return BetaClimateSample(
                temperature: temperature, humidity: humidity,
                biome: .lookup(temperature: temperature, humidity: humidity))
        }
    }
}
