public struct BetaTimer: Sendable {
    public var partialTick: Float = 0

    public init() {}

    public mutating func advance(seconds: Double) -> Int {
        let seconds = seconds.isFinite ? min(1, max(0, seconds)) : 0
        partialTick = Float(Double(partialTick) + seconds * 20)
        let ticks = Int(partialTick)
        partialTick -= Float(ticks)
        return min(10, ticks)
    }
}

public struct BetaMouseFilter: Sendable {
    private var accumulated: Float = 0
    private var consumed: Float = 0
    private var smoothed: Float = 0

    public init() {}

    public mutating func filter(_ delta: Float, factor: Float) -> Float {
        accumulated += delta
        var movement = (accumulated - consumed) * factor
        smoothed += (movement - smoothed) * 0.5
        if (movement > 0 && movement > smoothed) || (movement < 0 && movement < smoothed) {
            movement = smoothed
        }
        consumed += movement
        return movement
    }
}
