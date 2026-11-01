import Foundation
import MinecraftCore
import Testing

private struct TextureAtlasReference: Decodable {
    struct Block: Decodable {
        let id: UInt8
        let faces: [[Int?]]
    }
    let version: String
    let clientSHA1: String
    let blocks: [Block]
}

@Test func meshTextureMetadataMatchesBeta() {
    #expect(BlockAtlas.textureIndex(for: BlockState(.grass), face: .top) == 0)
    #expect(BlockAtlas.textureIndex(for: BlockState(.grass), face: .bottom) == 2)
    #expect(BlockAtlas.textureIndex(for: BlockState(.wood, metadata: 1), face: .east) == 116)
    #expect(BlockAtlas.textureIndex(for: BlockState(.wood, metadata: 2), face: .east) == 117)
    #expect(BlockAtlas.textureIndex(for: BlockState(.wood, metadata: 2), face: .top) == 21)
    #expect(BlockAtlas.textureIndex(for: BlockState(.slab, metadata: 1), face: .top) == 176)
    #expect(BlockAtlas.textureIndex(for: BlockState(.furnace, metadata: 4), face: .west) == 44)
    #expect(BlockAtlas.textureIndex(for: BlockState(.burningFurnace, metadata: 4), face: .west) == 61)
    #expect(BlockAtlas.textureIndex(for: BlockState(.wool, metadata: 14), face: .top) == 129)
    #expect(BlockAtlas.textureIndex(for: BlockState(.poweredRail), face: .top) == 163)
    #expect(BlockAtlas.textureIndex(for: BlockState(.poweredRail, metadata: 8), face: .top) == 179)
    #expect(BlockAtlas.textureIndex(for: BlockState(.bed), face: .north) == 149)
    #expect(BlockAtlas.textureIndex(for: BlockState(.stickyPiston, metadata: 8), face: .bottom) == 110)
    #expect(BlockAtlas.textureIndex(for: BlockState(.woodenDoor, metadata: 8), face: .top) == 97)
    #expect(BlockAtlas.textureIndex(for: BlockState(.redstoneTorch), face: .top) == 164)
}

@Test func meshAtlasMatchesOriginalClient() throws {
    let url = try #require(Bundle.module.url(forResource: "BlockAtlas", withExtension: "json"))
    let reference = try JSONDecoder().decode(TextureAtlasReference.self, from: Data(contentsOf: url))
    #expect(reference.version == "b1.7.3")
    #expect(reference.clientSHA1 == "43db9b498cb67058d2e12d394e6507722e71bb45")
    for block in reference.blocks {
        let kind = try #require(BlockKind(rawValue: block.id))
        for face in BlockFace.allCases {
            for (metadata, expected) in block.faces[face.rawValue].enumerated() {
                guard let expected else { continue }
                let state = BlockState(kind, metadata: UInt8(metadata))
                #expect(BlockAtlas.textureIndex(for: state, face: face) == abs(expected))
            }
        }
    }
}

@Test func meshInventoryAtlasMatchesOriginalClient() throws {
    let url = try #require(Bundle.module.url(forResource: "InventoryBlockAtlas", withExtension: "json"))
    let reference = try JSONDecoder().decode(TextureAtlasReference.self, from: Data(contentsOf: url))
    for block in reference.blocks {
        let kind = try #require(BlockKind(rawValue: block.id))
        for face in BlockFace.allCases {
            for (metadata, expected) in block.faces[face.rawValue].enumerated() {
                guard let expected else { continue }
                #expect(
                    BlockAtlas.inventoryTextureIndex(
                        for: BlockState(kind, metadata: UInt8(metadata)), face: face) == abs(expected))
            }
        }
    }
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .fence
    #expect(
        BlockMesh(world: world, blockAt: BlockPosition(0, 0, 0), options: BlockMeshOptions(inventory: true))
            .vertices.count == 144)
}

@Test func meshCullsFacesAcrossChunkBoundaries() {
    var world = BlockWorld()
    world[BlockPosition(-1, 8, 0)] = .stone
    world[BlockPosition(0, 8, 0)] = .dirt
    let negative = BlockMesh(world: world, chunk: ChunkPosition(-1, 0))
    let positive = BlockMesh(world: world, chunk: ChunkPosition(0, 0))
    #expect(negative.opaqueVertices.count == 30)
    #expect(positive.opaqueVertices.count == 30)
}

private struct BedGeometryCase: Decodable {
    var metadata: UInt8
    var blockedFace: Int
    var vertices: [[Float]]
}

