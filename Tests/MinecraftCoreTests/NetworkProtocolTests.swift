import Foundation
import MinecraftCore
import Testing

@Suite("Beta protocol 14")
struct NetworkProtocolTests {
    // Serialized by the original 1.7.3 client packet classes, including Java string codecs.
    private static let originalPackets = [
        "00",
        "010102030400030041d83dde00010203040506070801",
        "0200030041d83dde00",
        "0300030041d83dde00",
        "040102030405060708",
        "0501020304030403040304",
        "06010203040102030401020304",
        "07010203040102030401",
        "080304",
        "0901",
        "0a01",
        "0bc004000000000000c004000000000000c004000000000000c00400000000000001",
        "0c3fc000003fc0000001",
        "0dc004000000000000c004000000000000c004000000000000c0040000000000003fc000003fc0000001",
        "0e0401020304040102030404",
        "0f010203040401020304040001020003",
        "100304",
        "110102030404010203040401020304",
        "120102030404",
        "130102030404",
        "140102030400030041d83dde0001020304010203040102030401010304",
        "15010203040304040304010203040102030401020304010101",
        "160102030401020304",
        "17010203040401020304010203040102030401020304030403040304",
        "180102030401010203040102030401020304010100012102034201020304633fc000008400030041d83dde00c50000000100000002000000037f",
        "190102030400030041d83dde0001020304010203040102030401020304",
        "1b3fc000003fc000003fc000003fc000000101",
        "1c01020304030403040304",
        "1d01020304",
        "1e01020304",
        "1f01020304010101",
        "20010203040101",
        "21010203040101010101",
        "22010203040102030401020304010203040101",
        "260102030401",
        "270102030401020304",
        "280102030400012102034201020304633fc000008400030041d83dde00c50000000100000002000000037f",
        "32010203040102030401",
        "33fffffff00000000000200101010000001c789c6360646266616563e7e0e4e2e6e1e5e3171014120600054600bf",
        "340102030401020304000112340303",
        "350102030404010203040404",
        "36010203040304010203040404",
        "3cc004000000000000c004000000000000c0040000000000003fc0000000000000",
        "3d0102030401020304040102030401020304",
        "4604",
        "470102030404010203040102030401020304",
        "640404000941c080eda0bdedb88004",
        "6504",
        "66040304040203010001020003",
        "670403040001020003",
        "68040000",
        "690403040304",
        "6a04020301",
        "820102030403040102030400010041000100420001004300010044",
        "83020302030103",
        "c80102030404",
        "ff00030041d83dde00",
    ]

    @Test func originalClientPacketTableHasExactWireParity() throws {
        var ids = Set<UInt8>()
        for hex in Self.originalPackets {
            let bytes = Self.data(hex)
            var codec = BetaPacketCodec()
            let packets = try codec.append(bytes)
            let packet = try #require(packets.first)
            #expect(packets.count == 1)
            #expect(packet.id == bytes.first)
            ids.insert(packet.id)
            let encoded = try BetaPacketCodec.encode(packet)
            if packet.id != 51 {
                #expect(encoded == bytes, "Packet \(packet.id) differs from original Java serialization")
            } else {
                var compressedRoundTrip = BetaPacketCodec()
                #expect(try compressedRoundTrip.append(encoded) == packets)
            }
        }
        #expect(ids.count == 57)
    }

    @Test func arbitraryTCPFragmentationPreservesPacketBoundaries() throws {
        let wire = Self.originalPackets.reduce(into: Data()) { $0.append(Self.data($1)) }
        var codec = BetaPacketCodec()
        var decoded: [BetaPacket] = []
        for byte in wire { decoded += try codec.append(Data([byte])) }
        #expect(decoded.count == 57)
        #expect(decoded.map(\.id) == Self.originalPackets.map { Self.data($0).first! })
        #expect(try codec.append(Data()).isEmpty)
    }

