import Foundation

public enum NBTTagType: UInt8, Sendable {
    case end = 0
    case byte, short, int, long, float, double, byteArray, string, list, compound
}

public indirect enum NBTTag: Equatable, Sendable {
    case end
    case byte(Int8)
    case short(Int16)
    case int(Int32)
    case long(Int64)
    case float(Float)
    case double(Double)
    case byteArray([UInt8])
    case string(String)
    case list(NBTTagType, [NBTTag])
    case compound([String: NBTTag])

    public var type: NBTTagType {
        switch self {
        case .end: .end
        case .byte: .byte
        case .short: .short
        case .int: .int
        case .long: .long
        case .float: .float
        case .double: .double
        case .byteArray: .byteArray
        case .string: .string
        case .list: .list
        case .compound: .compound
        }
    }

    public var compoundValue: [String: NBTTag]? {
        if case .compound(let value) = self { value } else { nil }
    }

    public var listValue: [NBTTag]? {
        if case .list(_, let values) = self { values } else { nil }
    }

    public var byteArrayValue: [UInt8]? {
        if case .byteArray(let value) = self { value } else { nil }
    }

    public var stringValue: String? {
        if case .string(let value) = self { value } else { nil }
    }

    public var integerValue: Int64? {
        switch self {
        case .byte(let value): Int64(value)
        case .short(let value): Int64(value)
        case .int(let value): Int64(value)
        case .long(let value): value
        default: nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .float(let value): Double(value)
        case .double(let value): value
        default: integerValue.map(Double.init)
        }
    }
}

public struct NBTDocument: Equatable, Sendable {
    public var name: String
    public var tag: NBTTag

    public init(name: String = "", tag: NBTTag) {
        self.name = name
        self.tag = tag
    }
}

public enum WorldStorageError: Error, LocalizedError, Equatable {
    case malformed(String)
    case unsupportedTag(UInt8)
    case unsupportedCompression(UInt8)
    case compression(Int32)
    case chunkTooLarge

    public var errorDescription: String? {
        switch self {
        case .malformed(let detail): "Invalid Minecraft save: \(detail)"
        case .unsupportedTag(let type): "Unsupported Beta NBT tag type \(type)"
        case .unsupportedCompression(let type): "Unsupported region compression type \(type)"
        case .compression(let code): "Minecraft save compression failed with zlib code \(code)"
        case .chunkTooLarge: "Compressed chunk exceeds the McRegion sector limit"
        }
    }
}

public enum NBTCodec {
    public static func encode(_ document: NBTDocument) throws -> Data {
        var writer = NBTWriter()
        writer.bytes.append(document.tag.type.rawValue)
        if document.tag.type != .end {
            try writer.string(document.name)
            try writer.payload(document.tag, depth: 0)
        }
        return Data(writer.bytes)
    }

    public static func decode(_ data: Data) throws -> NBTDocument {
        guard data.count <= 64 * 1024 * 1024 else {
            throw WorldStorageError.malformed("NBT payload exceeds 64 MiB")
        }
        var reader = NBTReader(bytes: Array(data))
        let type = try reader.type()
        if type == .end {
            guard data.count == 1 else { throw WorldStorageError.malformed("trailing bytes after TAG_End") }
            return NBTDocument(tag: .end)
        }
        let name = try reader.string()
        let value = try reader.payload(type, depth: 0)
        guard reader.offset == reader.bytes.count else {
            throw WorldStorageError.malformed("trailing bytes after NBT root")
        }
        return NBTDocument(name: name, tag: value)
    }
}

private struct NBTReader {
    let bytes: [UInt8]
    var offset = 0

    mutating func integer<T: FixedWidthInteger>(_ type: T.Type = T.self) throws -> T {
        let count = MemoryLayout<T>.size
        guard count <= bytes.count - offset else { throw WorldStorageError.malformed("truncated NBT") }
        var result: UInt64 = 0
        for byte in bytes[offset..<offset + count] { result = result << 8 | UInt64(byte) }
        offset += count
        return T(truncatingIfNeeded: result)
    }

    mutating func type() throws -> NBTTagType {
        let id: UInt8 = try integer()
        guard let type = NBTTagType(rawValue: id) else { throw WorldStorageError.unsupportedTag(id) }
        return type
    }

