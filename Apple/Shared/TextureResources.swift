import Foundation
import MetalKit

@MainActor
enum TextureResources {
    private static var overrideURL: URL?
    private static var revision: UInt64?

    static func configure(overrideURL: URL?, revision: UInt64) {
        guard self.overrideURL != overrideURL || self.revision != revision else { return }
        self.overrideURL = overrideURL
        self.revision = revision
    }

    static func url(for path: String) -> URL? {
        let path = path.hasSuffix(".png") ? path : path + ".png"
        if path != "font/default.png", let override = overrideURL?.appendingPathComponent(path),
            FileManager.default.fileExists(atPath: override.path)
        {
            return override
        }
        return vanillaURL(for: path)
    }

    static func vanillaURL(for path: String) -> URL? {
        let path = path.hasSuffix(".png") ? path : path + ".png"
        guard let root = Bundle.main.resourceURL else { return nil }
        let fallback = root.appendingPathComponent("Vanilla/\(path)")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }
}

/// Lazily loads resource-pack textures by path and keeps them until `removeAll()`.
@MainActor
final class NamedTextures {
    private let loader: MTKTextureLoader
    private var cache: [String: MTLTexture] = [:]

    init(device: MTLDevice) { loader = MTKTextureLoader(device: device) }

    func removeAll() { cache.removeAll() }

    func texture(_ name: String) -> MTLTexture? {
        if let cached = cache[name] { return cached }
        guard let url = TextureResources.url(for: name),
            let texture = try? loader.newTexture(
                URL: url, options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false])
        else { return nil }
        cache[name] = texture
        return texture
    }
}

extension MTLDevice {
    func makeSharedBuffer<Element: BitwiseCopyable>(_ elements: [Element]) -> MTLBuffer? {
        guard !elements.isEmpty else { return nil }
        return elements.withUnsafeBytes {
            makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
        }
    }
}
