public enum BlockSounds {
    public static func step(for kind: BlockKind, at position: SIMD3<Double>) -> BlockEvent {
        let name: String
        let volume: Float
        let pitch: Float
        switch kind.rawValue {
        case 1, 4, 7, 8, 9, 10, 11, 14, 15, 16, 20, 21, 22, 23, 24, 25, 26, 29, 30, 33, 34, 36, 43, 44, 45,
            48, 49, 55, 56, 61, 62, 67, 70, 73, 74, 77, 79, 84, 87, 89, 90:
            name = "step.stone"
            volume = 1.0
            pitch = 1.0
        case 2, 6, 18, 19, 31, 32, 37, 38, 39, 40, 46, 59, 83:
            name = "step.grass"
            volume = 1.0
            pitch = 1.0
        case 3, 13, 60, 82:
            name = "step.gravel"
            volume = 1.0
            pitch = 1.0
        case 5, 17, 47, 50, 51, 53, 54, 58, 63, 64, 65, 68, 69, 72, 75, 76, 85, 86, 91, 93, 94, 95, 96:
            name = "step.wood"
            volume = 1.0
            pitch = 1.0
        case 12, 88:
            name = "step.sand"
            volume = 1.0
            pitch = 1.0
        case 27, 28, 41, 42, 52, 57, 66, 71:
            name = "step.stone"
            volume = 1.0
            pitch = 1.5
        case 35, 78, 80, 81, 92:
            name = "step.cloth"
            volume = 1.0
            pitch = 1.0
        default:
            name = "step.stone"
            volume = 1
            pitch = 1
        }
        return .sound(name: name, position: position, volume: volume * 0.15, pitch: pitch)
    }
}
