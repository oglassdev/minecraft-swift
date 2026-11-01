import ImageIO
import MinecraftCore
import SwiftUI

struct GameHUD: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            if !session.inventoryOpen && !session.isPaused {
                if let image = VanillaUISprites.sprite(
                    "gui/icons.png", rect: CGRect(x: 0, y: 0, width: 16, height: 16))
                {
                    Image(decorative: image, scale: 1).resizable().interpolation(.none)
                        .frame(width: 24, height: 24).allowsHitTesting(false)
                } else {
                    Text("+").font(.system(size: 22, weight: .light, design: .monospaced))
                        .foregroundStyle(.white).allowsHitTesting(false)
                }
            }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Minecraft Beta 1.7.3 · Swift").fontWeight(.semibold)
                        Text(session.positionText)
                        if !session.statusText.isEmpty { Text(session.statusText) }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .shadow(color: .black, radius: 1, x: 1, y: 1)
                    .allowsHitTesting(false)
                    Spacer()
                    if let achievement = session.achievementNotice {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Achievement get!").foregroundStyle(.yellow)
                            Text(achievement)
                        }.font(.system(size: 12, design: .monospaced)).padding(12).background(
                            .black.opacity(0.8))
                    }
                    #if os(iOS)
                        HStack(spacing: 12) {
                            Button {
                                session.toggleInventory()
                            } label: {
                                Image(systemName: "square.grid.3x3.fill")
                            }
                            .accessibilityLabel("Inventory")
                            if session.isMultiplayer {
                                Button {
                                    session.beginChat()
                                } label: {
                                    Image(systemName: "bubble.left.fill")
                                }.accessibilityLabel("Chat")
                            }
                            Button {
                                session.togglePause()
                            } label: {
                                Image(systemName: "pause.fill")
                            }
                            .accessibilityLabel("Pause")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 20))
                    #endif
                }
                .padding(16)
                Spacer()
                if !session.inventoryOpen && !session.isPaused {
                    VStack(spacing: 5) {
                        #if os(macOS)
                            if !session.isMouseCaptured {
                                Text(
                                    "Click to play · WASD move · Space jump · Shift sneak · E inventory · Esc pause"
                                )
                                .font(.system(size: 11)).padding(.bottom, 8)
                                .shadow(color: .black, radius: 2)
                            }
                        #endif
                        HStack {
                            hearts
                            Spacer()
                        }.frame(width: 360)
                        hotbar
                    }
                    .padding(.bottom, 12)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var hearts: some View {
        HStack(spacing: 0) {
            ForEach(0..<10) { index in
                ZStack {
                    heartSprite(x: 16, fallback: .black.opacity(0.6))
                    if session.health >= (index + 1) * 2 {
                        heartSprite(x: 52, fallback: .red)
                    } else if session.health == index * 2 + 1 {
                        heartSprite(x: 61, fallback: .red.opacity(0.6))
                    }
                }
                .frame(width: 18, height: 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health \(session.health) of 20")
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func heartSprite(x: CGFloat, fallback: Color) -> some View {
        if let image = VanillaUISprites.sprite("gui/icons.png", rect: CGRect(x: x, y: 0, width: 9, height: 9))
        {
            Image(decorative: image, scale: 1).resizable().interpolation(.none)
        } else {
            Image(systemName: "heart.fill").resizable().foregroundStyle(fallback).padding(2)
        }
    }

    private var hotbar: some View {
        HStack(spacing: 4) {
            ForEach(0..<9) { index in
                Button {
                    session.selectHotbar(index)
                } label: {
                    GameItemIcon(
                        stack: session.inventoryItems.indices.contains(index)
                            ? session.inventoryItems[index] : nil,
                        fallback: label(at: index), size: 36
                    )
                    .overlay {
                        if index == session.selectedHotbar {
                            Rectangle().stroke(.white, lineWidth: 2).padding(-2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hotbar slot \(index + 1), \(label(at: index))")
                .accessibilityAddTraits(index == session.selectedHotbar ? .isSelected : [])
            }
        }
        .padding(4)
        .background {
            if let image = VanillaUISprites.sprite(
                "gui/gui.png", rect: CGRect(x: 0, y: 0, width: 182, height: 22))
            {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
            } else {
                Rectangle().fill(.black.opacity(0.65)).overlay { Rectangle().stroke(.gray, lineWidth: 2) }
            }
        }
        #if os(macOS)
            .allowsHitTesting(false)
        #endif
    }

    private func label(at index: Int) -> String {
        session.hotbarLabels.indices.contains(index) ? session.hotbarLabels[index] : ""
    }
}

@MainActor
enum VanillaUISprites {
    private static var images: [String: CGImage] = [:]
    private static var crops: [String: CGImage] = [:]

    static func sprite(_ name: String, rect: CGRect) -> CGImage? {
        if images[name] == nil {
            guard let resources = Bundle.main.resourceURL else { return nil }
            let url = resources.appendingPathComponent("Vanilla").appendingPathComponent(name)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
            images[name] = image
        }
        let key = "\(name):\(rect.origin.x):\(rect.origin.y):\(rect.width):\(rect.height)"
        if let cached = crops[key] { return cached }
        let cropped = images[name]?.cropping(to: rect)
        crops[key] = cropped
        return cropped
    }
}
