import CZlib
import Foundation

enum NBTCompression {
    case gzip, zlib

    var windowBits: Int32 { self == .gzip ? 31 : 15 }

    func compress(_ data: Data) throws -> Data {
        var stream = z_stream()
        let status = deflateInit2_(
            &stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, windowBits, 8,
            Z_DEFAULT_STRATEGY, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw WorldStorageError.compression(status) }
        defer { deflateEnd(&stream) }
        return try process(data, stream: &stream, compressing: true)
    }

    func decompress(_ data: Data) throws -> Data {
        var stream = z_stream()
        let status = inflateInit2_(&stream, windowBits, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw WorldStorageError.compression(status) }
        defer { inflateEnd(&stream) }
        return try process(data, stream: &stream, compressing: false)
    }

    private func process(_ data: Data, stream: inout z_stream, compressing: Bool) throws -> Data {
        guard data.count <= Int(UInt32.max) else {
            throw WorldStorageError.malformed("compressed payload is too large")
        }
        return try data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer<Bytef>(
                mutating: input.baseAddress?.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(input.count)
            var result = Data()
            var buffer = [UInt8](repeating: 0, count: 16384)
            while true {
                let status = buffer.withUnsafeMutableBytes { output -> Int32 in
                    stream.next_out = output.baseAddress?.assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = uInt(output.count)
                    return compressing ? deflate(&stream, Z_FINISH) : inflate(&stream, Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw WorldStorageError.compression(status)
                }
                let produced = buffer.count - Int(stream.avail_out)
                guard result.count + produced <= 64 * 1024 * 1024 else {
                    throw WorldStorageError.malformed("NBT payload exceeds 64 MiB")
                }
                result.append(contentsOf: buffer.prefix(produced))
                if status == Z_STREAM_END { return result }
                if !compressing && stream.avail_in == 0 && produced == 0 {
                    throw WorldStorageError.malformed("truncated compressed NBT")
                }
            }
        }
    }
}
