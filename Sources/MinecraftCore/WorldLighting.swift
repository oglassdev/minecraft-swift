public enum WorldLighting {
    /// Rebuilds the settled Beta light fields within the currently loaded chunks.
    public static func rebuild(world: inout BlockWorld) {
        let positions = world.chunks.keys.sorted { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }
        rebuild(world: &world, positions: positions, preserveBoundary: false)
    }

    /// Relights edited chunks and their neighbors using the settled, unchanged outside fields.
    public static func rebuild(world: inout BlockWorld, changedChunks: Set<ChunkPosition>) {
        var selected = Set<ChunkPosition>()
        for changed in changedChunks {
            for x in (changed.x - 1)...(changed.x + 1) {
                for z in (changed.z - 1)...(changed.z + 1) {
                    let position = ChunkPosition(x, z)
                    if world.chunks[position] != nil { selected.insert(position) }
                }
            }
        }
        let positions = selected.sorted { $0.x == $1.x ? $0.z < $1.z : $0.x < $1.x }
        rebuild(world: &world, positions: positions, preserveBoundary: true)
    }

    private static func rebuild(world: inout BlockWorld, positions: [ChunkPosition], preserveBoundary: Bool) {
        let chunks = positions.compactMap { world.chunks[$0] }
        guard !chunks.isEmpty else { return }
        let hasSky = world.dimension != -1
        let slots = Dictionary(uniqueKeysWithValues: positions.enumerated().map { ($0.element, $0.offset) })
        let neighbors = positions.map { position in
            Neighbors(
                west: slots[ChunkPosition(position.x - 1, position.z)].map { $0 * Chunk.volume } ?? -1,
                east: slots[ChunkPosition(position.x + 1, position.z)].map { $0 * Chunk.volume } ?? -1,
                north: slots[ChunkPosition(position.x, position.z - 1)].map { $0 * Chunk.volume } ?? -1,
                south: slots[ChunkPosition(position.x, position.z + 1)].map { $0 * Chunk.volume } ?? -1
            )
        }
        let count = chunks.count * Chunk.volume
        var sky = [UInt8](repeating: 0, count: count)
        var block = [UInt8](repeating: 0, count: count)
        var opacity = [UInt8](repeating: 0, count: count)
        var skyQueue: [Int] = []
        var blockQueue: [Int] = []
        var highestOccluder = 0
        let opacityByID = (0...255).map { BlockKind(rawValue: UInt8($0))?.lightOpacity ?? 0 }
        let emissionByID = (0...255).map { BlockKind(rawValue: UInt8($0))?.lightEmission ?? 0 }

        for (slot, chunk) in chunks.enumerated() {
            let base = slot * Chunk.volume
            for x in 0..<16 {
                for z in 0..<16 {
                    var sunlight = hasSky ? 15 : 0
                    let column = x << 11 | z << 7
                    for y in (0..<128).reversed() {
                        let local = column + y
                        let index = base + local
                        let id = Int(chunk.blockIDs[local])
                        let attenuation = Int(opacityByID[id])
                        opacity[index] = UInt8(attenuation)
                        if hasSky {
                            if attenuation > 0 { highestOccluder = max(highestOccluder, y) }
                            if sunlight < 15 || attenuation > 0 {
                                sunlight = max(0, sunlight - max(1, attenuation))
                            }
                            sky[index] = UInt8(sunlight)
                        }
                        block[index] = emissionByID[id]
                        if block[index] > 1 { blockQueue.append(index) }
                    }
                }
            }
        }

        if preserveBoundary {
            for (slot, position) in positions.enumerated() {
                let base = slot * Chunk.volume
                let adjacent = neighbors[slot]
                let faces: [(Int, ChunkPosition, Int, Int, Int)] = [
                    (adjacent.west, ChunkPosition(position.x - 1, position.z), 0, 15 << 11, 128),
                    (adjacent.east, ChunkPosition(position.x + 1, position.z), 15 << 11, 0, 128),
                    (adjacent.north, ChunkPosition(position.x, position.z - 1), 0, 15 << 7, 2048),
                    (adjacent.south, ChunkPosition(position.x, position.z + 1), 15 << 7, 0, 2048),
                ]
                for (neighbor, outsidePosition, insideStart, outsideStart, stride) in faces {
                    guard neighbor < 0, let outside = world.chunks[outsidePosition] else { continue }
                    for column in 0..<16 {
                        for y in 0..<128 {
                            let index = base + insideStart + column * stride + y
                            let outsideIndex = outsideStart + column * stride + y
                            let attenuation = max(1, Int(opacity[index]))
                            let incomingBlock = Int(outside.blockLight[outsideIndex]) - attenuation
                            if incomingBlock > Int(block[index]) {
                                block[index] = UInt8(incomingBlock)
                                if incomingBlock > 1 { blockQueue.append(index) }
                            }
                            let incomingSky = hasSky ? Int(outside.skyLight[outsideIndex]) - attenuation : 0
                            if incomingSky > Int(sky[index]) {
                                sky[index] = UInt8(incomingSky)
                                if incomingSky > 1 { skyQueue.append(index) }
                            }
                        }
                    }
                }
            }
        }

        // Direct columns are already maximal vertically; only shadow boundaries need flooding.
        for slot in chunks.indices {
            let base = slot * Chunk.volume
            for x in 0..<16 {
                for z in 0..<16 {
                    let column = base + (x << 11 | z << 7)
                    for y in 0...highestOccluder {
                        let index = column + y
                        let level = Int(sky[index])
                        guard level > 1 else { continue }
                        var spreads = false
                        forEachNeighbor(of: index, chunks: neighbors) { neighbor in
                            if !spreads && level - max(1, Int(opacity[neighbor])) > Int(sky[neighbor]) {
                                spreads = true
                            }
                        }
                        if spreads { skyQueue.append(index) }
                    }
                }
            }
        }
        propagate(queue: &skyQueue, light: &sky, opacity: opacity, chunks: neighbors)
        propagate(queue: &blockQueue, light: &block, opacity: opacity, chunks: neighbors)
        for slot in chunks.indices {
            var chunk = chunks[slot]
            let range = slot * Chunk.volume..<(slot + 1) * Chunk.volume
            chunk.skyLight = Array(sky[range])
            chunk.blockLight = Array(block[range])
            world.applyLighting(from: chunk)
        }
    }

    private struct Neighbors {
        let west: Int
        let east: Int
        let north: Int
        let south: Int
    }

    private static func propagate(
        queue: inout [Int], light: inout [UInt8], opacity: [UInt8], chunks: [Neighbors]
    ) {
        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let level = Int(light[index])
            guard level > 1 else { continue }
            forEachNeighbor(of: index, chunks: chunks) { neighbor in
                let propagated = level - max(1, Int(opacity[neighbor]))
                if propagated > Int(light[neighbor]) {
                    light[neighbor] = UInt8(propagated)
                    if propagated > 1 { queue.append(neighbor) }
                }
            }
        }
    }

    @inline(__always)
    private static func forEachNeighbor(of index: Int, chunks: [Neighbors], _ body: (Int) -> Void) {
        let local = index & (Chunk.volume - 1)
        let adjacent = chunks[index >> 15]
        let x = local >> 11
        let z = local >> 7 & 15
        let y = local & 127
        if y > 0 { body(index - 1) }
        if y < 127 { body(index + 1) }
        if x > 0 { body(index - 2048) } else if adjacent.west >= 0 { body(adjacent.west + local + 15 * 2048) }
        if x < 15 {
            body(index + 2048)
        } else if adjacent.east >= 0 {
            body(adjacent.east + local - 15 * 2048)
        }
        if z > 0 { body(index - 128) } else if adjacent.north >= 0 { body(adjacent.north + local + 15 * 128) }
        if z < 15 {
            body(index + 128)
        } else if adjacent.south >= 0 {
            body(adjacent.south + local - 15 * 128)
        }
    }
}
