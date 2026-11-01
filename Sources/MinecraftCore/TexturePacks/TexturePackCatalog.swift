import Foundation

public struct TexturePackDescriptor: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var isDefault: Bool { archiveURL == nil }
    public let name: String
    public let archiveURL: URL?
    public let descriptionLine1: String
    public let descriptionLine2: String
    public let iconData: Data?

    public static let defaultPack = TexturePackDescriptor(
        name: "Default", archiveURL: nil,
        descriptionLine1: "The default look of Minecraft", descriptionLine2: "", iconData: nil)
}

public struct TexturePackCatalog: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory.standardizedFileURL }

    public func packs() throws -> [TexturePackDescriptor] {
        var result: [TexturePackDescriptor] = [.defaultPack]
        for url in try archives() {
            let zip = try? ClassicZIP(url: url)
            let description =
                zip.flatMap { archive in
                    archive.entries.first(where: { $0.name == "pack.txt" }).flatMap {
                        try? archive.data(for: $0)
                    }
                }.map { Self.descriptionLines($0) } ?? []
            let icon = zip.flatMap { archive in
                archive.entries.first(where: { $0.name == "pack.png" }).flatMap { try? archive.data(for: $0) }
            }
            result.append(
                TexturePackDescriptor(
                    name: url.lastPathComponent, archiveURL: url,
                    descriptionLine1: description.first ?? "",
                    descriptionLine2: description.count > 1 ? description[1] : "",
                    iconData: icon))
        }
        return result
    }

    /// Returns only custom overrides; missing files remain the default pack's responsibility.
    public func select(name: String, to cacheDirectory: URL) throws -> URL? {
        guard name != "Default",
            let archiveURL = try archives().first(where: { $0.lastPathComponent == name })
        else { return nil }
        let zip = try ClassicZIP(url: archiveURL)
        let resources = zip.entries.filter {
            !$0.isDirectory && ($0.name == "pack.txt" || $0.name.lowercased().hasSuffix(".png"))
        }
        guard resources.count <= 4096 else { throw TexturePackError.exceedsLimits }
        var total = 0
        for resource in resources {
            total += resource.size
            guard resource.size <= ClassicZIP.maximumResourceSize, total <= ClassicZIP.maximumTotalSize else {
                throw TexturePackError.exceedsLimits
            }
        }
        let cache = cacheDirectory.standardizedFileURL
        guard cache.isFileURL else { throw TexturePackError.unsafePath(cache.absoluteString) }
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let identity = "pack-" + String(zip.fingerprint, radix: 16)
        let destination = cache.appendingPathComponent(identity, isDirectory: true)
        if validCache(at: destination, resources: resources, identity: identity) { return destination }
        let stage = cache.appendingPathComponent(".texturepack-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        var moved = false
        defer { if !moved { try? FileManager.default.removeItem(at: stage) } }
        for resource in resources {
            let data = try zip.data(for: resource)
            let target = stage.appendingPathComponent(resource.name)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .withoutOverwriting)
        }
        try Data(identity.utf8).write(
            to: stage.appendingPathComponent(".texturepack-source"), options: .withoutOverwriting)
        let target =
            FileManager.default.fileExists(atPath: destination.path)
            ? cache.appendingPathComponent(identity + "-\(UUID().uuidString)", isDirectory: true)
            : destination
        try FileManager.default.moveItem(at: stage, to: target)
        moved = true
        return target
    }

    private func archives() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ).filter { url in
            guard url.pathExtension.lowercased() == "zip",
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            else { return false }
            return values.isRegularFile == true && values.isSymbolicLink != true
        }.sorted { $0.lastPathComponent.utf16.lexicographicallyPrecedes($1.lastPathComponent.utf16) }
    }

    private func validCache(at root: URL, resources: [ClassicZIP.Entry], identity: String) -> Bool {
        guard let rootValues = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
            rootValues.isDirectory == true, rootValues.isSymbolicLink != true
        else { return false }
        guard
            (try? Data(contentsOf: root.appendingPathComponent(".texturepack-source"))) == Data(identity.utf8)
        else { return false }
        for resource in resources {
            let file = root.appendingPathComponent(resource.name)
            var parent = root
            for component in resource.name.split(separator: "/").dropLast() {
                parent.appendPathComponent(String(component), isDirectory: true)
                guard (try? parent.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == false
                else { return false }
            }
            guard
                let values = try? file.resourceValues(forKeys: [
                    .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
                ]),
                values.isRegularFile == true, values.isSymbolicLink != true, values.fileSize == resource.size,
                let data = try? Data(contentsOf: file), ClassicZIP.crc32(data) == resource.crc
            else { return false }
        }
        return true
    }

    private static func descriptionLines(_ data: Data) -> [String] {
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return text.split(separator: "\n", omittingEmptySubsequences: false).prefix(2).map {
            String(decoding: $0.utf16.prefix(34), as: UTF16.self)
        }
    }
}
