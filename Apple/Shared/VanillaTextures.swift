import CoreGraphics
import ImageIO
import MetalKit
import MinecraftCore

@MainActor
struct VanillaTextures {
    let atlas: MTLTexture
    let items: MTLTexture
    let colorMaps: BlockColorMaps?

    init(device: MTLDevice) throws {
        guard let url = TextureResources.url(for: "terrain"),
            let itemsURL = TextureResources.url(for: "gui/items")
        else {
            throw Renderer.SetupError.unavailable(
                "Vanilla textures are missing. Run just assets before building.")
        }
        atlas = try MTKTextureLoader(device: device).newTexture(
            URL: url,
            options: [
                .origin: MTKTextureLoader.Origin.topLeft,
                .SRGB: false,
                .generateMipmaps: false,
            ])
        items = try MTKTextureLoader(device: device).newTexture(
            URL: itemsURL,
            options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false, .generateMipmaps: false])
        if let grass = Self.loadColorMap("grasscolor"), let foliage = Self.loadColorMap("foliagecolor") {
            colorMaps = BlockColorMaps(grass: grass, foliage: foliage)
        } else {
            colorMaps = nil
        }
    }

    private static func loadColorMap(_ name: String) -> [UInt32]? {
        guard let image = loadRGBA("misc/\(name)"), image.width == 256, image.height == 256 else {
            return nil
        }
        let rgba = image.pixels
        return stride(from: 0, to: rgba.count, by: 4).map {
            UInt32(rgba[$0]) << 16 | UInt32(rgba[$0 + 1]) << 8 | UInt32(rgba[$0 + 2])
        }
    }

    static func loadRGBA(_ path: String, fromPack: Bool = true) -> (width: Int, height: Int, pixels: [UInt8])?
    {
        guard
            let url = fromPack ? TextureResources.url(for: path) : TextureResources.vanillaURL(for: path),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let width = image.width
        let height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return (width, height, rgba)
    }
}
