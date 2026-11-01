import Foundation

struct McRegionFile {
    let url: URL
    private static let sectorSize = 4096
    private static let headerSize = 8192

    func readChunk(at position: ChunkPosition) throws -> NBTDocument? {
        try readChunkData(at: position).map { try NBTCodec.decode($0) }
    }

    func readChunkData(at position: ChunkPosition) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        guard size >= UInt64(Self.headerSize) else {
            throw WorldStorageError.malformed("truncated McRegion header")
        }
        try file.seek(toOffset: 0)
        let header = try readExactly(Self.headerSize, from: file)
        let location = readUInt32(header, at: slot(position) * 4)
        if location == 0 { return nil }
        let offset = Int(location >> 8)
        let sectors = Int(location & 255)
        guard offset >= 2, sectors > 0, UInt64(offset + sectors) * UInt64(Self.sectorSize) <= size else {
            throw WorldStorageError.malformed("McRegion chunk points outside the region file")
        }
        try file.seek(toOffset: UInt64(offset * Self.sectorSize))
        let prefix = try readExactly(5, from: file)
        let length = Int(readUInt32(prefix, at: 0))
        guard length > 1, length <= sectors * Self.sectorSize - 4 else {
            throw WorldStorageError.malformed("invalid McRegion chunk length")
        }
        let compression: NBTCompression
        switch prefix[4] {
        case 1: compression = .gzip
        case 2: compression = .zlib
        default: throw WorldStorageError.unsupportedCompression(prefix[4])
        }
        let compressed = try readExactly(length - 1, from: file)
        return try compression.decompress(compressed)
    }

    func writeChunk(_ document: NBTDocument, at position: ChunkPosition) throws {
        try writeChunkData(NBTCodec.encode(document), at: position)
    }

    func writeChunkData(_ data: Data, at position: ChunkPosition) throws {
        let compressed = try NBTCompression.zlib.compress(data)
        let needed = (compressed.count + 5 + Self.sectorSize - 1) / Self.sectorSize
        guard needed < 256 else { throw WorldStorageError.chunkTooLarge }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: Data(count: Self.headerSize))
            else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let file = try FileHandle(forUpdating: url)
        defer { try? file.close() }
        let length = try file.seekToEnd()
        guard length >= UInt64(Self.headerSize), length % UInt64(Self.sectorSize) == 0 else {
            throw WorldStorageError.malformed("invalid McRegion file size")
        }
        try file.seek(toOffset: 0)
        let header = try readExactly(Self.headerSize, from: file)
        let oldLocation = readUInt32(header, at: slot(position) * 4)
        var free = [Bool](repeating: true, count: Int(length / UInt64(Self.sectorSize)))
        free[0] = false
        free[1] = false
        for index in 0..<1024 {
            let location = readUInt32(header, at: index * 4)
            if location == 0 { continue }
            let start = Int(location >> 8)
            let count = Int(location & 255)
            guard start >= 2, count > 0, start + count <= free.count else {
                throw WorldStorageError.malformed("invalid McRegion sector allocation")
            }
            if index != slot(position) {
                for sector in start..<start + count {
                    guard free[sector] else {
                        throw WorldStorageError.malformed("overlapping McRegion chunks")
                    }
                    free[sector] = false
                }
            }
        }

        if oldLocation != 0 {
            let oldStart = Int(oldLocation >> 8)
            let oldCount = Int(oldLocation & 255)
            guard free[oldStart..<oldStart + oldCount].allSatisfy({ $0 }) else {
                throw WorldStorageError.malformed("overlapping McRegion chunks")
            }
        }
        var start = -1
        if oldLocation != 0, Int(oldLocation & 255) == needed {
            start = Int(oldLocation >> 8)
        } else {
            var run = 0
            for sector in 2..<free.count {
                run = free[sector] ? run + 1 : 0
                if run == needed {
                    start = sector - needed + 1
                    break
                }
            }
        }
        if start == -1 {
            start = free.count
            try file.seekToEnd()
            try file.write(contentsOf: Data(count: needed * Self.sectorSize))
        }
        guard start <= 0xFFFFFF else { throw WorldStorageError.chunkTooLarge }

        var payload = Data()
        appendUInt32(UInt32(compressed.count + 1), to: &payload)
        payload.append(2)
        payload.append(compressed)
        payload.append(Data(count: needed * Self.sectorSize - payload.count))
        try file.seek(toOffset: UInt64(start * Self.sectorSize))
        try file.write(contentsOf: payload)
        var location = Data()
        appendUInt32(UInt32(start << 8 | needed), to: &location)
        try file.seek(toOffset: UInt64(slot(position) * 4))
        try file.write(contentsOf: location)
        var timestamp = Data()
        appendUInt32(UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970)), to: &timestamp)
        try file.seek(toOffset: UInt64(4096 + slot(position) * 4))
        try file.write(contentsOf: timestamp)
        try file.synchronize()
    }

    private func slot(_ position: ChunkPosition) -> Int { (position.x & 31) + (position.z & 31) * 32 }

    private func readExactly(_ count: Int, from file: FileHandle) throws -> Data {
        var data = Data()
        while data.count < count {
            guard let next = try file.read(upToCount: count - data.count), !next.isEmpty else {
                throw WorldStorageError.malformed("truncated McRegion payload")
            }
            data.append(next)
        }
        return data
    }

    private func readUInt32(_ data: Data, at index: Int) -> UInt32 {
        UInt32(data[index]) << 24 | UInt32(data[index + 1]) << 16 | UInt32(data[index + 2]) << 8
            | UInt32(data[index + 3])
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: [
            UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value),
        ])
    }
}
