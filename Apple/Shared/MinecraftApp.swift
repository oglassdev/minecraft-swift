import SwiftUI

@main
struct MinecraftApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                #if os(macOS)
                    .frame(minWidth: 800, minHeight: 500)
                #endif
        }
        #if os(macOS)
            .defaultSize(width: 1100, height: 720)
        #endif
    }
}

struct GameView: View {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MetalSurface(session: session)
                .ignoresSafeArea()
            Text("+")
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 8) {
                Text("MINECRAFT SWIFT  /  RENDERER PROTOTYPE")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text("Placeholder scene · free flight")
                    .font(.system(size: 12))
                Text(session.positionText)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                #if os(macOS)
                    Text(
                        session.isMouseCaptured
                            ? "WASD move  ·  Mouse look  ·  Space / Ctrl rise / descend  ·  Shift faster  ·  Esc release"
                            : "Click the scene to capture the mouse  ·  WASD move  ·  Esc release"
                    )
                    .font(.system(size: 12))
                #else
                    Text("Left drag: move  ·  Right drag: look  ·  ▲ / ▼: rise / descend")
                        .font(.system(size: 12))
                #endif
            }
            .padding(20)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            .allowsHitTesting(false)
            #if os(iOS)
                TouchControls(session: session)
            #endif
            if let message = session.errorMessage {
                Text(message)
                    .padding(24)
                    .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.resetInput() }
        }
    }
}
