import CZlib
import Foundation

public enum TexturePackError: Error, LocalizedError {
    case malformedArchive(String)
    case unsafePath(String)
    case unsupportedFeature(String)
    case checksumMismatch(String)
    case exceedsLimits

    public var errorDescription: String? {
        switch self {
        case .malformedArchive(let message): "Invalid texture pack ZIP: \(message)"
        case .unsafePath(let name): "Texture pack contains an unsafe path: \(name)"
        case .unsupportedFeature(let feature): "Texture pack ZIP uses an unsupported feature: \(feature)"
        case .checksumMismatch(let name): "Texture pack data failed its CRC check: \(name)"
        case .exceedsLimits: "Texture pack exceeds the supported archive or resource size."
        }
    }
}

struct ClassicZIP {
    struct Entry {
        let name: String
        let nameBytes: [UInt8]
        let flags: UInt16
        let method: UInt16
        let crc: UInt32
        let compressedSize: Int
        let size: Int
        let offset: Int
        var isDirectory: Bool { name.hasSuffix("/") }
    }

    static let maximumResourceSize = 64 * 1024 * 1024
    static let maximumTotalSize = 256 * 1024 * 1024
    let entries: [Entry]
    let fingerprint: UInt64
    private let bytes: [UInt8]
    private let directoryOffset: Int

