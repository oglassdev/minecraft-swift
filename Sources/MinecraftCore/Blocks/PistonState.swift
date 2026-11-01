public struct PistonState: Codable, Equatable, Sendable {
    public var block: BlockState
    public var facing: UInt8
    public var extending: Bool
    public var isSource: Bool
    public var progress: Float
    public var previousProgress: Float

    public init(
        block: BlockState, facing: UInt8, extending: Bool, isSource: Bool = false,
        progress: Float = 0, previousProgress: Float? = nil
    ) {
        self.block = block
        self.facing = facing & 7
        self.extending = extending
        self.isSource = isSource
        self.progress = min(1, max(0, progress))
        self.previousProgress = min(1, max(0, previousProgress ?? progress))
    }

    public func interpolatedProgress(_ fraction: Float) -> Float {
        previousProgress + (progress - previousProgress) * min(1, max(0, fraction))
    }

    public func offset(interpolation: Float) -> SIMD3<Float> {
        let progress = interpolatedProgress(interpolation)
        return direction * (extending ? progress - 1 : 1 - progress)
    }

    public func storedCollisionBounds(at p: BlockPosition) -> AxisAlignedBox? {
        if block.kind == .movingPiston { return nil }
        if [.pistonHead, .woodenStairs, .cobblestoneStairs].contains(block.kind) {
            let origin = SIMD3(Double(p.x), Double(p.y), Double(p.z))
            return AxisAlignedBox(min: origin, max: origin + SIMD3(repeating: 1))
        }
        return BlockCollision.boxes(for: block, at: p).first
    }

    public var collisionOffset: SIMD3<Double> {
        let distance = extending ? 1 - previousProgress : previousProgress
        return -SIMD3<Double>(direction) * Double(distance)
    }

    public var direction: SIMD3<Float> {
        guard facing < 6 else { return .zero }
        let offset = BlockPower.directions[Int(facing)]
        return SIMD3(Float(offset.x), Float(offset.y), Float(offset.z))
    }
}
