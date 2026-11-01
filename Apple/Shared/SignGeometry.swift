import Foundation
import MinecraftCore
import simd

@MainActor
struct SignGeometry {
    private var widths = [Int](repeating: 6, count: 256)
    private var characters: [Character: Int] = [:]

    init() {
        if let root = Bundle.main.resourceURL,
            let text = try? String(
                contentsOf: root.appendingPathComponent("Vanilla/font.txt"), encoding: .utf8)
        {
            let allowed = text.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }.joined()
            for (index, character) in allowed.enumerated() where characters[character] == nil {
                characters[character] = index + 32
            }
        }
        guard let image = VanillaTextures.loadRGBA("font/default"), image.width == 128 && image.height == 128
        else { return }
        for character in 0..<256 {
            var right = -1
            for x in (0..<8).reversed() {
                let column = character % 16 * 8 + x
                if (0..<8).contains(where: { y in
                    image.pixels[((character / 16 * 8 + y) * 128 + column) * 4 + 2] > 0
                }) {
                    right = x
                    break
                }
            }
            widths[character] = character == 32 ? 4 : right + 2
        }
    }

    func vertices(state: BlockState, lines: [String], position: SIMD3<Float>, light: UInt8) -> (
        board: [BlockVertex], text: [BlockVertex]
    ) {
        let standing = state.kind.rawValue == 63
        let degrees: Float =
            standing
            ? Float(state.metadata) * 360 / 16
            : (state.metadata == 2 ? 180 : (state.metadata == 4 ? 90 : (state.metadata == 5 ? -90 : 0)))
        let angle = degrees * .pi / 180
        let anchor =
            position + SIMD3(0.5, 0.5, 0.5)
            + (standing ? .zero : EntityModelPart.rotate(SIMD3(0, -0.3125, -0.4375), by: SIMD3(0, -angle, 0)))
        var parts = [EntityModelPart(SIMD3(-12, -14, -1), SIMD3(24, 12, 2), at: .zero, uv: .zero)]
        if standing {
            parts.append(EntityModelPart(SIMD3(-1, -2, -1), SIMD3(2, 14, 2), at: .zero, uv: SIMD2(0, 14)))
        }
        let board = parts.flatMap {
            $0.vertices(
                position: anchor, yaw: angle - .pi, scale: 2 / 3,
                originY: 0, tint: SIMD3(repeating: 1), light: light, opacity: 1)
        }
        var text: [BlockVertex] = []
        let factor: Float = 1 / 90
        for row in 0..<min(4, lines.count) {
            let glyphs = lines[row].compactMap { characters[$0] }.filter { $0 < 256 }
            var x = -Float(glyphs.reduce(0) { $0 + widths[$1] }) / 2
            let y = Float(row * 10 - 20)
            for glyph in glyphs {
                let u = Float(glyph % 16) / 16
                let v = Float(glyph / 16) / 16
                let uv = [
                    SIMD2(u, v + 7.99 / 128), SIMD2(u + 7.99 / 128, v + 7.99 / 128), SIMD2(u + 7.99 / 128, v),
                    SIMD2(u, v),
                ]
                let points = [
                    SIMD3(x, y + 7.99, 0), SIMD3(x + 7.99, y + 7.99, 0), SIMD3(x + 7.99, y, 0),
                    SIMD3(x, y, 0),
                ].map {
                    anchor
                        + EntityModelPart.rotate(
                            SIMD3($0.x * factor, 1 / 3 - $0.y * factor, 0.0468), by: SIMD3(0, -angle, 0))
                }
                text += [0, 1, 2, 0, 2, 3].map {
                    BlockVertex(position: points[$0], color: .zero, uv: uv[$0], light: light)
                }
                x += Float(widths[glyph])
            }
        }
        return (board, text)
    }
}
