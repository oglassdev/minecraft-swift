import Foundation

public struct WorldTickState: Sendable {
    public var random: JavaRandom
    public var updateLCG: Int32
    public var caveSoundCooldown: Int
    public private(set) var activeChunks: [ChunkPosition] = []
    private var chunkSet = BetaChunkSet()

    public init(randomSeed: Int64, coordinateSeed: Int64) {
        var random = JavaRandom(seed: randomSeed)
        var coordinateRandom = JavaRandom(seed: coordinateSeed)
        let updateLCG = coordinateRandom.nextInt()
        let cooldown = random.nextInt(bound: 12000)
        self.init(random: random, updateLCG: updateLCG, caveSoundCooldown: cooldown)
    }

    public init(random: JavaRandom, updateLCG: Int32, caveSoundCooldown: Int) {
        self.random = random
        self.updateLCG = updateLCG
        self.caveSoundCooldown = caveSoundCooldown
    }

    public mutating func prepareActiveChunks(players: [SIMD3<Double>]) {
        chunkSet.removeAll()
        for player in players {
            let center = ChunkPosition(Int(floor(player.x / 16)), Int(floor(player.z / 16)))
            for x in -9...9 { for z in -9...9 { chunkSet.insert(ChunkPosition(center.x + x, center.z + z)) } }
        }
        activeChunks = chunkSet.elements
        if caveSoundCooldown > 0 { caveSoundCooldown -= 1 }
    }

    public mutating func nextPosition(in chunk: ChunkPosition) -> BlockPosition {
        updateLCG = updateLCG &* 3 &+ 1_013_904_223
        let bits = updateLCG >> 2
        return BlockPosition(
            chunk.x * 16 + Int(bits & 15), Int(bits >> 16 & 127), chunk.z * 16 + Int(bits >> 8 & 15))
    }
}