    init(url: URL) throws {
        let attributes = try url.resourceValues(forKeys: [
            .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else {
            throw TexturePackError.unsafePath(url.lastPathComponent)
        }
        guard let size = attributes.fileSize, size <= Self.maximumTotalSize else {
            throw TexturePackError.exceedsLimits
        }
        bytes = Array(try Data(contentsOf: url))
        guard bytes.count <= Self.maximumTotalSize else { throw TexturePackError.exceedsLimits }
        fingerprint = bytes.reduce(UInt64(0xcbf2_9ce4_8422_2325)) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
        let reader = ZIPBytes(bytes: bytes)
        guard bytes.count >= 22 else { throw TexturePackError.malformedArchive("missing end record") }
        var end: Int?
        for index in stride(from: bytes.count - 22, through: max(0, bytes.count - 22 - 65535), by: -1) {
            if try reader.uint32(at: index) == 0x0605_4b50,
                index + 22 + Int(try reader.uint16(at: index + 20)) == bytes.count
            {
                end = index
                break
            }
        }
        guard let end else { throw TexturePackError.malformedArchive("missing end record") }
        guard try reader.uint16(at: end + 4) == 0, try reader.uint16(at: end + 6) == 0,
            try reader.uint16(at: end + 8) == reader.uint16(at: end + 10)
        else {
            throw TexturePackError.unsupportedFeature("multi-disk archives")
        }
        let count = Int(try reader.uint16(at: end + 10))
        let centralSize = Int(try reader.uint32(at: end + 12))
        directoryOffset = Int(try reader.uint32(at: end + 16))
        guard count != 65535, centralSize != Int(UInt32.max), directoryOffset != Int(UInt32.max) else {
            throw TexturePackError.unsupportedFeature("ZIP64")
        }
        guard directoryOffset <= end, centralSize <= end - directoryOffset else {
            throw TexturePackError.malformedArchive("central directory is outside the archive")
        }
        let centralEnd = directoryOffset + centralSize
        var cursor = directoryOffset
        var parsed: [Entry] = []
        var names = Set<String>()
        for _ in 0..<count {
            guard cursor <= centralEnd - 46, try reader.uint32(at: cursor) == 0x0201_4b50 else {
                throw TexturePackError.malformedArchive("invalid central directory entry")
            }
            let version = try reader.uint16(at: cursor + 6)
            let flags = try reader.uint16(at: cursor + 8)
            let method = try reader.uint16(at: cursor + 10)
            let crc = try reader.uint32(at: cursor + 16)
            let compressedSize = Int(try reader.uint32(at: cursor + 20))
            let size = Int(try reader.uint32(at: cursor + 24))
            let nameSize = Int(try reader.uint16(at: cursor + 28))
            let extraSize = Int(try reader.uint16(at: cursor + 30))
            let commentSize = Int(try reader.uint16(at: cursor + 32))
            let offset = Int(try reader.uint32(at: cursor + 42))
            guard version <= 20, compressedSize != Int(UInt32.max), size != Int(UInt32.max),
                offset != Int(UInt32.max)
            else { throw TexturePackError.unsupportedFeature("ZIP64 or newer ZIP version") }
            guard flags & 0x2041 == 0 else { throw TexturePackError.unsupportedFeature("encrypted entries") }
            guard method == 0 || method == 8 else {
                throw TexturePackError.unsupportedFeature("compression method \(method)")
            }
            guard try reader.uint16(at: cursor + 34) == 0 else {
                throw TexturePackError.unsupportedFeature("multi-disk entries")
            }
            let unixMode = try reader.uint32(at: cursor + 38) >> 16
            guard unixMode & 0xF000 != 0xA000 else { throw TexturePackError.unsafePath("symbolic link") }
            let length = 46 + nameSize + extraSize + commentSize
            guard length <= centralEnd - cursor else {
                throw TexturePackError.malformedArchive("truncated central directory")
            }
            let rawName = Array(bytes[cursor + 46..<cursor + 46 + nameSize])
            let name = try Self.decodeName(rawName, utf8: flags & 0x0800 != 0)
            try Self.validatePath(name)
            guard names.insert(name).inserted else {
                throw TexturePackError.malformedArchive("duplicate entry \(name)")
            }
            parsed.append(
                Entry(
                    name: name, nameBytes: rawName, flags: flags, method: method, crc: crc,
                    compressedSize: compressedSize, size: size, offset: offset))
            cursor += length
        }
        guard cursor == centralEnd else {
            throw TexturePackError.malformedArchive("central directory size mismatch")
        }
        entries = parsed
    }

    func data(for entry: Entry) throws -> Data {
        guard entry.size <= Self.maximumResourceSize else { throw TexturePackError.exceedsLimits }
        let reader = ZIPBytes(bytes: bytes)
        let start = entry.offset
        guard start <= directoryOffset - 30, try reader.uint32(at: start) == 0x0403_4b50 else {
            throw TexturePackError.malformedArchive("invalid local header for \(entry.name)")
        }
        guard try reader.uint16(at: start + 6) == entry.flags,
            try reader.uint16(at: start + 8) == entry.method
        else {
            throw TexturePackError.malformedArchive("local header mismatch for \(entry.name)")
        }
        let nameSize = Int(try reader.uint16(at: start + 26))
        let extraSize = Int(try reader.uint16(at: start + 28))
        let payload = start + 30 + nameSize + extraSize
        guard payload <= directoryOffset, entry.compressedSize <= directoryOffset - payload,
            Array(bytes[start + 30..<start + 30 + nameSize]) == entry.nameBytes
        else {
            throw TexturePackError.malformedArchive("entry data is outside the archive")
        }
        if entry.flags & 8 == 0 {
            guard try reader.uint32(at: start + 14) == entry.crc,
                try reader.uint32(at: start + 18) == UInt32(entry.compressedSize),
                try reader.uint32(at: start + 22) == UInt32(entry.size)
            else {
                throw TexturePackError.malformedArchive("local sizes or CRC mismatch for \(entry.name)")
            }
        }
        let compressed = Data(bytes[payload..<payload + entry.compressedSize])
        let result: Data
        if entry.method == 0 {
            guard entry.compressedSize == entry.size else {
                throw TexturePackError.malformedArchive("stored size mismatch")
            }
            result = compressed
        } else {
            result = try Self.inflate(compressed, size: entry.size)
        }
        guard Self.crc32(result) == entry.crc else { throw TexturePackError.checksumMismatch(entry.name) }
        return result
    }

    static func crc32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { buffer in
            UInt32(
                truncatingIfNeeded: CZlib.crc32(
                    0, buffer.baseAddress?.assumingMemoryBound(to: Bytef.self), uInt(buffer.count)))
        }
    }

    private static func inflate(_ data: Data, size: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -15, zlibVersion(), Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw TexturePackError.malformedArchive("could not initialize DEFLATE")
        }
        defer { inflateEnd(&stream) }
        var output = [UInt8](repeating: 0, count: max(1, size))
        let status = data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer<Bytef>(
                mutating: input.baseAddress?.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(input.count)
            return output.withUnsafeMutableBytes { buffer in
                stream.next_out = buffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                stream.avail_out = uInt(buffer.count)
                return CZlib.inflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END, stream.total_out == uLong(size), stream.total_in == uLong(data.count)
        else {
            throw TexturePackError.malformedArchive("invalid DEFLATE stream or expanded size")
        }
        return Data(output.prefix(size))
    }

    private static func validatePath(_ name: String) throws {
        let parts = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\0"),
            !parts.contains(".."), !parts.contains("."), !parts.dropLast().contains(""),
            parts.first?.contains(":") != true
        else { throw TexturePackError.unsafePath(name) }
    }

    private static func decodeName(_ bytes: [UInt8], utf8: Bool) throws -> String {
        if let text = String(bytes: bytes, encoding: .utf8) { return text }
        guard !utf8 else { throw TexturePackError.malformedArchive("invalid UTF-8 filename") }
        return String(
            String.UnicodeScalarView(
                bytes.map { byte in
                    byte < 128 ? Unicode.Scalar(byte) : cp437[Int(byte) - 128]
                }))
    }

    private static let cp437 = Array(
        "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ "
            .unicodeScalars)
}

private struct ZIPBytes {
    let bytes: [UInt8]
    func uint16(at index: Int) throws -> UInt16 {
        guard index >= 0, index <= bytes.count - 2 else {
            throw TexturePackError.malformedArchive("truncated header")
        }
        return UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8
    }
    func uint32(at index: Int) throws -> UInt32 {
        guard index >= 0, index <= bytes.count - 4 else {
            throw TexturePackError.malformedArchive("truncated header")
        }
        return UInt32(bytes[index]) | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2]) << 16 | UInt32(
            bytes[index + 3]) << 24
    }
}
