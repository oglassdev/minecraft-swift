import Foundation
import Testing

@testable import MinecraftCore

struct WorldLibraryTests {
    @Test func seedTextMatchesJavaLongParsingAndUTF16Hashing() {
        // Captured from Java Long.parseLong/String.hashCode, as called by Beta GuiCreateWorld.
        let cases: [(String, Int64)] = [
            ("", 42), ("0", 42), ("+0", 42), ("-0", 42), ("000", 42), ("123", 123), ("-123", -123),
            ("+123", 123),
            ("9223372036854775807", Int64.max), ("-9223372036854775808", Int64.min),
            ("9223372036854775808", -1_773_151_197), ("-9223372036854775809", 1_304_595_159),
            (" 123", 1_002_002), ("123 ", 1_509_422), (" ", 32), ("\t", 9), ("hello", 99_162_322),
            ("Glacier", 1_772_835_215), ("404", 404), ("😀", 1_772_899), ("A😀B", 56_896_350),
            ("١٢٣", 123), ("１２３", 123), ("²", 178), ("𝟙𝟚𝟛", -1_454_511_217),
        ]
        for (text, expected) in cases {
            #expect(WorldCatalog.seed(from: text, randomSeed: { 42 }) == expected)
        }
    }

    @Test func catalogReadsOriginalMetadataAndBackupWithoutRequiringPlayer() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = WorldCatalog(directory: directory)
        try writeLevel(
            in: directory.appendingPathComponent("Older"),
            fields: [
                "RandomSeed": .long(-123), "Time": .long(6000), "LastPlayed": .long(1000),
                "SizeOnDisk": .long(4096), "LevelName": .string("Old world"), "version": .int(0),
            ])
        let latest = directory.appendingPathComponent("Latest")
        try writeLevel(
            in: latest, filename: "level.dat_old",
            fields: [
                "RandomSeed": .long(456), "Time": .long(12000), "LastPlayed": .long(2000),
                "LevelName": .string(""), "version": .int(19132),
            ])
        try Data([1, 2, 3]).write(to: latest.appendingPathComponent("level.dat"))
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Unfinished"), withIntermediateDirectories: true)
        try writeLevel(
            in: directory.appendingPathComponent(".trash"), fields: ["LevelName": .string("Hidden")])
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("Linked"), withDestinationURL: latest)
        let worlds = try catalog.worlds()
        #expect(worlds.map(\.name) == ["Latest", "Old world"])
        #expect(worlds.map(\.seed) == [456, -123])
        #expect(worlds.map(\.time) == [12000, 6000])
        #expect(worlds.map(\.requiresConversion) == [false, true])
        #expect(worlds.map(\.isNew) == [false, false])
        #expect(worlds[0].lastPlayed == Date(timeIntervalSince1970: 2))
        #expect(worlds[1].sizeOnDisk == 4096)
        #expect(try Data(contentsOf: latest.appendingPathComponent("level.dat")) == Data([1, 2, 3]))
    }

    @Test func createAllocatesUniqueSafeDirectoriesWithoutInventingSavedPlayer() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = WorldCatalog(directory: directory)
        let first = try catalog.create(name: "  A/B:C?  ", seedText: "Glacier")
        let marker = first.directory.appendingPathComponent("untouched")
        try Data([42]).write(to: marker)
        let second = try catalog.create(name: "  A/B:C?  ", seedText: "404")
        #expect(first.directory.lastPathComponent == "A_B_C_")
        #expect(second.directory.lastPathComponent == "A_B_C_-")
        #expect(first.name == "  A/B:C?  " && first.seed == 1_772_835_215 && first.isNew)
        #expect(second.seed == 404 && second.formatVersion == 19132)
        #expect(try FileManager.default.contentsOfDirectory(atPath: second.directory.path).isEmpty)
        #expect(try Data(contentsOf: marker) == Data([42]))
        #expect(try catalog.worlds().isEmpty)
        for name in ["", "..", ".", ".trash", String(repeating: "😀", count: 100)] {
            let world = try catalog.create(name: name, seedText: "1")
            #expect(
                world.directory.deletingLastPathComponent().standardizedFileURL
                    == directory.standardizedFileURL)
            #expect(world.directory.lastPathComponent.utf8.count <= 240)
            #expect(world.directory != directory)
        }
    }

    @Test func optionsReadWriteMatchesBetaSettingsAndRetainsUnknownFields() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("options.txt")
        var defaults = try GameOptions.load(from: url)
        #expect(defaults.music == 1 && defaults.sound == 1 && defaults.mouseSensitivity == 0.5)
        #expect(
            defaults.difficulty == 2 && defaults.renderDistance == 0 && defaults.fpsLimit == 1
                && defaults.guiScale == 0)
        #expect(
            defaults.viewBobbing && defaults.fancyGraphics && defaults.smoothLighting && !defaults.invertY)
        #expect(
            !defaults.anaglyph && !defaults.advancedOpenGL && defaults.skin == "Default"
                && defaults.lastServer.isEmpty)
        for key in GameKey.allCases { #expect(defaults.keyBindings[key] == key.defaultCode) }
        let source = """
            music:true
            sound:false
            mouseSensitivity: 0.75f
            invertYMouse:true
            viewDistance:3
            guiScale:2
            bobView:false
            anaglyph3d:true
            advancedOpengl:true
            fpsLimit:2
            difficulty:3
            fancyGraphics:false
            ao:false
            skin:Custom
            lastServer:example.org:25565
            key_key.forward:200
            key_key.inventory:23
            music:bad
            viewDistance:2147483648
            key_key.jump:bad
            futureOption:retain:this
            # retained comment
            """
        try source.write(to: url, atomically: true, encoding: .utf8)
        var loaded = try GameOptions.load(from: url)
        #expect(loaded.music == 1 && loaded.sound == 0 && loaded.mouseSensitivity == 0.75)
        #expect(loaded.invertY && loaded.renderDistance == 3 && loaded.guiScale == 2 && !loaded.viewBobbing)
        #expect(loaded.anaglyph && loaded.advancedOpenGL && loaded.fpsLimit == 2 && loaded.difficulty == 3)
        #expect(!loaded.fancyGraphics && !loaded.smoothLighting && loaded.skin == "Custom")
        #expect(loaded.lastServer == "example.org")
        #expect(
            loaded.keyBindings[.forward] == 200 && loaded.keyBindings[.inventory] == 23
                && loaded.keyBindings[.jump] == 57)
        loaded.sound = 0.25
        try loaded.save(to: url)
        let saved = try String(contentsOf: url, encoding: .utf8)
        #expect(saved.contains("futureOption:retain:this\n") && saved.contains("# retained comment\n"))
        let restored = try GameOptions.load(from: url)
        #expect(
            restored.sound == 0.25 && restored.mouseSensitivity == loaded.mouseSensitivity
                && restored.keyBindings == loaded.keyBindings)
        for (sensitivity, bits): (Float, UInt32) in [
            (0, 0x392f_b0cb), (0.5, 0x3b2b_92a6), (0.75, 0x3bbc_7909), (1, 0x3c2f_b0cb),
        ] {
            defaults.mouseSensitivity = sensitivity
            #expect(defaults.mouseRadiansPerPixel.bitPattern == bits)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MinecraftLibrary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeLevel(in directory: URL, filename: String = "level.dat", fields: [String: NBTTag])
        throws
    {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = NBTDocument(tag: .compound(["Data": .compound(fields)]))
        try NBTCompression.gzip.compress(NBTCodec.encode(document)).write(
            to: directory.appendingPathComponent(filename))
    }
}
