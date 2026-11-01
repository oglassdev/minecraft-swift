enum StatisticsMD5 {
    private static let constants: [UInt32] = [
        0xd76a_a478, 0xe8c7_b756, 0x2420_70db, 0xc1bd_ceee, 0xf57c_0faf, 0x4787_c62a, 0xa830_4613,
        0xfd46_9501, 0x6980_98d8, 0x8b44_f7af, 0xffff_5bb1, 0x895c_d7be, 0x6b90_1122, 0xfd98_7193,
        0xa679_438e, 0x49b4_0821, 0xf61e_2562, 0xc040_b340, 0x265e_5a51, 0xe9b6_c7aa, 0xd62f_105d,
        0x0244_1453, 0xd8a1_e681, 0xe7d3_fbc8, 0x21e1_cde6, 0xc337_07d6, 0xf4d5_0d87, 0x455a_14ed,
        0xa9e3_e905, 0xfcef_a3f8, 0x676f_02d9, 0x8d2a_4c8a, 0xfffa_3942, 0x8771_f681, 0x6d9d_6122,
        0xfde5_380c, 0xa4be_ea44, 0x4bde_cfa9, 0xf6bb_4b60, 0xbebf_bc70, 0x289b_7ec6, 0xeaa1_27fa,
        0xd4ef_3085, 0x0488_1d05, 0xd9d4_d039, 0xe6db_99e5, 0x1fa2_7cf8, 0xc4ac_5665, 0xf429_2244,
        0x432a_ff97, 0xab94_23a7, 0xfc93_a039, 0x655b_59c3, 0x8f0c_cc92, 0xffef_f47d, 0x8584_5dd1,
        0x6fa8_7e4f, 0xfe2c_e6e0, 0xa301_4314, 0x4e08_11a1, 0xf753_7e82, 0xbd3a_f235, 0x2ad7_d2bb,
        0xeb86_d391,
    ]
    private static let shifts = [
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
    ]

    static func hex(_ data: [UInt8]) -> String {
        var bytes = data
        let length = UInt64(bytes.count) &* 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 { bytes.append(0) }
        for shift in stride(from: 0, through: 56, by: 8) {
            bytes.append(UInt8(truncatingIfNeeded: length >> shift))
        }
        var state: [UInt32] = [0x6745_2301, 0xefcd_ab89, 0x98ba_dcfe, 0x1032_5476]
        for block in stride(from: 0, to: bytes.count, by: 64) {
            let words: [UInt32] = (0..<16).map { index in
                let offset = block + index * 4
                return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
                    | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
            }
            var a = state[0]
            var b = state[1]
            var c = state[2]
            var d = state[3]
            for round in 0..<64 {
                let function: UInt32
                let index: Int
                switch round {
                case 0..<16:
                    function = (b & c) | (~b & d)
                    index = round
                case 16..<32:
                    function = (d & b) | (~d & c)
                    index = (5 * round + 1) % 16
                case 32..<48:
                    function = b ^ c ^ d
                    index = (3 * round + 5) % 16
                default:
                    function = c ^ (b | ~d)
                    index = (7 * round) % 16
                }
                let next = a &+ function &+ constants[round] &+ words[index]
                let rotated = (next << shifts[round]) | (next >> (32 - shifts[round]))
                a = d
                d = c
                c = b
                b = b &+ rotated
            }
            state[0] &+= a
            state[1] &+= b
            state[2] &+= c
            state[3] &+= d
        }
        let alphabet = Array("0123456789abcdef")
        var digest: [Character] = []
        digest.reserveCapacity(32)
        for word in state {
            for shift in stride(from: 0, to: 32, by: 8) {
                let byte = UInt8(truncatingIfNeeded: word >> shift)
                digest.append(alphabet[Int(byte >> 4)])
                digest.append(alphabet[Int(byte & 15)])
            }
        }
        let hex = String(digest.drop(while: { $0 == "0" }))
        return hex.isEmpty ? "0" : hex
    }
}
