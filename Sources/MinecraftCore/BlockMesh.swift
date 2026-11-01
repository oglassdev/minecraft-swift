public struct BlockVertex: Sendable {
    public let position: SIMD3<Float>
    public let color: SIMD3<Float>
}

/// Emits outward-facing triangles only where a solid block borders air.
public struct BlockMesh: Sendable {
    public let vertices: [BlockVertex]

    public init(world: BlockWorld) {
        var vertices: [BlockVertex] = []
        let positions = world.blocks.keys.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        for position in positions {
            guard let block = world[position] else { continue }
            for face in Self.faces {
                let neighbor = BlockPosition(
                    position.x + face.direction.x,
                    position.y + face.direction.y,
                    position.z + face.direction.z
                )
                guard world[neighbor] == nil else { continue }
                var color = block.color
                if block == .grass && face.direction.y < 1 { color = BlockKind.dirt.color }
                for index in [0, 1, 2, 0, 2, 3] {
                    vertices.append(
                        BlockVertex(
                            position: position.vector + face.corners[index],
                            color: color * face.brightness
                        ))
                }
            }
        }
        self.vertices = vertices
    }

    private struct Face: Sendable {
        let direction: BlockPosition
        let corners: [SIMD3<Float>]
        let brightness: Float
    }

    private static let faces: [Face] = [
        Face(
            direction: BlockPosition(0, 0, 1),
            corners: [
                SIMD3(0, 0, 1), SIMD3(1, 0, 1), SIMD3(1, 1, 1), SIMD3(0, 1, 1),
            ], brightness: 0.80),
        Face(
            direction: BlockPosition(0, 0, -1),
            corners: [
                SIMD3(1, 0, 0), SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0),
            ], brightness: 0.80),
        Face(
            direction: BlockPosition(1, 0, 0),
            corners: [
                SIMD3(1, 0, 1), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(1, 1, 1),
            ], brightness: 0.65),
        Face(
            direction: BlockPosition(-1, 0, 0),
            corners: [
                SIMD3(0, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 1, 1), SIMD3(0, 1, 0),
            ], brightness: 0.65),
        Face(
            direction: BlockPosition(0, 1, 0),
            corners: [
                SIMD3(0, 1, 1), SIMD3(1, 1, 1), SIMD3(1, 1, 0), SIMD3(0, 1, 0),
            ], brightness: 1),
        Face(
            direction: BlockPosition(0, -1, 0),
            corners: [
                SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 1), SIMD3(0, 0, 1),
            ], brightness: 0.5),
    ]
}