    mutating func string() throws -> String {
        let count = Int(try integer(UInt16.self))
        guard count <= bytes.count - offset else { throw WorldStorageError.malformed("truncated NBT string") }
        let end = offset + count
        var units: [UInt16] = []
        while offset < end {
            let first = bytes[offset]
            offset += 1
            if first < 0x80 {
                units.append(UInt16(first))
            } else if first & 0xE0 == 0xC0 {
                guard offset < end, bytes[offset] & 0xC0 == 0x80 else {
                    throw WorldStorageError.malformed("invalid modified UTF-8 string")
                }
                units.append(UInt16(first & 31) << 6 | UInt16(bytes[offset] & 63))
                offset += 1
            } else if first & 0xF0 == 0xE0 {
                guard offset + 1 < end, bytes[offset] & 0xC0 == 0x80, bytes[offset + 1] & 0xC0 == 0x80 else {
                    throw WorldStorageError.malformed("invalid modified UTF-8 string")
                }
                units.append(
                    UInt16(first & 15) << 12 | UInt16(bytes[offset] & 63) << 6
                        | UInt16(bytes[offset + 1] & 63))
                offset += 2
            } else {
                throw WorldStorageError.malformed("invalid modified UTF-8 string")
            }
        }
        var index = 0
        while index < units.count {
            if (0xD800...0xDBFF).contains(units[index]) {
                guard index + 1 < units.count, (0xDC00...0xDFFF).contains(units[index + 1]) else {
                    throw WorldStorageError.malformed("unpaired UTF-16 surrogate")
                }
                index += 2
            } else {
                guard !(0xDC00...0xDFFF).contains(units[index]) else {
                    throw WorldStorageError.malformed("unpaired UTF-16 surrogate")
                }
                index += 1
            }
        }
        return String(decoding: units, as: UTF16.self)
    }

    mutating func payload(_ type: NBTTagType, depth: Int) throws -> NBTTag {
        guard depth < 512 else { throw WorldStorageError.malformed("NBT nesting exceeds 512 levels") }
        switch type {
        case .end: return .end
        case .byte: return .byte(try integer())
        case .short: return .short(try integer())
        case .int: return .int(try integer())
        case .long: return .long(try integer())
        case .float: return .float(Float(bitPattern: try integer()))
        case .double: return .double(Double(bitPattern: try integer()))
        case .byteArray:
            let count = Int(try integer(Int32.self))
            guard count >= 0, count <= bytes.count - offset else {
                throw WorldStorageError.malformed("invalid NBT byte-array length")
            }
            let result = Array(bytes[offset..<offset + count])
            offset += count
            return .byteArray(result)
        case .string: return .string(try string())
        case .list:
            let elementType = try self.type()
            let count = Int(try integer(Int32.self))
            guard count >= 0, count <= bytes.count - offset, count <= 1_048_576,
                elementType != .end || count == 0
            else {
                throw WorldStorageError.malformed("invalid NBT list length")
            }
            var values: [NBTTag] = []
            values.reserveCapacity(count)
            for _ in 0..<count { values.append(try payload(elementType, depth: depth + 1)) }
            return .list(elementType, values)
        case .compound:
            var values: [String: NBTTag] = [:]
            while true {
                let childType = try self.type()
                if childType == .end { return .compound(values) }
                let name = try string()
                values[name] = try payload(childType, depth: depth + 1)
            }
        }
    }
}

private struct NBTWriter {
    var bytes: [UInt8] = []

    mutating func integer<T: FixedWidthInteger>(_ value: T) {
        for shift in stride(from: T.bitWidth - 8, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: value >> shift))
        }
    }

    mutating func string(_ value: String) throws {
        var encoded: [UInt8] = []
        for unit in value.utf16 {
            if unit > 0 && unit < 0x80 {
                encoded.append(UInt8(unit))
            } else if unit < 0x800 {
                encoded.append(UInt8(0xC0 | unit >> 6))
                encoded.append(UInt8(0x80 | unit & 63))
            } else {
                encoded.append(UInt8(0xE0 | unit >> 12))
                encoded.append(UInt8(0x80 | unit >> 6 & 63))
                encoded.append(UInt8(0x80 | unit & 63))
            }
        }
        guard encoded.count <= Int(UInt16.max) else {
            throw WorldStorageError.malformed("NBT string exceeds 65535 bytes")
        }
        integer(UInt16(encoded.count))
        bytes += encoded
    }

    mutating func payload(_ value: NBTTag, depth: Int) throws {
        guard depth < 512 else { throw WorldStorageError.malformed("NBT nesting exceeds 512 levels") }
        switch value {
        case .end: break
        case .byte(let value): integer(value)
        case .short(let value): integer(value)
        case .int(let value): integer(value)
        case .long(let value): integer(value)
        case .float(let value): integer(value.bitPattern)
        case .double(let value): integer(value.bitPattern)
        case .byteArray(let values):
            guard values.count <= Int(Int32.max) else {
                throw WorldStorageError.malformed("NBT byte array is too large")
            }
            integer(Int32(values.count))
            bytes += values
        case .string(let value): try string(value)
        case .list(let type, let values):
            guard values.count <= Int(Int32.max), type != .end || values.isEmpty,
                values.allSatisfy({ $0.type == type })
            else {
                throw WorldStorageError.malformed("NBT list has incompatible element types")
            }
            bytes.append(type.rawValue)
            integer(Int32(values.count))
            for value in values { try payload(value, depth: depth + 1) }
        case .compound(let values):
            for name in values.keys.sorted() {
                guard let child = values[name], child.type != .end else {
                    throw WorldStorageError.malformed("named TAG_End in NBT compound")
                }
                bytes.append(child.type.rawValue)
                try string(name)
                try payload(child, depth: depth + 1)
            }
            bytes.append(0)
        }
    }
}
