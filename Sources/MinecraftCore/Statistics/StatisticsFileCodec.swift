import CoreFoundation
import Foundation

public struct StatisticChange: Equatable, Sendable {
    public let id: Int
    public let value: Int
    public init(id: Int, value: Int) {
        self.id = id
        self.value = value
    }
}

public enum StatisticsFileError: Error, Equatable {
    case invalidFormat
    case checksumMismatch
    case invalidUsername
}

public enum StatisticsFileCodec {
    public static func encode(_ changes: [StatisticChange], username: String? = "Player") -> String {
        let changes = changes.filter { StatisticRegistry.definition(for: $0.id) != nil }
        var output = "{\r\n"
        if let username {
            output += "  \"user\":{\r\n    \"name\":" + quoted(username)
            output += ",\r\n    \"sessionid\":\"local\"\r\n  },\r\n"
        }
        output += "  \"stats-change\":["
        output += changes.map { "\r\n    {\"\($0.id)\":\($0.value)}" }.joined(separator: ",")
        output += "\r\n  ],\r\n  \"checksum\":\"" + checksum(changes) + "\"\r\n}"
        return output
    }

    public static func encode(values: [Int: Int], username: String? = "Player") -> String {
        encode(
            values.keys.sorted().map { StatisticChange(id: $0, value: values[$0] ?? 0) }, username: username)
    }

    public static func decode(_ json: String) throws -> [Int: Int] {
        guard let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = object["stats-change"] as? [[String: Any]],
            let storedChecksum = object["checksum"] as? String
        else { throw StatisticsFileError.invalidFormat }
        var changes: [StatisticChange] = []
        var values: [Int: Int] = [:]
        for entry in entries {
            guard entry.count == 1, let (key, rawValue) = entry.first, let id = Int(key),
                let number = rawValue as? NSNumber,
                CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue == Double(number.int64Value),
                number.int64Value >= Int64(Int32.min), number.int64Value <= Int64(Int32.max)
            else { throw StatisticsFileError.invalidFormat }
            if StatisticRegistry.definition(for: id) == nil { continue }
            let value = number.intValue
            changes.append(StatisticChange(id: id, value: value))
            values[id] = value
        }
        guard checksum(changes) == storedChecksum else { throw StatisticsFileError.checksumMismatch }
        return values
    }

    public static func checksum(_ changes: [StatisticChange]) -> String {
        let content = changes.compactMap { change -> String? in
            guard let definition = StatisticRegistry.definition(for: change.id) else { return nil }
            return definition.checksumKey + ",\(change.value),"
        }.joined()
        return StatisticsMD5.hex(Array(("local" + content).utf8))
    }

    private static func quoted(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 34: result += "\\\""
            case 92: result += "\\\\"
            case 0..<32: result += String(format: "\\u%04x", scalar.value)
            default: result.append(Character(scalar))
            }
        }
        return result + "\""
    }
}
