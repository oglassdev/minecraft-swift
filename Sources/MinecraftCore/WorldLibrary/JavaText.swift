enum JavaText {
    static func trim(_ text: String) -> String {
        let units = Array(text.utf16)
        let start = units.firstIndex(where: { $0 > 32 }) ?? units.endIndex
        let end = units.lastIndex(where: { $0 > 32 }).map { $0 + 1 } ?? start
        return String(decoding: units[start..<end], as: UTF16.self)
    }

    static func hashCode(_ text: String) -> Int32 {
        text.utf16.reduce(Int32(0)) { ($0 &* 31) &+ Int32($1) }
    }

    static func parseLong(_ text: String) -> Int64? {
        var units = ArraySlice(text.utf16)
        guard let first = units.first else { return nil }
        let negative = first == 45
        if negative || first == 43 { units.removeFirst() }
        guard !units.isEmpty else { return nil }
        let limit = negative ? Int64.min : -Int64.max
        let multiplicationLimit = limit / 10
        var value: Int64 = 0
        for unit in units {
            guard let scalar = Unicode.Scalar(unit), scalar.properties.generalCategory == .decimalNumber,
                let number = scalar.properties.numericValue, number >= 0, number <= 9,
                value >= multiplicationLimit
            else { return nil }
            let digit = Int64(number)
            value *= 10
            guard value >= limit + digit else { return nil }
            value -= digit
        }
        return negative ? value : -value
    }
}