@Test func bedGeometryMatchesOriginalForEveryOrientationAndNeighbor() throws {
    let url = try #require(Bundle.module.url(forResource: "BedGeometry", withExtension: "json"))
    let cases = try JSONDecoder().decode([BedGeometryCase].self, from: Data(contentsOf: url))
    let position = BlockPosition(0, 64, 0)
    for reference in cases {
        var world = BlockWorld()
        world.setBlock(BlockState(.bed, metadata: reference.metadata), at: position)
        if let face = BlockFace(rawValue: reference.blockedFace) {
            let offset = face.offset
            world[BlockPosition(position.x + offset.x, position.y + offset.y, position.z + offset.z)] = .stone
        }
        let vertices = BlockMesh(world: world, blockAt: position, relativeTo: position).cutoutVertices
        #expect(vertices.count / 6 == reference.vertices.count / 4)
        for quad in 0..<(reference.vertices.count / 4) {
            let actual = vertices[(quad * 6)..<(quad * 6 + 6)]
            for expected in reference.vertices[(quad * 4)..<(quad * 4 + 4)] {
                #expect(
                    actual.contains { vertex in
                        let values = [
                            vertex.position.x, vertex.position.y, vertex.position.z,
                            vertex.uv.x, vertex.uv.y, vertex.color.x, vertex.color.y, vertex.color.z,
                        ]
                        return zip(values, expected).allSatisfy { abs($0.0 - $0.1) < 0.000001 }
                    })
            }
        }
    }
}

@Test func meshSeparatesCutoutsAndLiquids() {
    var world = BlockWorld()
    world[BlockPosition(0, 1, 0)] = .glass
    world[BlockPosition(2, 1, 0)] = .leaves
    world[BlockPosition(4, 1, 0)] = .stillWater
    let mesh = BlockMesh(world: world)
    #expect(mesh.opaqueVertices.isEmpty)
    #expect(mesh.cutoutVertices.count == 72)
    #expect(mesh.translucentFaces.count == 6)
    #expect(mesh.translucentFaces.allSatisfy { $0.vertices.count == 6 })
}

@Test func meshUsesPartialBoundsAndInsetAtlasCoordinates() {
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .slab
    let mesh = BlockMesh(world: world)
    #expect(mesh.vertices.count == 36)
    #expect(mesh.vertices.map(\.position.y).max() == 0.5)
    #expect(mesh.vertices.allSatisfy { $0.uv.x > 0 && $0.uv.x < 1 && $0.uv.y > 0 && $0.uv.y < 1 })
    #expect(MemoryLayout<BlockVertex>.stride == 48)
}

@Test func meshAppliesOriginalBiomeColorMaps() {
    let colorMaps = BlockColorMaps(
        grass: Array(repeating: 0x123456, count: 65536),
        foliage: Array(repeating: 0xabcdef, count: 65536)
    )
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .grass
    let mesh = BlockMesh(world: world, colorMaps: colorMaps)
    let topColor = SIMD3<Float>(0x12, 0x34, 0x56) / 255
    let top = mesh.opaqueVertices.filter { $0.position.y == 1 && $0.uv.x < 1 / 16 && $0.uv.y < 1 / 16 }
    #expect(top.count == 6)
    #expect(top.allSatisfy { $0.color == topColor })
    #expect(mesh.cutoutVertices.count == 24)
}

@Test func meshPacksOriginalSmoothLightingSamples() throws {
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .grass
    world[BlockPosition(-1, 1, 0)] = .stone
    world[BlockPosition(0, 1, -1)] = .stone
    WorldLighting.rebuild(world: &world)
    let vertices = BlockMesh(world: world).opaqueVertices.filter { $0.uv.x < 1 / 16 && $0.uv.y < 1 / 16 }
    let corner = try #require(vertices.first { $0.position == SIMD3(0, 1, 0) })
    #expect(corner.lightSamples == 240)
    let open = try #require(vertices.first { $0.position == SIMD3(1, 1, 1) })
    #expect(open.lightSamples == 0xf0f0_f0f0)
    #expect(MemoryLayout<BlockVertex>.offset(of: \.lightSamples) == 28)
    #expect(MemoryLayout<BlockVertex>.stride == 48)
}

