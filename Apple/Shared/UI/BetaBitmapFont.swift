import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

@MainActor
final class BetaBitmapFont {
    static let shared = BetaBitmapFont(
        resourceDirectory: Bundle.main.resourceURL?.appendingPathComponent("Vanilla"))
    private var pixels: [UInt8] = []
    private var advances = Array(repeating: 0, count: 256)
    private var characters: [UInt16: Int] = [:]
    private var cache: [String: CGImage] = [:]

    init(resourceDirectory: URL?) {
        guard let resourceDirectory,
            let source = CGImageSourceCreateWithURL(
                resourceDirectory.appendingPathComponent("font/default.png") as CFURL, nil),
            let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let alphabet = try? String(
                contentsOf: resourceDirectory.appendingPathComponent("font.txt"), encoding: .utf8)
        else { return }
        pixels = Array(repeating: 0, count: 128 * 128 * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: 128, height: 128, bitsPerComponent: 8,
                    bytesPerRow: 128 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.draw(atlas, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        let allowed = alphabet.components(separatedBy: .newlines).filter { !$0.hasPrefix("#") }.joined()
        for (index, character) in allowed.utf16.enumerated() where characters[character] == nil {
            characters[character] = index + 32
        }
        for glyph in 0..<256 {
            var right = -1
            for x in stride(from: 7, through: 0, by: -1) {
                if (0..<8).contains(where: { y in
                    pixels[((glyph / 16 * 8 + y) * 128 + glyph % 16 * 8 + x) * 4 + 2] > 0
                }) {
                    right = x
                    break
                }
            }
            if glyph == 32 { right = 2 }
            advances[glyph] = right + 2
        }
    }

    func width(_ text: String) -> Int {
        var width = 0
        var maximum = 0
        var index = 0
        let units = Array(text.utf16)
        while index < units.count {
            let character = units[index]
            if character == 167 {
                index += 2
                continue
            }
            if character == 10 {
                maximum = max(maximum, width)
                width = 0
            } else if let glyph = characters[character] {
                width += advances[glyph]
            }
            index += 1
        }
        return max(maximum, width)
    }

    func image(_ text: String, color: UInt32 = 0xFFFFFF, shadow: Bool = true) -> CGImage? {
        guard !pixels.isEmpty, !text.isEmpty else { return nil }
        let key = "\(color):\(shadow):\(text)"
        if let image = cache[key] { return image }
        let width = max(1, self.width(text) + (shadow ? 1 : 0))
        let height =
            max(8, text.split(separator: "\n", omittingEmptySubsequences: false).count * 8) + (shadow ? 1 : 0)
        var result = Array(repeating: UInt8(0), count: width * height * 4)
        let units = Array(text.utf16)
        for pass in (shadow ? [true, false] : [false]) {
            var x = pass ? 1 : 0
            var y = pass ? 1 : 0
            var index = 0
            var tint = pass ? (color & 0xFCFCFC) >> 2 : color & 0xFFFFFF
            while index < units.count {
                let character = units[index]
                if character == 167 && index + 1 < units.count {
                    let code = UnicodeScalar(units[index + 1]).map { String($0).lowercased() } ?? "f"
                    let number =
                        "0123456789abcdef".firstIndex(of: code.first ?? "f").map {
                            "0123456789abcdef".distance(from: "0123456789abcdef".startIndex, to: $0)
                        } ?? 15
                    tint = palette(number, shadow: pass)
                    index += 2
                    continue
                }
                if character == 10 {
                    x = pass ? 1 : 0
                    y += 8
                    index += 1
                    continue
                }
                if let glyph = characters[character] {
                    for gy in 0..<8 {
                        for gx in 0..<8 where x + gx < width && y + gy < height {
                            let source = ((glyph / 16 * 8 + gy) * 128 + glyph % 16 * 8 + gx) * 4
                            let alpha = UInt32(pixels[source + 3])
                            guard alpha > 0 else { continue }
                            let destination = ((y + gy) * width + x + gx) * 4
                            for component in 0..<3 {
                                let channel = (tint >> (16 - component * 8)) & 255
                                let value = UInt32(pixels[source + component]) * channel / 255
                                result[destination + component] = UInt8(
                                    min(
                                        255,
                                        value + UInt32(result[destination + component]) * (255 - alpha) / 255)
                                )
                            }
                            result[destination + 3] = UInt8(
                                min(255, alpha + UInt32(result[destination + 3]) * (255 - alpha) / 255))
                        }
                    }
                    x += advances[glyph]
                }
                index += 1
            }
        }
        guard let provider = CGDataProvider(data: Data(result) as CFData),
            let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        if cache.count > 512 { cache.removeAll(keepingCapacity: true) }
        cache[key] = image
        return image
    }

    private func palette(_ code: Int, shadow: Bool) -> UInt32 {
        let extra = (code >> 3 & 1) * 85
        var red = (code >> 2 & 1) * 170 + extra
        var green = (code >> 1 & 1) * 170 + extra
        var blue = (code & 1) * 170 + extra
        if code == 6 && !shadow { red += 85 }
        if shadow {
            red /= 4
            green /= 4
            blue /= 4
        }
        return UInt32(red << 16 | green << 8 | blue)
    }
}

struct BetaText: View {
    let text: String
    var color: UInt32 = 0xFFFFFF
    var shadow = true

    init(_ text: String, color: UInt32 = 0xFFFFFF, shadow: Bool = true) {
        self.text = text
        self.color = color
        self.shadow = shadow
    }

    var body: some View {
        Group {
            if let image = BetaBitmapFont.shared.image(text, color: color, shadow: shadow) {
                Image(decorative: image, scale: 1).interpolation(.none)
            } else {
                Color.clear.frame(width: CGFloat(BetaBitmapFont.shared.width(text)), height: 8)
            }
        }.accessibilityLabel(text)
    }
}
