import Foundation
import Testing

@testable import MinecraftCore

struct TexturePackTests {
    @Test func classicZIPMetadataAndOverridesMatchOriginalTexturePackCustom() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packs = root.appendingPathComponent("texturepacks")
        let cache = root.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: packs, withIntermediateDirectories: true)
        let archive = packs.appendingPathComponent("Classic.ZIP")
        let zip = try #require(Data(base64Encoded: Self.javaZIP))
        let png = try #require(Data(base64Encoded: Self.png))
        try zip.write(to: archive)
        try FileManager.default.createSymbolicLink(
            at: packs.appendingPathComponent("Linked.zip"), withDestinationURL: archive)
        let catalog = TexturePackCatalog(directory: packs)
        let descriptors = try catalog.packs()
        #expect(descriptors.map(\.name) == ["Default", "Classic.ZIP"])
        #expect(descriptors[0].isDefault && !descriptors[1].isDefault)
        #expect(descriptors[1].descriptionLine1 == "ABCDEFGHIJKLMNOPQRSTUVWXYZ12345678")
        #expect(descriptors[1].descriptionLine2 == "Second description")
        #expect(descriptors[1].iconData == png)
        #expect(try catalog.select(name: "Default", to: cache) == nil)
        #expect(try catalog.select(name: "Missing.zip", to: cache) == nil)
        #expect(try catalog.select(name: "../Classic.ZIP", to: cache) == nil)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        let selected = try #require(try catalog.select(name: "Classic.ZIP", to: cache))
        for name in ["terrain.png", "gui/items.png", "pack.png", "textures/é.png", "folder/terrain.png"] {
            #expect(try Data(contentsOf: selected.appendingPathComponent(name)) == png)
        }
        #expect(try Data(contentsOf: selected.appendingPathComponent("empty.png")).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: selected.appendingPathComponent("readme.md").path))
        // Missing paths stay absent so the renderer can use the default pack for that file.
        #expect(
            !FileManager.default.fileExists(atPath: selected.appendingPathComponent("gui/icons.png").path))
        #expect(try catalog.select(name: "Classic.ZIP", to: cache) == selected)
        try Data([1, 2, 3]).write(to: selected.appendingPathComponent("terrain.png"))
        let repaired = try #require(try catalog.select(name: "Classic.ZIP", to: cache))
        #expect(repaired != selected)
        #expect(try Data(contentsOf: repaired.appendingPathComponent("terrain.png")) == png)
        #expect(try Data(contentsOf: selected.appendingPathComponent("terrain.png")) == Data([1, 2, 3]))
        #expect(try Data(contentsOf: archive) == zip)
    }

    @Test func storedCP437ZIPAndCorruptOrUnsafeEntriesAreHandledWithoutEscapingCache() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packs = root.appendingPathComponent("texturepacks")
        let cache = root.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: packs, withIntermediateDirectories: true)
        let archive = packs.appendingPathComponent("Authored.zip")
        let catalog = TexturePackCatalog(directory: packs)
        try storedZIP(name: [0x82] + Array(".png".utf8)).write(to: archive)
        let selected = try #require(try catalog.select(name: "Authored.zip", to: cache))
        #expect(
            try Data(contentsOf: selected.appendingPathComponent("é.png")) == Data(base64Encoded: Self.png))
        for name in ["../outside.png", "/outside.png", "gui/../outside.png", "gui\\outside.png"] {
            try storedZIP(name: Array(name.utf8)).write(to: archive)
            #expect(throws: TexturePackError.self) { try catalog.select(name: "Authored.zip", to: cache) }
        }
        try storedZIP(name: Array("terrain.png".utf8), crc: 0).write(to: archive)
        #expect(throws: TexturePackError.self) { try catalog.select(name: "Authored.zip", to: cache) }
        try storedZIP(name: Array("terrain.png".utf8), offset: UInt32.max - 1).write(to: archive)
        #expect(throws: TexturePackError.self) { try catalog.select(name: "Authored.zip", to: cache) }
        try storedZIP(name: Array("terrain.png".utf8), size: UInt32.max - 1).write(to: archive)
        #expect(throws: TexturePackError.self) { try catalog.select(name: "Authored.zip", to: cache) }
        try storedZIP(name: Array("terrain.png".utf8), attributes: 0xA1FF_0000).write(to: archive)
        #expect(throws: TexturePackError.self) { try catalog.select(name: "Authored.zip", to: cache) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("outside.png").path))
        #expect(!FileManager.default.fileExists(atPath: cache.appendingPathComponent("outside.png").path))
        let remaining = try FileManager.default.contentsOfDirectory(atPath: cache.path)
        #expect(!remaining.contains { $0.hasPrefix(".texturepack-") })
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MinecraftTextures-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func storedZIP(
        name: [UInt8], crc: UInt32 = 0xABF3_6810, size: UInt32? = nil,
        offset: UInt32 = 0, attributes: UInt32 = 0
    ) throws -> Data {
        let png = try #require(Data(base64Encoded: Self.png))
        var result = Data()
        func u16(_ value: UInt16) {
            result.append(UInt8(truncatingIfNeeded: value))
            result.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func u32(_ value: UInt32) {
            u16(UInt16(truncatingIfNeeded: value))
            u16(UInt16(truncatingIfNeeded: value >> 16))
        }
        u32(0x0403_4B50)
        u16(20)
        u16(0)
        u16(0)
        u16(0)
        u16(0)
        u32(crc)
        u32(UInt32(png.count))
        u32(size ?? UInt32(png.count))
        u16(UInt16(name.count))
        u16(0)
        result.append(contentsOf: name)
        result.append(png)
        let directoryOffset = UInt32(result.count)
        u32(0x0201_4B50)
        u16(0x0314)
        u16(20)
        u16(0)
        u16(0)
        u16(0)
        u16(0)
        u32(crc)
        u32(UInt32(png.count))
        u32(size ?? UInt32(png.count))
        u16(UInt16(name.count))
        u16(0)
        u16(0)
        u16(0)
        u16(0)
        u32(attributes)
        u32(offset)
        result.append(contentsOf: name)
        let directorySize = UInt32(result.count) - directoryOffset
        u32(0x0605_4B50)
        u16(0)
        u16(0)
        u16(1)
        u16(1)
        u32(directorySize)
        u32(directoryOffset)
        u16(0)
        return result
    }

    // Authored 1×1 RGBA pixel and Java ZipOutputStream output, verified with original vp/TexturePackCustom.
    private static let png =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOQaDnxHwAEgAJkmEb3gwAAAABJRU5ErkJggg=="
    private static let javaZIP =
        "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"
}
