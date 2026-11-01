import Foundation

public struct LegacyConversionProgress: Sendable {
    public enum Stage: Sendable { case scanning, converting, finishing, complete }
    public let stage: Stage
    public let completedChunks: Int
    public let totalChunks: Int
    public var fractionCompleted: Double {
        totalChunks == 0 ? (stage == .complete ? 1 : 0) : Double(completedChunks) / Double(totalChunks)
    }
}

public struct LegacyConversionResult: Sendable {
    public let convertedChunks: Int
    public let skippedChunks: Int
    public let regionFiles: Int
    public let backupURL: URL?
    public var totalChunks: Int { convertedChunks + skippedChunks }
}

public enum LegacyConversionError: Error, LocalizedError {
    case missingLevel
    case unsupportedVersion(Int64)
    case invalidChunkName(String)
    case invalidChunk(URL, String)
    case symbolicLink(URL)

    public var errorDescription: String? {
        switch self {
        case .missingLevel: "The world has no readable level.dat or level.dat_old."
        case .unsupportedVersion(let version): "World format \(version) cannot be converted from Alpha."
        case .invalidChunkName(let name):
            "The legacy chunk coordinates in \(name) exceed the original format."
        case .invalidChunk(let url, let message): "Could not convert \(url.lastPathComponent): \(message)"
        case .symbolicLink(let url):
            "Conversion cannot write through the symbolic link \(url.lastPathComponent)."
        }
    }
}

