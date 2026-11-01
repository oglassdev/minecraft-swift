import Foundation

public struct BetaMapStorage: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public func load() throws -> BetaMapCollection {
        guard FileManager.default.fileExists(atPath: directory.path) else { return BetaMapCollection() }
        var counts: [String: Int16] = [:]
        let countFile = directory.appendingPathComponent("idcounts.dat")
        if FileManager.default.fileExists(atPath: countFile.path) {
            let document = try NBTCodec.decode(Data(contentsOf: countFile))
            for (key, tag) in document.tag.compoundValue ?? [:] {
                if case .short(let count) = tag { counts[key] = count }
            }
        }
        var maps: [Int16: BetaMapData] = [:]
        for file in try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        {
            let name = file.deletingPathExtension().lastPathComponent
            guard file.pathExtension == "dat", name.hasPrefix("map_"), let id = Int16(name.dropFirst(4))
            else { continue }
            let data = try NBTCompression.gzip.decompress(Data(contentsOf: file))
            maps[id] = try BetaMapData.decode(id: id, document: NBTCodec.decode(data))
        }
        return BetaMapCollection(maps: maps, idCounts: counts)
    }

    public func save(_ collection: BetaMapCollection) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let counts = collection.idCounts.mapValues { NBTTag.short($0) }
        try NBTCodec.encode(NBTDocument(tag: .compound(counts)))
            .write(to: directory.appendingPathComponent("idcounts.dat"), options: .atomic)
        for map in collection.maps.values {
            let data = try NBTCompression.gzip.compress(NBTCodec.encode(map.nbtDocument))
            try data.write(to: directory.appendingPathComponent("map_\(map.id).dat"), options: .atomic)
        }
    }
}

extension BetaMapData {
    public var nbtDocument: NBTDocument {
        var fields = originalFields
        fields["dimension"] = .byte(dimension)
        fields["xCenter"] = .int(centerX)
        fields["zCenter"] = .int(centerZ)
        fields["scale"] = .byte(Int8(scale))
        fields["width"] = .short(128)
        fields["height"] = .short(128)
        fields["colors"] = .byteArray(colors)
        return NBTDocument(tag: .compound(["data": .compound(fields)]))
    }

    public static func decode(id: Int16, document: NBTDocument) throws -> BetaMapData {
        guard let fields = document.tag.compoundValue?["data"]?.compoundValue,
            let source = fields["colors"]?.byteArrayValue
        else { throw WorldStorageError.malformed("map has no colors") }
        let width = Int(fields["width"]?.integerValue ?? 0)
        let height = Int(fields["height"]?.integerValue ?? 0)
        guard width > 0, width <= 128, height > 0, height <= 128, source.count == width * height else {
            throw WorldStorageError.malformed("invalid map dimensions or colors")
        }
        var colors = Array(repeating: UInt8(0), count: 16384)
        for y in 0..<height {
            for x in 0..<width {
                colors[x + (128 - width) / 2 + (y + (128 - height) / 2) * 128] = source[x + y * width]
            }
        }
        var map = BetaMapData(
            id: id, centerX: Int32(truncatingIfNeeded: fields["xCenter"]?.integerValue ?? 0),
            centerZ: Int32(truncatingIfNeeded: fields["zCenter"]?.integerValue ?? 0),
            dimension: Int8(truncatingIfNeeded: fields["dimension"]?.integerValue ?? 0),
            scale: UInt8(min(4, max(0, fields["scale"]?.integerValue ?? 0))), colors: colors)
        map.originalFields = fields
        return map
    }
}
