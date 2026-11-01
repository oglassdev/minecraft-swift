import Foundation
import Metal
import MinecraftCore

@MainActor
struct ItemTextureAnimation {
    private var elapsed: Float = 0.05
    private let compass: [UInt8]
    private let clock: [UInt8]
    private let dial: [UInt8]
    private let compassIndex = ItemDefinition.definition(for: 345)!.iconIndex
    private let clockIndex = ItemDefinition.definition(for: 347)!.iconIndex

    init() {
        let pixels =
            VanillaTextures.loadRGBA("gui/items")?.pixels ?? [UInt8](repeating: 0, count: 256 * 256 * 4)
        func tile(_ index: Int) -> [UInt8] {
            (0..<1024).map { offset in
                let pixel = offset / 4
                return pixels[
                    (((index >> 4) * 16 + pixel / 16) * 256 + (index & 15) * 16 + pixel % 16) * 4 + offset % 4
                ]
            }
        }
        compass = tile(compassIndex)
        clock = tile(clockIndex)
        dial = VanillaTextures.loadRGBA("misc/dial")?.pixels ?? [UInt8](repeating: 0, count: 1024)
    }

    mutating func encode(
        delta: Float, compassAngle: Double, clockAngle: Double, device: MTLDevice,
        atlas: MTLTexture, commandBuffer: MTLCommandBuffer
    ) {
        elapsed += delta
        guard elapsed >= 0.05, let encoder = commandBuffer.makeBlitCommandEncoder() else { return }
        elapsed = elapsed.truncatingRemainder(dividingBy: 0.05)
        encoder.label = "Animate compass and watch"
        LiquidTextureAnimation.upload(
            Self.compassPixels(base: compass, angle: compassAngle), index: compassIndex, device: device,
            atlas: atlas, encoder: encoder)
        LiquidTextureAnimation.upload(
            Self.clockPixels(base: clock, dial: dial, angle: clockAngle), index: clockIndex, device: device,
            atlas: atlas, encoder: encoder)
        encoder.endEncoding()
    }

    static func compassPixels(base: [UInt8], angle: Double) -> [UInt8] {
        var result = base
        let sine = sin(angle)
        let cosine = cos(angle)
        for step in -4...4 {
            let x = Int(8.5 + cosine * Double(step) * 0.3)
            let y = Int(7.5 - sine * Double(step) * 0.3 * 0.5)
            let index = (y * 16 + x) * 4
            result[index] = 100
            result[index + 1] = 100
            result[index + 2] = 100
            result[index + 3] = 255
        }
        for step in -8...16 {
            let x = Int(8.5 + sine * Double(step) * 0.3)
            let y = Int(7.5 + cosine * Double(step) * 0.3 * 0.5)
            let index = (y * 16 + x) * 4
            result[index] = step >= 0 ? 255 : 100
            result[index + 1] = step >= 0 ? 20 : 100
            result[index + 2] = result[index + 1]
            result[index + 3] = 255
        }
        return result
    }

    static func clockPixels(base: [UInt8], dial: [UInt8], angle: Double) -> [UInt8] {
        var result = base
        let sine = sin(angle)
        let cosine = cos(angle)
        for pixel in 0..<256 {
            let offset = pixel * 4
            let red = Int(base[offset])
            let green = base[offset + 1]
            let blue = Int(base[offset + 2])
            guard red == blue && green == 0 && blue > 0 else { continue }
            let x = -(Double(pixel % 16) / 15 - 0.5)
            let y = Double(pixel / 16) / 15 - 0.5
            let sourceX = Int((x * cosine + y * sine + 0.5) * 16)
            let sourceY = Int((y * cosine - x * sine + 0.5) * 16)
            let source = ((sourceX & 15) + (sourceY & 15) * 16) * 4
            for channel in 0..<3 { result[offset + channel] = UInt8(Int(dial[source + channel]) * red / 255) }
            result[offset + 3] = dial[source + 3]
        }
        return result
    }
}