public struct LegacyWorldConverter: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory.standardizedFileURL }

    @discardableResult
    public func convert(progress: (@Sendable (LegacyConversionProgress) -> Void)? = nil) throws
        -> LegacyConversionResult
    {
        progress?(LegacyConversionProgress(stage: .scanning, completedChunks: 0, totalChunks: 0))
        let (_, original, document) = try readLevel()
        guard var root = document.tag.compoundValue, var fields = root["Data"]?.compoundValue else {
            throw LegacyConversionError.missingLevel
        }
        let version = fields["version"]?.integerValue ?? 0
        if version == 19132 {
            progress?(LegacyConversionProgress(stage: .complete, completedChunks: 0, totalChunks: 0))
            return LegacyConversionResult(
                convertedChunks: 0, skippedChunks: 0, regionFiles: 0, backupURL: nil)
        }
        guard version == 0 else { throw LegacyConversionError.unsupportedVersion(version) }
        var chunks: [LegacyChunk] = []
        for dimension in [directory, directory.appendingPathComponent("DIM-1", isDirectory: true)] {
            chunks += try scan(dimension)
        }
        chunks.sort {
            if $0.dimension != $1.dimension { return $0.dimension.path < $1.dimension.path }
            if $0.position.x >> 5 != $1.position.x >> 5 { return $0.position.x >> 5 < $1.position.x >> 5 }
            if $0.position.z >> 5 != $1.position.z >> 5 { return $0.position.z >> 5 < $1.position.z >> 5 }
            return $0.url.path < $1.url.path
        }
        var converted = 0
        var skipped = 0
        var regions = Set<URL>()
        for chunk in chunks {
            progress?(
                LegacyConversionProgress(
                    stage: .converting, completedChunks: converted + skipped, totalChunks: chunks.count))
            let folder = chunk.dimension.appendingPathComponent("region", isDirectory: true)
            let destination = folder.appendingPathComponent(
                "r.\(chunk.position.x >> 5).\(chunk.position.z >> 5).mcr")
            try rejectSymbolicLink(folder)
            try rejectSymbolicLink(destination)
            let region = McRegionFile(url: destination)
            if let existing = try region.readChunkData(at: chunk.position) {
                _ = try NBTCodec.decode(existing)
                skipped += 1
            } else {
                do {
                    let bytes = try NBTCompression.gzip.decompress(Data(contentsOf: chunk.url))
                    _ = try NBTCodec.decode(bytes)
                    try region.writeChunkData(bytes, at: chunk.position)
                } catch {
                    throw LegacyConversionError.invalidChunk(chunk.url, error.localizedDescription)
                }
                converted += 1
            }
            regions.insert(destination)
        }
        progress?(
            LegacyConversionProgress(
                stage: .finishing, completedChunks: chunks.count, totalChunks: chunks.count))
        fields["version"] = .int(19132)
        root["Data"] = .compound(fields)
        let updated = try NBTCompression.gzip.compress(
            NBTCodec.encode(NBTDocument(name: document.name, tag: .compound(root))))
        let backup = try backupLevel(data: original)
        try updated.write(to: directory.appendingPathComponent("level.dat"), options: .atomic)
        progress?(
            LegacyConversionProgress(
                stage: .complete, completedChunks: chunks.count, totalChunks: chunks.count))
        return LegacyConversionResult(
            convertedChunks: converted, skippedChunks: skipped, regionFiles: regions.count, backupURL: backup)
    }

    private struct LegacyChunk {
        let url: URL
        let dimension: URL
        let position: ChunkPosition
    }

    private func readLevel() throws -> (URL, Data, NBTDocument) {
        try rejectSymbolicLink(directory)
        for filename in ["level.dat", "level.dat_old"] {
            let url = directory.appendingPathComponent(filename)
            try rejectSymbolicLink(url)
            guard let source = try? Data(contentsOf: url),
                let decompressed = try? NBTCompression.gzip.decompress(source),
                let document = try? NBTCodec.decode(decompressed),
                document.tag.compoundValue?["Data"]?.compoundValue != nil
            else { continue }
            return (url, source, document)
        }
        throw LegacyConversionError.missingLevel
    }

    private func scan(_ dimension: URL) throws -> [LegacyChunk] {
        try rejectSymbolicLink(dimension)
        guard try isDirectory(dimension) else { return [] }
        var chunks: [LegacyChunk] = []
        for x in try children(dimension) {
            guard isAxisName(x.lastPathComponent) else { continue }
            try rejectSymbolicLink(x)
            guard try isDirectory(x) else { continue }
            for z in try children(x) {
                guard isAxisName(z.lastPathComponent) else { continue }
                try rejectSymbolicLink(z)
                guard try isDirectory(z) else { continue }
                for file in try children(z) {
                    let parts = file.lastPathComponent.split(separator: ".", omittingEmptySubsequences: false)
                    guard parts.count == 4, parts[0] == "c", parts[3] == "dat",
                        isCoordinate(parts[1]), isCoordinate(parts[2])
                    else { continue }
                    try rejectSymbolicLink(file)
                    let attributes = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else {
                        continue
                    }
                    guard let cx = Int32(parts[1], radix: 36), let cz = Int32(parts[2], radix: 36) else {
                        throw LegacyConversionError.invalidChunkName(file.lastPathComponent)
                    }
                    chunks.append(
                        LegacyChunk(
                            url: file, dimension: dimension, position: ChunkPosition(Int(cx), Int(cz))))
                }
            }
        }
        return chunks
    }

    private func children(_ url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
    }

    private func isDirectory(_ url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let attributes = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return attributes.isDirectory == true && attributes.isSymbolicLink != true
    }

    private func isAxisName(_ name: String) -> Bool {
        (1...2).contains(name.utf8.count)
            && name.utf8.allSatisfy { (48...57).contains($0) || (97...122).contains($0) }
    }

    private func isCoordinate(_ name: Substring) -> Bool {
        let digits = name.hasPrefix("-") ? name.dropFirst() : name[...]
        return !digits.isEmpty && digits.utf8.allSatisfy { (48...57).contains($0) || (97...122).contains($0) }
    }

    private func rejectSymbolicLink(_ url: URL) throws {
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            throw LegacyConversionError.symbolicLink(url)
        }
    }

    private func backupLevel(data: Data) throws -> URL {
        var candidate = directory.appendingPathComponent("level.dat_before_conversion")
        while true {
            do {
                try data.write(to: candidate, options: .withoutOverwriting)
                return candidate
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                candidate = directory.appendingPathComponent(
                    "level.dat_before_conversion-\(UUID().uuidString)")
            }
        }
    }
}
