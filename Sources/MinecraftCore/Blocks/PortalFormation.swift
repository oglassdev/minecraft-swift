enum PortalFormation {
    static func form(at p: BlockPosition, world: inout BlockWorld) -> [BlockPosition] {
        let xAxis =
            world[p.adding(BlockPosition(-1, 0, 0))] == .obsidian
            || world[p.adding(BlockPosition(1, 0, 0))] == .obsidian
        let zAxis =
            world[p.adding(BlockPosition(0, 0, -1))] == .obsidian
            || world[p.adding(BlockPosition(0, 0, 1))] == .obsidian
        guard xAxis != zAxis else { return [] }
        let axis = xAxis ? BlockPosition(1, 0, 0) : BlockPosition(0, 0, 1)
        var origin = p
        if world[p.adding(BlockPosition(-axis.x, 0, -axis.z))] == nil {
            origin = p.adding(BlockPosition(-axis.x, 0, -axis.z))
        }
        for x in -1...2 {
            for y in -1...3 {
                let edge = x == -1 || x == 2 || y == -1 || y == 3
                if (x == -1 || x == 2) && (y == -1 || y == 3) { continue }
                let kind = world[origin.adding(BlockPosition(axis.x * x, y, axis.z * x))]
                if edge {
                    if kind != .obsidian { return [] }
                } else if kind != nil && kind != .fire {
                    return []
                }
            }
        }
        var placed: [BlockPosition] = []
        for x in 0..<2 {
            for y in 0..<3 {
                let target = origin.adding(BlockPosition(axis.x * x, y, axis.z * x))
                world[target] = .portal
                placed.append(target)
            }
        }
        return placed
    }

    static func isValid(at p: BlockPosition, world: BlockWorld) -> Bool {
        let xAxis =
            world[p.adding(BlockPosition(-1, 0, 0))] == .portal
            || world[p.adding(BlockPosition(1, 0, 0))] == .portal
        let zAxis =
            world[p.adding(BlockPosition(0, 0, -1))] == .portal
            || world[p.adding(BlockPosition(0, 0, 1))] == .portal
        guard xAxis != zAxis else { return false }
        let axis = xAxis ? BlockPosition(1, 0, 0) : BlockPosition(0, 0, 1)
        var bottom = p
        while bottom.y > 0 && world[bottom.adding(BlockPosition(0, -1, 0))] == .portal { bottom.y -= 1 }
        guard world[bottom.adding(BlockPosition(0, -1, 0))] == .obsidian else { return false }
        var height = 1
        while height < 4 && world[bottom.adding(BlockPosition(0, height, 0))] == .portal { height += 1 }
        guard height == 3, world[bottom.adding(BlockPosition(0, height, 0))] == .obsidian else {
            return false
        }
        let left = world[p.adding(BlockPosition(-axis.x, 0, -axis.z))]
        let right = world[p.adding(axis)]
        return left == .obsidian && right == .portal || left == .portal && right == .obsidian
    }
}
