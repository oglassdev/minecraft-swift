import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

public struct WorldDescriptor: Identifiable, Hashable, Sendable {
    public var id: URL { directory }
    public let directory: URL
    public let name: String
    public let seed: Int64
    public let time: Int64
    public let lastPlayed: Date?
    public let sizeOnDisk: Int64
    public let formatVersion: Int32
    public let requiresConversion: Bool
    public let isNew: Bool
}

public struct WorldCatalog: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory.standardizedFileURL }

    public func worlds() throws -> [WorldDescriptor] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let directories = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return directories.compactMap { child -> WorldDescriptor? in
            guard child.lastPathComponent != ".trash",
                let attributes = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                attributes.isDirectory == true, attributes.isSymbolicLink != true,
                let fields = levelFields(in: child)
            else { return nil }
            let version = Int32(truncatingIfNeeded: fields["version"]?.integerValue ?? 0)
            let played = fields["LastPlayed"]?.integerValue ?? 0
            let storedName = fields["LevelName"]?.stringValue ?? ""
            return WorldDescriptor(
                directory: child, name: storedName.isEmpty ? child.lastPathComponent : storedName,
                seed: fields["RandomSeed"]?.integerValue ?? 0, time: fields["Time"]?.integerValue ?? 0,
                lastPlayed: played == 0 ? nil : Date(timeIntervalSince1970: Double(played) / 1000),
                sizeOnDisk: fields["SizeOnDisk"]?.integerValue ?? 0, formatVersion: version,
                requiresConversion: version != 19132, isNew: false)
        }.sorted {
            if $0.lastPlayed != $1.lastPlayed {
                return ($0.lastPlayed ?? Date(timeIntervalSince1970: 0))
                    > ($1.lastPlayed ?? Date(timeIntervalSince1970: 0))
            }
            return $0.directory.lastPathComponent.utf16.lexicographicallyPrecedes(
                $1.directory.lastPathComponent.utf16)
        }
    }

    public func create(name: String, seedText: String) throws -> WorldDescriptor {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = Self.folderName(for: name)
        var candidate = base
        while true {
            let child = directory.appendingPathComponent(candidate, isDirectory: true)
            let result = child.withUnsafeFileSystemRepresentation { path in
                guard let path else { return Int32(-1) }
                return mkdir(path, 0o755)
            }
            if result == 0 {
                return WorldDescriptor(
                    directory: child, name: name.isEmpty ? "World" : name,
                    seed: Self.seed(from: seedText), time: 0, lastPlayed: nil,
                    sizeOnDisk: 0, formatVersion: 19132, requiresConversion: false, isNew: true)
            }
            let code = errno
            guard code == EEXIST else { throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO) }
            candidate = candidate.utf8.count < 240 ? candidate + "-" : base + "-" + UUID().uuidString
        }
    }

    public static func seed(
        from text: String,
        randomSeed: () -> Int64 = {
            var random = SystemRandomNumberGenerator()
            return Int64(bitPattern: random.next())
        }
    ) -> Int64 {
        guard !text.isEmpty else { return randomSeed() }
        if let number = JavaText.parseLong(text) { return number == 0 ? randomSeed() : number }
        return Int64(JavaText.hashCode(text))
    }

    private static func folderName(for name: String) -> String {
        let forbidden = Set("/\n\r\t\0\u{000C}`?*\\<>|\":".unicodeScalars)
        var result = String(
            String.UnicodeScalarView(
                JavaText.trim(name).unicodeScalars.map {
                    forbidden.contains($0) ? "_" : $0
                }))
        while result.utf8.count > 120 { result.removeLast() }
        if result.isEmpty || result == "." || result == ".." || result == ".trash" { result = "World" }
        return result
    }

    private func levelFields(in directory: URL) -> [String: NBTTag]? {
        for filename in ["level.dat", "level.dat_old"] {
            guard let compressed = try? Data(contentsOf: directory.appendingPathComponent(filename)),
                let data = try? NBTCompression.gzip.decompress(compressed),
                let root = try? NBTCodec.decode(data),
                let fields = root.tag.compoundValue?["Data"]?.compoundValue
            else { continue }
            return fields
        }
        return nil
    }
}
