import Foundation

/// The 48-bit generator used by java.util.Random in the original game.
public struct JavaRandom: Sendable {
    private static let multiplier: UInt64 = 0x5_DEEC_E66D
    private static let mask: UInt64 = (1 << 48) - 1
    private var state: UInt64
    private var gaussian: Double?

    public init(seed: Int64) {
        state = (UInt64(bitPattern: seed) ^ Self.multiplier) & Self.mask
    }

    public mutating func setSeed(_ seed: Int64) {
        state = (UInt64(bitPattern: seed) ^ Self.multiplier) & Self.mask
        gaussian = nil
    }

    private mutating func next(_ bits: Int) -> UInt32 {
        state = (state &* Self.multiplier &+ 11) & Self.mask
        return UInt32(state >> (48 - bits))
    }

    public mutating func nextInt() -> Int32 {
        Int32(bitPattern: next(32))
    }

    public mutating func nextInt(bound: Int) -> Int {
        precondition(bound > 0 && bound <= Int(Int32.max))
        if bound & (bound - 1) == 0 {
            return Int((Int64(bound) * Int64(next(31))) >> 31)
        }
        while true {
            let bits = Int(next(31))
            let value = bits % bound
            if Int32(truncatingIfNeeded: bits - value + bound - 1) >= 0 { return value }
        }
    }

    public mutating func nextLong() -> Int64 {
        (Int64(nextInt()) << 32) &+ Int64(nextInt())
    }

    public mutating func nextBoolean() -> Bool { next(1) != 0 }

    public mutating func nextFloat() -> Float { Float(next(24)) / 16_777_216 }

    public mutating func nextDouble() -> Double {
        Double((UInt64(next(26)) << 27) + UInt64(next(27))) / 9_007_199_254_740_992
    }

    public mutating func nextGaussian() -> Double {
        if let value = gaussian {
            gaussian = nil
            return value
        }
        while true {
            let x = 2 * nextDouble() - 1
            let y = 2 * nextDouble() - 1
            let squared = x * x + y * y
            if squared < 1 && squared != 0 {
                let scale = sqrt(-2 * log(squared) / squared)
                gaussian = y * scale
                return x * scale
            }
        }
    }
}
