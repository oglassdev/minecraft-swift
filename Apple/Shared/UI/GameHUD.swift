import MinecraftCore
import SwiftUI

struct GameHUD: View {
    @ObservedObject var session: GameSession
    @State private var achievementStarted = Date()

    /// Between ticks only the debug position, pickup bounce, and achievement toast change per frame.
    private var animatesEveryFrame: Bool {
        session.showDebug || session.achievementNotice != nil
            || session.hotbarPickupTicks.contains(where: { $0 > 0 })
    }

    var body: some View {
        TimelineView(.animation(paused: !animatesEveryFrame)) { _ in
            BetaGUI(option: session.options.guiScale) { resolution in
                ZStack(alignment: .topLeading) {
                    if !session.hideHUD && !session.worldMenuOpen {
                        hud(width: resolution.width, height: resolution.height)
                        if session.sleepTicks > 0 {
                            Color(red: 16.0 / 255, green: 16.0 / 255, blue: 32.0 / 255)
                                .opacity(session.sleepOpacity)
                        }
                        if session.showDebug { debugOverlay }
                        if let title = session.achievementNotice {
                            achievementToast(title).offset(
                                x: CGFloat(resolution.width - 160), y: achievementOffset)
                        }
                    }
                    #if os(iOS)
                        VStack {
                            HStack(spacing: 12) {
                                Spacer()
                                Button {
                                    session.toggleInventory()
                                } label: {
                                    Image(systemName: "square.grid.3x3.fill")
                                }
                                if session.isMultiplayer {
                                    Button {
                                        session.beginChat()
                                    } label: {
                                        Image(systemName: "bubble.left.fill")
                                    }
                                }
                                Button {
                                    session.togglePause()
                                } label: {
                                    Image(systemName: "pause.fill")
                                }
                            }.font(.system(size: 16)).foregroundStyle(.white).buttonStyle(.plain).padding(10)
                            Spacer()
                        }
                    #endif
                }.frame(
                    width: CGFloat(resolution.width), height: CGFloat(resolution.height),
                    alignment: .topLeading)
            }
        }
        .onAppear { configureTextures() }
        .onChange(of: session.achievementNotice) { _, title in if title != nil { achievementStarted = Date() }
        }
        .onChange(of: session.texturePackRevision) { _, _ in configureTextures() }
        #if os(macOS)
            .allowsHitTesting(false)
        #endif
    }

    private func hud(width: Int, height: Int) -> some View {
        ZStack(alignment: .topLeading) {
            BetaSprite(name: "gui/gui.png", rect: CGRect(x: 0, y: 0, width: 182, height: 22))
                .offset(x: CGFloat(width / 2 - 91), y: CGFloat(height - 22))
            BetaSprite(name: "gui/gui.png", rect: CGRect(x: 0, y: 22, width: 24, height: 22))
                .offset(x: CGFloat(width / 2 - 92 + session.selectedHotbar * 20), y: CGFloat(height - 23))
            BetaSprite(name: "gui/icons.png", rect: CGRect(x: 0, y: 0, width: 16, height: 16))
                .blendMode(.difference).offset(x: CGFloat(width / 2 - 7), y: CGFloat(height / 2 - 7))
            ForEach(0..<9) { index in
                GameItemIcon(stack: item(index), size: 16, pickupAnimation: pickupAnimation(index))
                    .offset(x: CGFloat(width / 2 - 88 + index * 20), y: CGFloat(height - 19))
            }
            ForEach(0..<10) { index in
                heart(index: index).offset(
                    x: CGFloat(width / 2 - 91 + index * 8), y: CGFloat(height - 32 + heartJitter(index)))
                if session.armorPoints > 0 {
                    BetaSprite(
                        name: "gui/icons.png", rect: CGRect(x: armorIcon(index), y: 9, width: 9, height: 9)
                    )
                    .offset(x: CGFloat(width / 2 + 82 - index * 8), y: CGFloat(height - 32))
                }
            }
            if session.isUnderwater {
                let full = max(0, Int(ceil(Double(session.air - 2) * 10 / 300)))
                let total = max(0, Int(ceil(Double(session.air) * 10 / 300)))
                ForEach(0..<min(10, total), id: \.self) { index in
                    BetaSprite(
                        name: "gui/icons.png",
                        rect: CGRect(x: index < full ? 16 : 25, y: 18, width: 9, height: 9)
                    )
                    .offset(x: CGFloat(width / 2 - 91 + index * 8), y: CGFloat(height - 41))
                }
            }
        }
    }

