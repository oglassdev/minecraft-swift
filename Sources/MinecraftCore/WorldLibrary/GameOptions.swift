import Foundation

public enum GameKey: String, CaseIterable, Sendable {
    case forward, left, back, right, jump, sneak, drop, inventory, chat, fog

    public var defaultCode: Int {
        switch self {
        case .forward: 17
        case .left: 30
        case .back: 31
        case .right: 32
        case .jump: 57
        case .sneak: 42
        case .drop: 16
        case .inventory: 18
        case .chat: 20
        case .fog: 33
        }
    }
}

public struct GameOptions: Sendable {
    public var music: Float = 1
    public var sound: Float = 1
    public var mouseSensitivity: Float = 0.5
    public var invertY = false
    public var renderDistance = 0
    public var guiScale = 0
    public var viewBobbing = true
    public var anaglyph = false
    public var advancedOpenGL = false
    public var fpsLimit = 1
    public var difficulty = 2
    public var fancyGraphics = true
    public var smoothLighting = true
    public var skin = "Default"
    public var lastServer = ""
    public var keyBindings = Dictionary(uniqueKeysWithValues: GameKey.allCases.map { ($0, $0.defaultCode) })
    private var retainedLines: [String] = []

    public init() {}

    public var mouseRadiansPerPixel: Float {
        let base = mouseSensitivity * 0.6 + 0.2
        return Float(Double(base * base * base * 8) * 0.15 * .pi / 180)
    }

    public static func load(from url: URL) throws -> GameOptions {
        var options = GameOptions()
        guard FileManager.default.fileExists(atPath: url.path) else { return options }
        let source = try String(contentsOf: url, encoding: .utf8)
        for line in source.components(separatedBy: .newlines) {
            guard let colon = line.firstIndex(of: ":") else {
                if !line.isEmpty { options.retainedLines.append(line) }
                continue
            }
            let key = String(line[..<colon])
            let remaining = line[line.index(after: colon)...]
            let value = String(remaining.prefix(while: { $0 != ":" }))
            if !options.setOption(key, value: value) { options.retainedLines.append(line) }
        }
        return options
    }

    public func save(to url: URL) throws {
        var lines = [
            "music:\(music)", "sound:\(sound)", "invertYMouse:\(invertY)",
            "mouseSensitivity:\(mouseSensitivity)", "viewDistance:\(renderDistance)", "guiScale:\(guiScale)",
            "bobView:\(viewBobbing)", "anaglyph3d:\(anaglyph)", "advancedOpengl:\(advancedOpenGL)",
            "fpsLimit:\(fpsLimit)", "difficulty:\(difficulty)", "fancyGraphics:\(fancyGraphics)",
            "ao:\(smoothLighting)", "skin:\(skin)", "lastServer:\(lastServer)",
        ]
        lines += GameKey.allCases.map { "key_key.\($0.rawValue):\(keyBindings[$0] ?? $0.defaultCode)" }
        lines += retainedLines
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private mutating func setOption(_ key: String, value: String) -> Bool {
        if key.hasPrefix("key_key."), let binding = GameKey(rawValue: String(key.dropFirst(8))) {
            if let parsed = JavaText.parseLong(value), let code = Int32(exactly: parsed) {
                keyBindings[binding] = Int(code)
            }
            return true
        }
        func float() -> Float? {
            if value == "true" { return 1 }
            if value == "false" { return 0 }
            var text = JavaText.trim(value)
            if let suffix = text.last, "fFdD".contains(suffix) { text.removeLast() }
            return Float(text)
        }
        func int() -> Int? { JavaText.parseLong(value).flatMap(Int32.init(exactly:)).map(Int.init) }
        switch key {
        case "music": if let parsed = float() { music = parsed }
        case "sound": if let parsed = float() { sound = parsed }
        case "mouseSensitivity": if let parsed = float() { mouseSensitivity = parsed }
        case "invertYMouse": if !value.isEmpty { invertY = value == "true" }
        case "viewDistance": if let parsed = int() { renderDistance = parsed }
        case "guiScale": if let parsed = int() { guiScale = parsed }
        case "bobView": if !value.isEmpty { viewBobbing = value == "true" }
        case "anaglyph3d": if !value.isEmpty { anaglyph = value == "true" }
        case "advancedOpengl": if !value.isEmpty { advancedOpenGL = value == "true" }
        case "fpsLimit": if let parsed = int() { fpsLimit = parsed }
        case "difficulty": if let parsed = int() { difficulty = parsed }
        case "fancyGraphics": if !value.isEmpty { fancyGraphics = value == "true" }
        case "ao": if !value.isEmpty { smoothLighting = value == "true" }
        case "skin": if !value.isEmpty { skin = value }
        case "lastServer": if !value.isEmpty { lastServer = value }
        default: return false
        }
        return true
    }
}
