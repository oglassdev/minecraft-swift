import ImageIO
import MinecraftCore
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct WorldLibraryPanel: View {
    @ObservedObject var session: GameSession
    @State private var screen = Screen.title
    @State private var selected: URL?
    @State private var name = "New World"
    @State private var seed = ""
    @State private var nameFocused = true
    @State private var seedFocused = false
    @State private var splash = Self.randomSplash()
    private enum Screen { case title, worlds, create, rename, delete, options, multiplayer, packs }

    var body: some View {
        if screen == .options {
            GameOptionsPanel(session: session, onClose: { screen = .title })
        } else if screen == .multiplayer {
            MultiplayerPanel(session: session, onClose: { screen = .title })
        } else {
            BetaGUI(option: session.options.guiScale) { resolution in
                ZStack(alignment: .topLeading) {
                    DirtMenuBackground()
                    switch screen {
                    case .title: title(resolution)
                    case .worlds: worlds(resolution)
                    case .create: create(resolution)
                    case .rename: rename(resolution)
                    case .delete: delete(resolution)
                    case .packs: packs(resolution)
                    default: EmptyView()
                    }
                }
            }
        }
    }

    private func title(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            BetaSprite(name: "title/mclogo.png", rect: CGRect(x: 0, y: 0, width: 155, height: 44)).offset(
                x: CGFloat(r.width / 2 - 137), y: 30)
            BetaSprite(name: "title/mclogo.png", rect: CGRect(x: 0, y: 45, width: 155, height: 44)).offset(
                x: CGFloat(r.width / 2 + 18), y: 30)
            TimelineView(.animation) { time in
                let pulse =
                    1.8
                    - abs(
                        sin(
                            time.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * Double.pi * 2
                        ) * 0.1)
                let scale = pulse * 100 / Double(BetaBitmapFont.shared.width(splash) + 32)
                BetaText(splash, color: 0xFFFF00).offset(
                    x: -CGFloat(BetaBitmapFont.shared.width(splash)) / 2, y: -8
                )
                .scaleEffect(scale, anchor: .topLeading).rotationEffect(.degrees(-20), anchor: .topLeading)
                .offset(x: CGFloat(r.width / 2 + 90), y: 70)
            }
            BetaText("Minecraft Beta 1.7.3", color: 0x505050).offset(x: 2, y: 2)
            let copyright = "Copyright Mojang AB. Do not distribute."
            BetaText(copyright).offset(
                x: CGFloat(r.width - BetaBitmapFont.shared.width(copyright) - 2), y: CGFloat(r.height - 10))
            BetaButton(title: "Singleplayer", session: session) {
                session.refreshWorldList()
                screen = .worlds
            }.offset(x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 48))
            BetaButton(title: "Multiplayer", session: session) { screen = .multiplayer }.offset(
                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 72))
            BetaButton(title: "Mods and Texture Packs", session: session) {
                session.refreshTexturePacks()
                screen = .packs
            }.offset(x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 96))
            BetaButton(title: "Options...", width: 98, session: session) { screen = .options }.offset(
                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 132))
            BetaButton(title: "Quit Game", width: 98, session: session) { quit() }.offset(
                x: CGFloat(r.width / 2 + 2), y: CGFloat(r.height / 4 + 132))
        }
    }

    private func worlds(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            DirtMenuBackground(brightness: 32).frame(height: CGFloat(r.height - 96)).offset(y: 32)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(session.availableWorlds) { world in
                        ZStack(alignment: .topLeading) {
                            if selected == world.directory {
                                Rectangle().fill(Color(white: 128.0 / 255)).frame(width: 220, height: 36)
                                Rectangle().fill(.black).frame(width: 218, height: 34).offset(x: 1, y: 1)
                            }
                            BetaText(world.name).offset(x: 4, y: 3)
                            BetaText(worldDetail(world), color: 0x808080).offset(x: 4, y: 14)
                            if world.requiresConversion {
                                BetaText("Must be converted!", color: 0x808080).offset(x: 4, y: 24)
                            }
                        }.frame(width: 220, height: 36, alignment: .topLeading).contentShape(Rectangle())
                            .onTapGesture(count: 2) { session.openWorld(world) }
                            .simultaneousGesture(TapGesture().onEnded { selected = world.directory })
                    }
                }.padding(.top, 2).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden).frame(height: CGFloat(max(0, r.height - 96))).offset(y: 32)
            centered("Select World", width: r.width, y: 20)
            BetaButton(
                title: "Play Selected World", width: 150, enabled: selectedWorld != nil, session: session
            ) { if let world = selectedWorld { session.openWorld(world) } }.offset(
                x: CGFloat(r.width / 2 - 154), y: CGFloat(r.height - 52))
            BetaButton(title: "Create New World", width: 150, session: session) {
                name = "New World"
                seed = ""
                nameFocused = true
                screen = .create
            }.offset(x: CGFloat(r.width / 2 + 4), y: CGFloat(r.height - 52))
            BetaButton(title: "Rename", width: 70, enabled: selectedWorld != nil, session: session) {
                name = selectedWorld?.name ?? ""
                nameFocused = true
                screen = .rename
            }.offset(x: CGFloat(r.width / 2 - 154), y: CGFloat(r.height - 28))
            BetaButton(title: "Delete", width: 70, enabled: selectedWorld != nil, session: session) {
                screen = .delete
            }.offset(x: CGFloat(r.width / 2 - 74), y: CGFloat(r.height - 28))
            BetaButton(title: "Cancel", width: 150, session: session) { screen = .title }.offset(
                x: CGFloat(r.width / 2 + 4), y: CGFloat(r.height - 28))
        }
    }

    private func create(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            centered("Create New World", width: r.width, y: r.height / 4 - 40)
            BetaText("World Name", color: 0xA0A0A0).offset(x: CGFloat(r.width / 2 - 100), y: 47)
            BetaTextField(
                text: $name, focused: $nameFocused, submitted: createWorld,
                tabbed: {
                    nameFocused = false
                    seedFocused = true
                }
            ).offset(x: CGFloat(r.width / 2 - 100), y: 60)
            BetaText("Will be saved in: \(folderName)", color: 0xA0A0A0).offset(
                x: CGFloat(r.width / 2 - 100), y: 85)
            BetaText("Seed for the World Generator", color: 0xA0A0A0).offset(
                x: CGFloat(r.width / 2 - 100), y: 104)
            BetaTextField(
                text: $seed, focused: $seedFocused, maximumLength: 0, submitted: createWorld,
                tabbed: {
                    seedFocused = false
                    nameFocused = true
                }
            ).offset(x: CGFloat(r.width / 2 - 100), y: 116)
            BetaText("Leave blank for a random seed", color: 0xA0A0A0).offset(
                x: CGFloat(r.width / 2 - 100), y: 140)
            BetaButton(
                title: "Create New World", enabled: !name.isEmpty, session: session, action: createWorld
            ).offset(x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 108))
            BetaButton(title: "Cancel", session: session) { screen = .worlds }.offset(
                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 132))
        }
    }

    private func rename(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            centered("Rename World", width: r.width, y: r.height / 4 - 40)
            BetaText("World Name", color: 0xA0A0A0).offset(x: CGFloat(r.width / 2 - 100), y: 47)
            BetaTextField(text: $name, focused: $nameFocused, submitted: renameWorld).offset(
                x: CGFloat(r.width / 2 - 100), y: 60)
            BetaButton(
                title: "Rename", enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                session: session, action: renameWorld
            ).offset(x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 108))
            BetaButton(title: "Cancel", session: session) { screen = .worlds }.offset(
                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 132))
        }
    }

    private func delete(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            centered("Are you sure you want to delete this world?", width: r.width, y: 70)
            centered(
                "'\(selectedWorld?.name ?? "")' will be lost forever! (A long time!)", width: r.width, y: 90)
            BetaButton(title: "Delete", width: 150, session: session) {
                if let world = selectedWorld { session.deleteWorld(world) }
                selected = nil
                screen = .worlds
            }.offset(x: CGFloat(r.width / 2 - 155), y: CGFloat(r.height / 6 + 96))
            BetaButton(title: "Cancel", width: 150, session: session) { screen = .worlds }.offset(
                x: CGFloat(r.width / 2 + 5), y: CGFloat(r.height / 6 + 96))
        }
    }

    private func packs(_ r: BetaGUIResolution) -> some View {
        ZStack(alignment: .topLeading) {
            centered("Select Texture Pack", width: r.width, y: 16)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(session.texturePacks) { pack in
                        ZStack(alignment: .topLeading) {
                            if session.options.skin == pack.name {
                                Rectangle().fill(Color(white: 128.0 / 255)).frame(width: 220, height: 36)
                                Rectangle().fill(.black).frame(width: 218, height: 34).offset(x: 1, y: 1)
                            }
                            if let data = pack.iconData,
                                let source = CGImageSourceCreateWithData(data as CFData, nil),
                                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
                            {
                                Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
                                    width: 32, height: 32
                                ).offset(x: 2, y: 2)
                            } else if let image = VanillaUISprites.image("gui/unknown_pack.png") {
                                Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
                                    width: 32, height: 32
                                ).offset(x: 2, y: 2)
                            }
                            BetaText(pack.name).offset(x: 36, y: 3)
                            BetaText(pack.descriptionLine1, color: 0x808080).offset(x: 36, y: 14)
                            BetaText(pack.descriptionLine2, color: 0x808080).offset(x: 36, y: 24)
                        }.frame(width: 220, height: 36, alignment: .topLeading).contentShape(Rectangle())
                            .onTapGesture { session.selectTexturePack(pack) }
                    }
                }.padding(.top, 2).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden).frame(height: CGFloat(max(0, r.height - 83))).offset(y: 32)
            #if os(macOS)
                BetaButton(title: "Open texture pack folder", width: 150, session: session) {
                    session.openTexturePackFolder()
                }.offset(x: CGFloat(r.width / 2 - 155), y: CGFloat(r.height - 48))
            #endif
            BetaButton(title: "Done", width: 150, session: session) { screen = .title }.offset(
                x: CGFloat(r.width / 2 + 5), y: CGFloat(r.height - 48))
        }
    }

    private func centered(_ text: String, width: Int, y: Int) -> some View {
        BetaText(text).offset(x: CGFloat(width / 2 - BetaBitmapFont.shared.width(text) / 2), y: CGFloat(y))
    }
    private var selectedWorld: WorldDescriptor? { session.availableWorlds.first { $0.directory == selected } }
    private func createWorld() {
        guard !name.isEmpty else { return }
        session.createWorld(name: name, seed: seed)
    }
    private func renameWorld() {
        if let world = selectedWorld { session.renameWorld(world, name: name) }
        screen = .worlds
    }
    private var folderName: String {
        let forbidden = Set("/\n\r\t\0\u{000C}`?*\\<>|\":")
        var folder = String(
            name.trimmingCharacters(in: .whitespacesAndNewlines).map { forbidden.contains($0) ? "_" : $0 })
        if folder.isEmpty || folder == "." || folder == ".." || folder == ".trash" { folder = "World" }
        while FileManager.default.fileExists(
            atPath: session.gameDirectory.appendingPathComponent("saves").appendingPathComponent(folder).path)
        { folder += "-" }
        return folder
    }
    private func worldDetail(_ world: WorldDescriptor) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let date = formatter.string(from: world.lastPlayed ?? Date(timeIntervalSince1970: 0))
        let size = Float(world.sizeOnDisk / 1024 * 100 / 1024) / 100
        return "\(world.directory.lastPathComponent) (\(date), \(size) MB)"
    }
    private static func randomSplash() -> String {
        let date = Calendar.current.dateComponents([.month, .day], from: Date())
        switch (date.month, date.day) {
        case (11, 9): return "Happy birthday, ez!"
        case (6, 1): return "Happy birthday, Notch!"
        case (12, 24): return "Merry X-mas!"
        case (1, 1): return "Happy new year!"
        default: break
        }
        guard
            let url = Bundle.main.url(forResource: "Vanilla", withExtension: nil)?.appendingPathComponent(
                "title/splashes.txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text.components(separatedBy: .newlines).filter { !$0.isEmpty }.randomElement() ?? ""
    }
    private func quit() {
        #if os(macOS)
            NSApplication.shared.terminate(nil)
        #else
            session.saveWorld()
        #endif
    }
}

struct DirtMenuBackground: View {
    var brightness: Double = 64
    @ObservedObject private var sprites = VanillaUISprites.shared
    var body: some View {
        Group {
            if let image = VanillaUISprites.image("gui/background.png") {
                Image(decorative: image, scale: CGFloat(image.width) / 32).resizable(resizingMode: .tile)
                    .interpolation(.none).colorMultiply(Color(white: brightness / 255))
            } else {
                Color(white: brightness / 255)
            }
        }.ignoresSafeArea()
    }
}