    private func heart(index: Int) -> some View {
        let blink = session.healthFlashTime >= 10 && session.healthFlashTime / 3 % 2 == 1
        return ZStack(alignment: .topLeading) {
            BetaSprite(name: "gui/icons.png", rect: CGRect(x: blink ? 25 : 16, y: 0, width: 9, height: 9))
            if blink && session.previousHealth > index * 2 {
                BetaSprite(
                    name: "gui/icons.png",
                    rect: CGRect(
                        x: session.previousHealth > index * 2 + 1 ? 70 : 79, y: 0, width: 9, height: 9))
            }
            if session.health > index * 2 {
                BetaSprite(
                    name: "gui/icons.png",
                    rect: CGRect(x: session.health > index * 2 + 1 ? 52 : 61, y: 0, width: 9, height: 9))
            }
        }.frame(width: 9, height: 9)
    }

    private func armorIcon(_ index: Int) -> Int {
        if index * 2 + 1 < session.armorPoints { return 34 }
        return index * 2 + 1 == session.armorPoints ? 25 : 16
    }

    private func heartJitter(_ index: Int) -> Int {
        guard session.health <= 4 else { return 0 }
        var random = JavaRandom(seed: Int64(session.tickCount) &* 312871)
        var value = 0
        for _ in 0...index { value = random.nextInt(bound: 2) }
        return value
    }

    private var debugOverlay: some View {
        let position = session.cameraPositionDouble
        return ZStack(alignment: .topLeading) {
            BetaText("Minecraft Beta 1.7.3 (\(session.fps) fps)").offset(x: 2, y: 2)
            BetaText("C: \(session.world.chunks.count) E: \(session.entities.count)").offset(x: 2, y: 12)
            BetaText("x: \(position.x)", color: 0xE0E0E0).offset(x: 2, y: 64)
            BetaText("y: \(position.y)", color: 0xE0E0E0).offset(x: 2, y: 72)
            BetaText("z: \(position.z)", color: 0xE0E0E0).offset(x: 2, y: 80)
            BetaText(
                "f: \(Int(floor((session.camera.yaw * 180 / Float(Double.pi) - 180) / 90 + 0.5)) & 3)",
                color: 0xE0E0E0
            ).offset(x: 2, y: 88)
        }
    }

    private func pickupAnimation(_ index: Int) -> Float {
        guard session.hotbarPickupTicks.indices.contains(index) else { return 0 }
        return max(0, Float(session.hotbarPickupTicks[index]) - session.accumulator / 0.05)
    }

    private var achievementOffset: CGFloat {
        let elapsed = Date().timeIntervalSince(achievementStarted) / 3
        guard elapsed >= 0 && elapsed <= 1 else { return -36 }
        let triangular = elapsed > 0.5 ? 2 - elapsed * 2 : elapsed * 2
        let hidden = max(0, 1 - triangular * 4)
        return -CGFloat(Int(pow(hidden, 4) * 36))
    }

    private func achievementToast(_ title: String) -> some View {
        ZStack(alignment: .topLeading) {
            BetaSprite(name: "achievement/bg.png", rect: CGRect(x: 96, y: 202, width: 160, height: 32))
            BetaText("Achievement get!", color: 0xFFFF00, shadow: false).offset(x: 30, y: 7)
            BetaText(title, shadow: false).offset(x: 30, y: 18)
            if let achievement = Achievements.all.first(where: { $0.title == title }) {
                GameItemIcon(stack: achievement.icon, size: 16).offset(x: 8, y: 8)
            }
        }
    }

    private func configureTextures() {
        TextureResources.configure(overrideURL: session.texturePackURL, revision: session.texturePackRevision)
        VanillaUISprites.reset()
    }

    private func item(_ index: Int) -> ItemStack? {
        session.inventoryItems.indices.contains(index) ? session.inventoryItems[index] : nil
    }
}