@Test func meshChestTexturesFollowWallsAndDoubleChestNeighbors() {
    var world = BlockWorld()
    let origin = BlockPosition(0, 1, 0)
    let chest = BlockState(.chest)
    world[origin] = .chest
    #expect(BlockAtlas.textureIndex(for: chest, face: .south, at: origin, in: world) == 27)
    world[BlockPosition(1, 1, 0)] = .stone
    #expect(BlockAtlas.textureIndex(for: chest, face: .west, at: origin, in: world) == 27)
    world[BlockPosition(1, 1, 0)] = .chest
    #expect(BlockAtlas.textureIndex(for: chest, face: .south, at: origin, in: world) == 41)
    #expect(BlockAtlas.textureIndex(for: chest, face: .north, at: origin, in: world) == 58)
    #expect(BlockAtlas.textureIndex(for: chest, face: .west, at: origin, in: world) == 26)
    world[BlockPosition(0, 1, 1)] = .stone
    #expect(BlockAtlas.textureIndex(for: chest, face: .north, at: origin, in: world) == 42)
}

@Test func meshPreservesPartialBlockPrecisionAtFarLandsCoordinates() {
    for coordinate in [-12_550_821, 12_550_821] {
        var world = BlockWorld()
        let position = BlockPosition(coordinate, 64, coordinate)
        world[position] = .cactus
        let origin = BlockPosition(position.chunk.x * 16, 0, position.chunk.z * 16)
        let vertices = BlockMesh(world: world, chunk: position.chunk, relativeTo: origin).vertices
        let low = Float(position.x - origin.x) + 1 / 16
        let high = Float(position.x - origin.x) + 15 / 16
        #expect(vertices.map(\.position.x).min() == low)
        #expect(vertices.map(\.position.x).max() == high)
        #expect(high - low == 0.875)
    }
}

@Test func meshRendersTorchCapsButtonsAndExtendedPistonShapes() {
    var world = BlockWorld()
    world.setBlock(BlockState(.torch, metadata: 1), at: BlockPosition(0, 0, 0))
    let torch = BlockMesh(world: world).cutoutVertices
    #expect(torch.count == 30)
    #expect(torch.prefix(6).allSatisfy { abs($0.position.y - 0.825) < 0.00001 })
    world.setBlock(BlockState(.stoneButton, metadata: 9), at: BlockPosition(0, 0, 0))
    #expect(BlockMesh(world: world).vertices.map(\.position.x).max() == Float(1) / 16)
    world.setBlock(BlockState(.piston, metadata: 9), at: BlockPosition(0, 0, 0))
    #expect(BlockMesh(world: world).vertices.map(\.position.y).max() == 0.75)
    world.setBlock(BlockState(.pistonHead, metadata: 1), at: BlockPosition(0, 0, 0))
    #expect(BlockMesh(world: world).vertices.count == 72)
}

@Test func meshHonorsSmoothLightingAndFastLeaves() throws {
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .grass
    world[BlockPosition(-1, 1, 0)] = .stone
    world[BlockPosition(0, 1, -1)] = .stone
    WorldLighting.rebuild(world: &world)
    let flat = BlockMesh(world: world, options: BlockMeshOptions(smoothLighting: false))
    let corner = try #require(
        flat.opaqueVertices.first {
            $0.position == SIMD3(0, 1, 0) && $0.uv.x < 1 / 16 && $0.uv.y < 1 / 16
        })
    #expect(corner.lightSamples == 0xf0f0_f0f0)
    var foliage = BlockWorld()
    foliage[BlockPosition(0, 0, 0)] = .leaves
    foliage[BlockPosition(1, 0, 0)] = .leaves
    let fancy = BlockMesh(world: foliage)
    let fast = BlockMesh(world: foliage, options: BlockMeshOptions(fancyLeaves: false))
    #expect(fancy.cutoutVertices.count == 72)
    #expect(fast.opaqueVertices.count == 60 && fast.cutoutVertices.isEmpty)
    #expect(
        fast.opaqueVertices.allSatisfy {
            Int($0.uv.x * 16) == 5 && Int($0.uv.y * 16) == 3
        })
}

@Test func grassOverlaySharesExactBaseSurfaceAndLighting() {
    var world = BlockWorld()
    world[BlockPosition(15, 64, -16)] = .grass
    let mesh = BlockMesh(world: world, options: BlockMeshOptions(smoothLighting: true))
    #expect(mesh.cutoutVertices.count == 24)
    for overlay in mesh.cutoutVertices {
        #expect(
            mesh.opaqueVertices.contains {
                $0.position == overlay.position && $0.lightSamples == overlay.lightSamples
            })
    }
}
