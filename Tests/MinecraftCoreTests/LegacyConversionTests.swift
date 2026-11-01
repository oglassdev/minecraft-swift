import Foundation
import Testing

@testable import MinecraftCore

struct LegacyConversionTests {
    @Test func convertsOriginalAlphaChunksInBothDimensionsWithoutChangingNBTOrSources() throws {
        let directory = try temporaryWorld()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalLevel = try writeLevel(in: directory)
        let overworld = try writeChunk(Self.overworld, in: directory, x: -33, z: 65)
        let netherDirectory = directory.appendingPathComponent("DIM-1")
        let nether = try writeChunk(Self.nether, in: netherDirectory, x: 2, z: -3)
        let result = try LegacyWorldConverter(directory: directory).convert()
        #expect(result.convertedChunks == 2 && result.skippedChunks == 0 && result.regionFiles == 2)
        #expect(result.backupURL?.lastPathComponent == "level.dat_before_conversion")
        #expect(try Data(contentsOf: #require(result.backupURL)) == originalLevel)
        let saved = try NBTCodec.decode(
            NBTCompression.gzip.decompress(Data(contentsOf: directory.appendingPathComponent("level.dat"))))
        #expect(saved.name == "Original root")
        #expect(saved.tag.compoundValue?["CustomRoot"] == .string("preserve"))
        #expect(saved.tag.compoundValue?["Data"]?.compoundValue?["CustomLevel"] == .string("keep all fields"))
        #expect(saved.tag.compoundValue?["Data"]?.compoundValue?["version"] == .int(19132))
        #expect(saved.tag.compoundValue?["Data"]?.compoundValue?["Player"] == nil)
        for (source, folder, position, fixture) in [
            (overworld, directory, ChunkPosition(-33, 65), Self.overworld),
            (nether, netherDirectory, ChunkPosition(2, -3), Self.nether),
        ] {
            let expected = try #require(Data(base64Encoded: fixture))
            #expect(try Data(contentsOf: source) == expected)
            let file = McRegionFile(
                url: folder.appendingPathComponent("region/r.\(position.x >> 5).\(position.z >> 5).mcr"))
            #expect(try file.readChunkData(at: position) == NBTCompression.gzip.decompress(expected))
            let chunk = try #require(
                try WorldStorage(directory: directory, dimension: folder == directory ? 0 : -1).loadChunk(
                    at: position))
            #expect(chunk.blockIDs[321] == 250 && chunk.isTerrainPopulated)
        }
        let upgradedLevel = try Data(contentsOf: directory.appendingPathComponent("level.dat"))
        #expect(try LegacyWorldConverter(directory: directory).convert().totalChunks == 0)
        #expect(try Data(contentsOf: directory.appendingPathComponent("level.dat")) == upgradedLevel)
        let storage = WorldStorage(directory: directory)
        let level = try #require(try storage.loadLevel())
        try storage.saveLevel(level)
        try storage.saveLevel(level)
        #expect(try Data(contentsOf: #require(result.backupURL)) == originalLevel)
    }

    @Test func failedConversionKeepsOldVersionAndBackupsThenResumesWithoutOverwritingRegions() throws {
        let directory = try temporaryWorld()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalLevel = try writeLevel(in: directory)
        let olderBackup = Data("older backup remains".utf8)
        let oldURL = directory.appendingPathComponent("level.dat_old")
        try olderBackup.write(to: oldURL)
        _ = try writeChunk(Self.overworld, in: directory, x: -33, z: 65)
        let netherDirectory = directory.appendingPathComponent("DIM-1")
        let damaged = try writeChunk(Self.nether, in: netherDirectory, x: 2, z: -3)
        try Data([0, 1, 2]).write(to: damaged)
        #expect(throws: LegacyConversionError.self) {
            try LegacyWorldConverter(directory: directory).convert()
        }
        #expect(try Data(contentsOf: directory.appendingPathComponent("level.dat")) == originalLevel)
        #expect(try Data(contentsOf: oldURL) == olderBackup)
        let position = ChunkPosition(-33, 65)
        let region = McRegionFile(url: directory.appendingPathComponent("region/r.-2.2.mcr"))
        let alreadyConverted = try #require(try region.readChunkData(at: position))
        _ = try writeChunk(Self.nether, in: netherDirectory, x: 2, z: -3)
        let result = try LegacyWorldConverter(directory: directory).convert()
        #expect(result.convertedChunks == 1 && result.skippedChunks == 1)
        #expect(result.backupURL != oldURL)
        #expect(try Data(contentsOf: #require(result.backupURL)) == originalLevel)
        #expect(try Data(contentsOf: oldURL) == olderBackup)
        #expect(try region.readChunkData(at: position) == alreadyConverted)
        #expect(try Data(contentsOf: damaged) == Data(base64Encoded: Self.nether))
    }

    private func temporaryWorld() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MinecraftLegacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeLevel(in directory: URL) throws -> Data {
        let document = NBTDocument(
            name: "Original root",
            tag: .compound([
                "CustomRoot": .string("preserve"),
                "Data": .compound([
                    "version": .int(0), "RandomSeed": .long(123), "LevelName": .string("Legacy fixture"),
                    "CustomLevel": .string("keep all fields"), "SpawnY": .int(70),
                ]),
            ]))
        let data = try NBTCompression.gzip.compress(NBTCodec.encode(document))
        try data.write(to: directory.appendingPathComponent("level.dat"))
        return data
    }

    private func writeChunk(_ base64: String, in directory: URL, x: Int, z: Int) throws -> URL {
        let folder = directory.appendingPathComponent(String(x & 63, radix: 36)).appendingPathComponent(
            String(z & 63, radix: 36))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("c.\(String(x,radix:36)).\(String(z,radix:36)).dat")
        try #require(Data(base64Encoded: base64)).write(to: file)
        return file
    }

    // Original Beta Java NBT gzip output; the original Java converter produces identical chunk bytes.
    private static let overworld =
        "H4sIAAAAAAAA/+3czU4TURgG4K9SmWlhwY2YuHWnoImLkjQKFzBhTmDSOoe0p2Dd6J16H25qC4bEtSZl8Ty78/N9ea/gHUeM4+Uk3aX5QQy/TfMyIt5VcXg6z1ez7eFH8I9+7TsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP9DFfXn2XrSXd+UiLf7TgMAAAAAAAAAAAAAAAAAAADErg5g9DHtygDOm9uIwb7j7N0wxpNmWS5v26akx6vXb6oYn87z1UxrAgAAAAAAAAAAAAAAAAAAADwjVQzfN6VRBQAAAAAAAAAAAAAAAAAAAADPw0EMv07zcrPZ/Kzj+LKf9fm+P7tZ9bMY5bu0uM+LeTuIk4u0WDRdP823q3lTUjsYxfFFN08f+tKVLi3H212DKo7OVsuSv5yuS1o+bP++qeNF18b4PLdtancjMYr6r7E6Ds9z6e5SVNPc9SUttlEeFz38W8do1V/dNP11ah+31dNtltL11xF1HP1J/SnnEieLVLZvr56yx2/0lrQtVUIBAA=="
    private static let nether =
        "H4sIAAAAAAAA/+3cwWoTURQG4JM2JpO0gi8iuHUnqYKLFIK2DzB0LsmQOBMyN9W60ecWJCaNm64V0sX3rS733nP4n+AfR4zjxTTdp9V59L/P2m632/0exmCyau+WXcTP4B/9OnUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP6HYRSflw/Ter7IEe9OnQYAAAAAAAAAAAAAAAAAAACIQx3A6GM6lAFcl+uI3qnjnFw/xtOyy7frqszpePXm7TDGk1V7t9SaAAAAAAAAAAAAAAAAAAAAAM/IMPrvy1yqAgAAAAAAAAAAAAAAAAAAAIDn4Tz632Zttz+dFXF52yyb9mtztdg2yxg0KS/SphevbtJmU9bNrF1vV2VOVW8Ulzf1Kn1ocp3r1I33471hXFxtu9x+mTzk1D2u/rEr4qyuYnzdVlWqDiMxiuLJWBGD6zbX9ymGs7ZuctrscxwXPf57iNG2uVuUzTxVx23FbJ8l1808ooiLv5E/tW2Ol5uU92+vj8HjD2pFtRJPQgEA"
}
