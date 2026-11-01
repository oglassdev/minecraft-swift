import MinecraftCore
import SwiftUI

struct GameOptionsPanel: View {
    @ObservedObject var session: GameSession
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var screen = Screen.options
    @State private var capturing: GameKey?
    private enum Screen { case options, video, controls }

    var body: some View {
        BetaGUI(option: session.options.guiScale) { resolution in
            ZStack(alignment: .topLeading) {
                if session.worldMenuOpen { DirtMenuBackground() } else { BetaScreenShade() }
                let title =
                    screen == .video ? "Video Settings" : (screen == .controls ? "Controls" : "Options")
                BetaText(title).offset(
                    x: CGFloat(resolution.width / 2 - BetaBitmapFont.shared.width(title) / 2), y: 20)
                switch screen {
                case .options: options(resolution)
                case .video: video(resolution)
                case .controls: controls(resolution)
                }
                BetaButton(title: "Done", session: session) {
                    session.saveOptions()
                    if screen == .options {
                        close()
                    } else {
                        screen = .options
                        capturing = nil
                    }
                }.offset(x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 6 + 168))
            }
        }.onDisappear { session.saveOptions() }
    }

    private func options(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            BetaSlider(
                title: percentage("Music", session.options.music), value: $session.options.music,
                changed: session.applyOptions
            ).offset(x: CGFloat(r.width / 2 - 155), y: CGFloat(r.height / 6))
            BetaSlider(
                title: percentage("Sound", session.options.sound), value: $session.options.sound,
                changed: session.applyOptions
            ).offset(x: CGFloat(r.width / 2 + 5), y: CGFloat(r.height / 6))
            BetaButton(title: "Invert Mouse: \(onOff(session.options.invertY))", width: 150, session: session)
            {
                session.options.invertY.toggle()
                session.applyOptions()
            }.offset(x: CGFloat(r.width / 2 - 155), y: CGFloat(r.height / 6 + 24))
            BetaSlider(
                title: sensitivity, value: $session.options.mouseSensitivity, changed: session.applyOptions
            ).offset(x: CGFloat(r.width / 2 + 5), y: CGFloat(r.height / 6 + 24))
            BetaButton(
                title: "Difficulty: \(["Peaceful","Easy","Normal","Hard"][session.options.difficulty])",
                width: 150, session: session
            ) {
                session.options.difficulty = (session.options.difficulty + 1) % 4
                session.applyOptions()
            }.offset(x: CGFloat(r.width / 2 - 155), y: CGFloat(r.height / 6 + 48))
            BetaButton(title: "Video Settings...", session: session) { screen = .video }.offset(
                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 6 + 108))
            BetaButton(title: "Controls...", session: session) { screen = .controls }.offset(
                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 6 + 132))
        }
    }

    private func video(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            videoButton("Graphics: \(session.options.fancyGraphics ? "Fancy" : "Fast")", index: 0, r: r) {
                session.options.fancyGraphics.toggle()
            }
            videoButton(
                "Render Distance: \(["Far","Normal","Short","Tiny"][session.options.renderDistance])",
                index: 1, r: r
            ) { session.options.renderDistance = (session.options.renderDistance + 1) % 4 }
            videoButton("Smooth Lighting: \(onOff(session.options.smoothLighting))", index: 2, r: r) {
                session.options.smoothLighting.toggle()
            }
            videoButton(
                "Performance: \(["Max FPS","Balanced","Power saver"][session.options.fpsLimit])", index: 3,
                r: r
            ) { session.options.fpsLimit = (session.options.fpsLimit + 1) % 3 }
            videoButton("3D Anaglyph: \(onOff(session.options.anaglyph))", index: 4, r: r, enabled: false) {}
            videoButton("View Bobbing: \(onOff(session.options.viewBobbing))", index: 5, r: r) {
                session.options.viewBobbing.toggle()
            }
            videoButton(
                "GUI Scale: \(["Auto","Small","Normal","Large"][min(3,max(0,session.options.guiScale))])",
                index: 6, r: r
            ) { session.options.guiScale = (session.options.guiScale + 1) % 4 }
            videoButton(
                "Advanced OpenGL: \(onOff(session.options.advancedOpenGL))", index: 7, r: r, enabled: false
            ) {}
        }
    }

    private func videoButton(
        _ title: String, index: Int, r: BetaGUIResolution, enabled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        BetaButton(title: title, width: 150, enabled: enabled, session: session) {
            action()
            session.applyOptions()
        }
        .offset(x: CGFloat(r.width / 2 - 155 + index % 2 * 160), y: CGFloat(r.height / 6 + index / 2 * 24))
    }

    private func controls(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(GameKey.allCases.enumerated()), id: \.element) { index, key in
                let x = r.width / 2 - 155 + index % 2 * 160
                let y = r.height / 6 + index / 2 * 24
                let name = keyName(session.options.keyBindings[key] ?? key.defaultCode)
                BetaButton(title: capturing == key ? "> \(name) <" : name, width: 70, session: session) {
                    capturing = key
                }
                .offset(x: CGFloat(x), y: CGFloat(y))
                BetaText(keyTitle(key)).offset(x: CGFloat(x + 76), y: CGFloat(y + 7))
            }
            #if os(macOS)
                if let capturing {
                    BetaKeyCapture { code in
                        session.options.keyBindings[capturing] = code
                        self.capturing = nil
                        session.saveOptions()
                    }.frame(width: 1, height: 1)
                }
            #endif
        }
    }

    private func percentage(_ title: String, _ value: Float) -> String {
        "\(title): \(value == 0 ? "OFF" : "\(Int(value * 100))%")"
    }
    private var sensitivity: String {
        "Sensitivity: \(session.options.mouseSensitivity == 0 ? "*yawn*" : (session.options.mouseSensitivity == 1 ? "HYPERSPEED!!!" : "\(Int(session.options.mouseSensitivity * 200))%"))"
    }
    private func onOff(_ value: Bool) -> String { value ? "ON" : "OFF" }
    private func close() { if let onClose { onClose() } else { dismiss() } }
    private func keyTitle(_ key: GameKey) -> String {
        switch key {
        case .forward: "Forward"
        case .left: "Left"
        case .back: "Back"
        case .right: "Right"
        case .jump: "Jump"
        case .sneak: "Sneak"
        case .drop: "Drop"
        case .inventory: "Inventory"
        case .chat: "Chat"
        case .fog: "Toggle Fog"
        }
    }
    private func keyName(_ code: Int) -> String {
        let names: [Int: String] = [
            0: "NONE", 1: "ESCAPE", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9",
            11: "0", 12: "MINUS", 13: "EQUALS", 14: "BACK", 15: "TAB", 16: "Q", 17: "W", 18: "E", 19: "R",
            20: "T", 21: "Y", 22: "U", 23: "I", 24: "O", 25: "P", 26: "LBRACKET", 27: "RBRACKET",
            28: "RETURN", 29: "LCONTROL", 30: "A", 31: "S", 32: "D", 33: "F", 34: "G", 35: "H", 36: "J",
            37: "K", 38: "L", 39: "SEMICOLON", 40: "APOSTROPHE", 41: "GRAVE", 42: "LSHIFT", 43: "BACKSLASH",
            44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M", 51: "COMMA", 52: "PERIOD",
            53: "SLASH", 54: "RSHIFT", 56: "LMENU", 57: "SPACE", 184: "RMENU", 157: "RCONTROL", 200: "UP",
            203: "LEFT", 205: "RIGHT", 208: "DOWN",
        ]
        if (59...68).contains(code) { return "F\(code - 58)" }
        return names[code] ?? "KEY \(code)"
    }
}
