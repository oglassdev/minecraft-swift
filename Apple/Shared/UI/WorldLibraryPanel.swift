import MinecraftCore
import SwiftUI

struct WorldLibraryPanel: View {
    @ObservedObject var session: GameSession
    @State private var creating = false
    @State private var optionsOpen = false
    @State private var multiplayerOpen = false

    var body: some View {
        ZStack {
            DirtMenuBackground()
            VStack(spacing: 16) {
                title.padding(.top, 20)
                Text("Select world").font(.title3).foregroundStyle(.white)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(session.availableWorlds) { world in
                            Button {
                                session.openWorld(world)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(world.name).font(.headline)
                                    Text(
                                        world.requiresConversion
                                            ? "Older save · convert and play"
                                            : "\(world.directory.lastPathComponent) · Day \(world.time / 24000)"
                                    )
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(
                                        .white.opacity(0.65))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                .background(.black.opacity(0.45))
                                .overlay { Rectangle().strokeBorder(.gray, lineWidth: 1) }
                            }.buttonStyle(.plain)
                        }
                        if session.availableWorlds.isEmpty {
                            Text("Create a world to start playing.").foregroundStyle(.white.opacity(0.7))
                                .padding(30)
                        }
                    }
                }.frame(maxWidth: 560, maxHeight: 350)
                HStack {
                    Button("Create new world") { creating = true }
                    Button("Multiplayer…") { multiplayerOpen = true }
                }
                HStack {
                    Button("Options…") { optionsOpen = true }
                    if session.hasLoadedWorld {
                        Button("Back to game") {
                            session.worldMenuOpen = false
                            session.isPaused = false
                            session.audio.setPaused(false)
                        }
                    }
                }
                Text("Minecraft Beta 1.7.3 · Swift port").font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(GameMenuButtonStyle()).frame(maxWidth: 560).padding(20)
            .foregroundStyle(.white)
        }
        .sheet(isPresented: $creating) { CreateWorldPanel(session: session) }
        .sheet(isPresented: $optionsOpen) { GameOptionsPanel(session: session) }
        .sheet(isPresented: $multiplayerOpen) { MultiplayerPanel(session: session) }
    }

    private var title: some View {
        HStack(spacing: 0) {
            if let left = VanillaUISprites.sprite(
                "title/mclogo.png", rect: CGRect(x: 0, y: 0, width: 155, height: 44)),
                let right = VanillaUISprites.sprite(
                    "title/mclogo.png", rect: CGRect(x: 0, y: 45, width: 119, height: 44))
            {
                Image(decorative: left, scale: 1).resizable().interpolation(.none).frame(
                    width: 155 * 1.3, height: 44 * 1.3)
                Image(decorative: right, scale: 1).resizable().interpolation(.none).frame(
                    width: 119 * 1.3, height: 44 * 1.3)
            } else {
                Text("MINECRAFT").font(.system(size: 36, weight: .black, design: .monospaced))
            }
        }.accessibilityLabel("Minecraft")
    }
}

struct DirtMenuBackground: View {
    var body: some View {
        ZStack {
            if let image = VanillaUISprites.sprite(
                "gui/background.png", rect: CGRect(x: 0, y: 0, width: 16, height: 16))
            {
                Image(decorative: image, scale: 0.5).resizable(resizingMode: .tile).interpolation(.none)
            } else {
                Color(red: 0.24, green: 0.16, blue: 0.11)
            }
            Color.black.opacity(0.5)
        }.ignoresSafeArea()
    }
}

private struct CreateWorldPanel: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var name = "New World"
    @State private var seed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create new world").font(.title2)
            TextField("World name", text: $name)
            TextField("Seed (optional)", text: $seed).autocorrectionDisabled()
            Text("Leave blank for a random seed. Numbers and text seeds use Beta’s original rules.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Create world") {
                    session.createWorld(name: name, seed: seed)
                    dismiss()
                }
            }.buttonStyle(GameMenuButtonStyle())
        }.textFieldStyle(.roundedBorder).padding(24).frame(minWidth: 320, idealWidth: 420)
    }
}

struct GameOptionsPanel: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Options").font(.title2)
                slider("Music", value: $session.options.music)
                slider("Sound", value: $session.options.sound)
                slider("Mouse sensitivity", value: $session.options.mouseSensitivity)
                Toggle("Invert mouse", isOn: $session.options.invertY)
                Picker("Render distance", selection: $session.options.renderDistance) {
                    Text("Far").tag(0)
                    Text("Normal").tag(1)
                    Text("Short").tag(2)
                    Text("Tiny").tag(3)
                }
                Toggle("Fancy graphics", isOn: $session.options.fancyGraphics)
                Toggle("Smooth lighting", isOn: $session.options.smoothLighting)
                Toggle("View bobbing", isOn: $session.options.viewBobbing)
                Picker("Frame rate", selection: $session.options.fpsLimit) {
                    Text("Unlimited").tag(0)
                    Text("Balanced").tag(1)
                    Text("Power saver").tag(2)
                }
                Picker("Difficulty", selection: $session.options.difficulty) {
                    Text("Peaceful").tag(0)
                    Text("Easy").tag(1)
                    Text("Normal").tag(2)
                    Text("Hard").tag(3)
                }
                Text("WASD move · Space jump · Shift sneak · E inventory · Q drop · T chat · 1–9 hotbar")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Done") {
                    session.saveOptions()
                    dismiss()
                }.buttonStyle(GameMenuButtonStyle())
            }.padding(24)
        }.frame(minWidth: 320, idealWidth: 420, minHeight: 300, idealHeight: 600, maxHeight: 680)
            .onDisappear { session.saveOptions() }
    }

    private func slider(_ name: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(name): \(Int(value.wrappedValue * 100))%")
            Slider(value: value, in: 0...1).onChange(of: value.wrappedValue) { _, _ in session.applyOptions()
            }
        }
    }
}
