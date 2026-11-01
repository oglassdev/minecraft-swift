import ImageIO
import SwiftUI

private struct BetaGUIRasterScaleKey: EnvironmentKey {
    static let defaultValue = 1
}

extension EnvironmentValues {
    var betaGUIRasterScale: Int {
        get { self[BetaGUIRasterScaleKey.self] }
        set { self[BetaGUIRasterScaleKey.self] = newValue }
    }
}

struct BetaGUIResolution {
    let width: Int
    let height: Int
    let scale: Int
    let pointsPerPixel: CGFloat

    init(size: CGSize, displayScale: CGFloat, option: Int) {
        let pixelWidth = max(1, Int(size.width * displayScale))
        let pixelHeight = max(1, Int(size.height * displayScale))
        let requested = option == 0 ? 1000 : max(1, option)
        var scale = 1
        while scale < requested && pixelWidth / (scale + 1) >= 320 && pixelHeight / (scale + 1) >= 240 {
            scale += 1
        }
        self.scale = scale
        width = Int(ceil(Double(pixelWidth) / Double(scale)))
        height = Int(ceil(Double(pixelHeight) / Double(scale)))
        pointsPerPixel = CGFloat(scale) / max(1, displayScale)
    }
}

struct BetaGUI<Content: View>: View {
    var option: Int
    @ViewBuilder var content: (BetaGUIResolution) -> Content
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let resolution = BetaGUIResolution(
                size: geometry.size, displayScale: displayScale, option: option)
            content(resolution)
                .environment(\.betaGUIRasterScale, resolution.scale)
                .frame(
                    width: CGFloat(resolution.width), height: CGFloat(resolution.height),
                    alignment: .topLeading
                )
                .scaleEffect(resolution.pointsPerPixel, anchor: .topLeading)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
        }
    }
}

struct BetaSprite: View {
    let name: String
    let rect: CGRect
    @ObservedObject private var sprites = VanillaUISprites.shared
    var body: some View {
        Group {
            if let image = VanillaUISprites.sprite(name, rect: rect) {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
            } else {
                Color.clear.frame(width: rect.width, height: rect.height)
            }
        }.frame(width: rect.width, height: rect.height)
    }
}

@MainActor
final class VanillaUISprites: ObservableObject {
    static let shared = VanillaUISprites()
    @Published private(set) var revision: UInt64 = 0
    private var images: [String: CGImage] = [:]
    private var crops: [String: CGImage] = [:]

    static func reset() {
        shared.images.removeAll()
        shared.crops.removeAll()
        shared.revision &+= 1
    }
    static func image(_ name: String) -> CGImage? {
        if let image = shared.images[name] { return image }
        guard let url = TextureResources.url(for: name),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        shared.images[name] = image
        return image
    }
    static func sprite(_ name: String, rect: CGRect) -> CGImage? {
        let key = "\(name):\(rect)"
        if let cached = shared.crops[key] { return cached }
        guard let image = image(name) else { return nil }
        let reference: CGSize
        switch name {
        case "gui/background.png": reference = CGSize(width: 16, height: 16)
        case "gui/slot.png", "font/default.png": reference = CGSize(width: 128, height: 128)
        case "item/sign.png": reference = CGSize(width: 64, height: 32)
        default: reference = CGSize(width: 256, height: 256)
        }
        let scaled = CGRect(
            x: rect.minX * CGFloat(image.width) / reference.width,
            y: rect.minY * CGFloat(image.height) / reference.height,
            width: rect.width * CGFloat(image.width) / reference.width,
            height: rect.height * CGFloat(image.height) / reference.height)
        let cropped = image.cropping(to: scaled)
        shared.crops[key] = cropped
        return cropped
    }
}
