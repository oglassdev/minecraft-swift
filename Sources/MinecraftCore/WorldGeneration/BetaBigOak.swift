import Foundation

struct BetaBigOak {
    private var random: JavaRandom
    private let origin: BlockPosition
    private var height: Int
    private var trunkHeight = 0
    private var nodes: [[Int]] = []
    private let leafHeight = 5
    private static let otherAxes = [2, 0, 0, 1, 2, 1]

    init(seed: Int64, origin: BlockPosition) {
        random = JavaRandom(seed: seed)
        self.origin = origin
        height = 5 + random.nextInt(bound: 12)
    }

    mutating func generate(world: inout BlockWorld) -> Bool {
        let ground = world[BlockPosition(origin.x, origin.y - 1, origin.z)]
        guard ground == .grass || ground == .dirt else { return false }
        let blocked = obstruction(
            from: [origin.x, origin.y, origin.z],
            to: [origin.x, origin.y + height - 1, origin.z], world: world)
        if blocked != -1 {
            if blocked < 6 { return false }
            height = blocked
        }
        trunkHeight = min(Int(Double(height) * 0.618), height - 1)
        createNodes(world: world)
        for node in nodes {
            for offset in 0..<leafHeight {
                leafLayer(
                    center: [node[0], node[1] + offset, node[2]],
                    radius: offset == 0 || offset == leafHeight - 1 ? 2 : 3, world: &world)
            }
        }
        line(
            from: [origin.x, origin.y, origin.z],
            to: [origin.x, origin.y + trunkHeight, origin.z], world: &world)
        for node in nodes where Double(node[3] - origin.y) >= Double(height) * 0.2 {
            line(from: [origin.x, node[3], origin.z], to: [node[0], node[1], node[2]], world: &world)
        }
        return true
    }

    private mutating func createNodes(world: BlockWorld) {
        let attempts = max(1, Int(1.382 + pow(Double(height) / 13, 2)))
        var y = origin.y + height - leafHeight
        let trunkTop = origin.y + trunkHeight
        var relative = y - origin.y
        nodes = [[origin.x, y, origin.z, trunkTop]]
        y -= 1
        while relative >= 0 {
            let radius = branchRadius(at: relative)
            if radius >= 0 {
                for _ in 0..<attempts {
                    let distance = Double(radius) * (Double(random.nextFloat()) + 0.328)
                    let angle = Double(random.nextFloat()) * 2 * 3.14159
                    let x = Int(floor(distance * sin(angle) + Double(origin.x) + 0.5))
                    let z = Int(floor(distance * cos(angle) + Double(origin.z) + 0.5))
                    let start = [x, y, z]
                    let end = [x, y + leafHeight, z]
                    if obstruction(from: start, to: end, world: world) == -1 {
                        let horizontal = sqrt(
                            pow(Double(abs(origin.x - x)), 2) + pow(Double(abs(origin.z - z)), 2))
                        let baseY = Double(y) - horizontal * 0.381
                        let attachment = baseY > Double(trunkTop) ? trunkTop : Int(baseY)
                        if obstruction(from: [origin.x, attachment, origin.z], to: start, world: world) == -1
                        {
                            nodes.append([x, y, z, attachment])
                        }
                    }
                }
            }
            y -= 1
            relative -= 1
        }
    }

    private func branchRadius(at level: Int) -> Float {
        if Double(level) < Double(height) * 0.3 { return -1.618 }
        let half = Float(height) / 2
        let displacement = half - Float(level)
        if displacement == 0 { return half * 0.5 }
        if abs(displacement) >= half { return 0 }
        return Float(sqrt(pow(Double(abs(half)), 2) - pow(Double(abs(displacement)), 2))) * 0.5
    }

    private func leafLayer(center: [Int], radius: Float, world: inout BlockWorld) {
        let extent = Int(Double(radius) + 0.618)
        for dx in -extent...extent {
            for dz in -extent...extent {
                let distance = sqrt(pow(Double(abs(dx)) + 0.5, 2) + pow(Double(abs(dz)) + 0.5, 2))
                if distance <= Double(radius) {
                    let position = BlockPosition(center[0] + dx, center[1], center[2] + dz)
                    if world[position] == nil || world[position] == .leaves { world[position] = .leaves }
                }
            }
        }
    }

    private func primaryAxis(from start: [Int], to end: [Int]) -> (delta: [Int], axis: Int) {
        let delta = zip(end, start).map(-)
        var axis = 0
        for index in 0..<3 where abs(delta[index]) > abs(delta[axis]) { axis = index }
        return (delta, axis)
    }

    private func obstruction(from start: [Int], to end: [Int], world: BlockWorld) -> Int {
        let (delta, axis) = primaryAxis(from: start, to: end)
        if delta[axis] == 0 { return -1 }
        let first = Self.otherAxes[axis]
        let second = Self.otherAxes[axis + 3]
        let direction = delta[axis] > 0 ? 1 : -1
        let slopeFirst = Double(delta[first]) / Double(delta[axis])
        let slopeSecond = Double(delta[second]) / Double(delta[axis])
        var offset = 0
        while offset != delta[axis] + direction {
            var point = [0, 0, 0]
            point[axis] = start[axis] + offset
            point[first] = Int(floor(Double(start[first]) + Double(offset) * slopeFirst))
            point[second] = Int(floor(Double(start[second]) + Double(offset) * slopeSecond))
            let kind = world[BlockPosition(point[0], point[1], point[2])]
            if kind != nil && kind != .leaves { return abs(offset) }
            offset += direction
        }
        return -1
    }

    private func line(from start: [Int], to end: [Int], world: inout BlockWorld) {
        let (delta, axis) = primaryAxis(from: start, to: end)
        if delta[axis] == 0 { return }
        let first = Self.otherAxes[axis]
        let second = Self.otherAxes[axis + 3]
        let direction = delta[axis] > 0 ? 1 : -1
        let slopeFirst = Double(delta[first]) / Double(delta[axis])
        let slopeSecond = Double(delta[second]) / Double(delta[axis])
        var offset = 0
        while offset != delta[axis] + direction {
            var point = [0, 0, 0]
            point[axis] = Int(floor(Double(start[axis] + offset) + 0.5))
            point[first] = Int(floor(Double(start[first]) + Double(offset) * slopeFirst + 0.5))
            point[second] = Int(floor(Double(start[second]) + Double(offset) * slopeSecond + 0.5))
            world[BlockPosition(point[0], point[1], point[2])] = .wood
            offset += direction
        }
    }
}