    @Test func javaUTF16AndModifiedUTF8AreDistinct() throws {
        let handshake = BetaPacket.handshake("A😀")
        #expect(try BetaPacketCodec.encode(handshake) == Self.data("0200030041d83dde00"))
        var codec = BetaPacketCodec()
        #expect(
            try codec.append(Self.data("640404000941c080eda0bdedb88004")) == [
                .openWindow(id: 4, type: 4, title: "A\0😀", slots: 4)
            ])
    }

    @Test func inventoryNullAndItemMetadataPreserveShortsAndCounts() throws {
        let packet = BetaPacket.windowItems(
            window: 0, items: [nil, BetaSlot(itemID: 5, count: 2, damage: 3)])
        let wire = Self.data("68000002ffff0005020003")
        #expect(try BetaPacketCodec.encode(packet) == wire)
        var codec = BetaPacketCodec()
        #expect(try codec.append(wire) == [packet])
        let metadata = BetaPacket.metadata(
            entityID: 1,
            values: [BetaMetadataEntry(index: 5, value: .item(BetaSlot(itemID: 1, count: 2, damage: 3)))])
        #expect(try BetaPacketCodec.encode(metadata) == Self.data("2800000001a500010200037f"))
    }

    @Test func compressedMapChunksApplyAcrossNegativeChunkBoundaries() throws {
        let raw =
            [UInt8](repeating: 1, count: 8) + [UInt8](repeating: 0x21, count: 4)
            + [UInt8](repeating: 0x43, count: 4) + [UInt8](repeating: 0x65, count: 4)
        let chunk = try BetaMapChunk(x: -1, y: 10, z: 15, sizeX: 2, sizeY: 2, sizeZ: 2, data: raw)
        var decoder = BetaPacketCodec()
        let decoded = try decoder.append(BetaPacketCodec.encode(.mapChunk(chunk)))
        guard case .mapChunk(let decodedChunk) = try #require(decoded.first) else {
            Issue.record("No map chunk")
            return
        }
        var world = BlockWorld()
        decodedChunk.apply(to: &world)
        #expect(world.chunks.count == 4)
        #expect(world.lightingRevision == 0)
        #expect(world.state(at: BlockPosition(-1, 10, 15)) == BlockState(.stone, metadata: 1))
        #expect(world.state(at: BlockPosition(0, 11, 16)) == BlockState(.stone, metadata: 2))
        let target = try #require(world.chunks[ChunkPosition(-1, 0)])
        let climate = BetaClimateSource(seed: world.seed).region(x: -16, z: 0)[255]
        #expect(target.temperatures[255] == climate.temperature)
        #expect(target.humidities[255] == climate.humidity)
        let index = Chunk.index(x: 15, y: 11, z: 15)
        #expect(target.blockLight[index] == 4)
        #expect(target.skyLight[index] == 6)
        var nether = BlockWorld(dimension: -1)
        decodedChunk.apply(to: &nether)
        #expect(nether.climate(atX: -1, z: 15).temperature == 1)
        #expect(nether.climate(atX: -1, z: 15).humidity == 0)
    }

    @Test func malformedFramesFailWithoutUnboundedAllocation() throws {
        var unknown = BetaPacketCodec()
        #expect(throws: BetaProtocolError.self) { try unknown.append(Data([254])) }
        var negativeString = BetaPacketCodec()
        #expect(throws: BetaProtocolError.self) { try negativeString.append(Data([2, 255, 255])) }
        #expect(throws: BetaProtocolError.self) {
            try BetaPacketCodec.encode(.handshake(String(repeating: "A", count: 33)))
        }
        var limited = BetaPacketCodec(maximumBufferedBytes: 4)
        #expect(throws: BetaProtocolError.self) { try limited.append(Data(repeating: 0, count: 5)) }
    }

    private static func data(_ hex: String) -> Data {
        let chars = Array(hex)
        return Data(
            stride(from: 0, to: chars.count, by: 2).map { UInt8(String(chars[$0...$0 + 1]), radix: 16)! })
    }
}
