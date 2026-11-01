import MinecraftCore
import Testing

@Test func adjacentBlocksOmitTheirSharedFaces() {
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .stone
    #expect(BlockMesh(world: world).vertices.count == 36)
    world[BlockPosition(1, 0, 0)] = .dirt
    #expect(BlockMesh(world: world).vertices.count == 60)
    world[BlockPosition(0, 0, 0)] = nil
    #expect(BlockMesh(world: world).vertices.count == 36)
}

@Test func trianglesFaceOutward() {
    var world = BlockWorld()
    world[BlockPosition(0, 0, 0)] = .stone
    let vertices = BlockMesh(world: world).vertices
    for index in stride(from: 0, to: vertices.count, by: 3) {
        let a = vertices[index].position
        let b = vertices[index + 1].position
        let c = vertices[index + 2].position
        let u = b - a
        let v = c - a
        let normal = SIMD3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)
        let outward = (a + b + c) / 3 - SIMD3<Float>(repeating: 0.5)
        #expect(normal.x * outward.x + normal.y * outward.y + normal.z * outward.z > 0)
    }
}

@Test func movementUsesCameraHeadingAndTime() {
    var camera = Camera(position: .zero, yaw: .pi / 2, pitch: 0)
    camera.move(MovementInput(forward: 1), deltaTime: 0.5)
    #expect(abs(camera.position.x - 2.5) < 0.0001)
    #expect(abs(camera.position.z) < 0.0001)
    var stepped = Camera(position: .zero, yaw: .pi / 2, pitch: 0)
    for _ in 0..<10 { stepped.move(MovementInput(forward: 1), deltaTime: 0.05) }
    #expect(abs(stepped.position.x - camera.position.x) < 0.0001)
}

@Test func diagonalMovementDoesNotIncreaseSpeed() {
    var camera = Camera(position: .zero, yaw: 0, pitch: 0)
    camera.move(MovementInput(forward: 1, right: 1, up: 1), deltaTime: 1)
    let p = camera.position
    #expect(abs(p.x * p.x + p.y * p.y + p.z * p.z - 25) < 0.0001)
}

@Test func lookingClampsPitchAndWrapsYaw() {
    var camera = Camera(position: .zero, yaw: 0, pitch: 0)
    camera.look(horizontal: 20 * .pi, vertical: 100)
    #expect(abs(camera.yaw) < 0.0001)
    #expect(camera.pitch == Float(Double.pi / 2))
    camera.look(horizontal: 0, vertical: -200)
    #expect(camera.pitch == -Float(Double.pi / 2))
}

@Test func demoWorldIsDeterministic() {
    let first = BlockWorld.demo()
    #expect(first.blocks == BlockWorld.demo().blocks)
    #expect(first[BlockPosition(3, 1, 1)] == .wood)
    #expect(first[BlockPosition(-5, 0, -5)] == .stone)
    #expect(first[BlockPosition(0, -1, 0)] == nil)
    #expect(first[BlockPosition(100, 0, 0)] == nil)
}
