import Foundation

public struct StatisticsStorage: Sendable {
    public let directory: URL
    public let username: String

    public init(directory: URL, username: String = "Player") {
        self.directory = directory
        self.username = username
    }

    public func load() throws -> PlayerStatistics {
        try validateUsername()
        try migrateUsernameCase()
        let baseline = try read(unsent: false)
        let pending = try read(unsent: true)
        return PlayerStatistics(baseline: baseline, pending: pending)
    }

    public func save(_ statistics: PlayerStatistics) throws {
        try validateUsername()
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = file(unsent: true, extension: "dat")
        let temporary = file(unsent: true, extension: "tmp")
        let backup = file(unsent: true, extension: "old")
        let json = StatisticsFileCodec.encode(values: statistics.pendingChanges, username: username)
        try Data(json.utf8).write(to: temporary)
        if manager.fileExists(atPath: backup.path) { try manager.removeItem(at: backup) }
        if manager.fileExists(atPath: target.path) { try manager.moveItem(at: target, to: backup) }
        try manager.moveItem(at: temporary, to: target)
    }

    private func read(unsent: Bool) throws -> [Int: Int] {
        for suffix in ["dat", "old", "tmp"] {
            let candidate = file(unsent: unsent, extension: suffix)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try StatisticsFileCodec.decode(String(contentsOf: candidate, encoding: .utf8))
            }
        }
        return [:]
    }

    private func file(unsent: Bool, extension suffix: String) -> URL {
        directory.appendingPathComponent(
            "stats_" + username.lowercased() + (unsent ? "_unsent." : ".") + suffix)
    }

    private func migrateUsernameCase() throws {
        guard username != username.lowercased() else { return }
        let manager = FileManager.default
        for unsent in [false, true] {
            for suffix in ["dat", "old", "tmp"] {
                let old = directory.appendingPathComponent(
                    "stats_" + username + (unsent ? "_unsent." : ".") + suffix)
                let target = file(unsent: unsent, extension: suffix)
                if manager.fileExists(atPath: old.path) && !manager.fileExists(atPath: target.path) {
                    try manager.moveItem(at: old, to: target)
                }
            }
        }
    }

    private func validateUsername() throws {
        guard !username.isEmpty, !username.contains("/"), !username.contains("\\"), !username.contains("\0")
        else { throw StatisticsFileError.invalidUsername }
    }
}
