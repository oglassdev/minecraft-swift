import SwiftUI

#if os(macOS)
    import AppKit
#endif

@main
struct MinecraftApp: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(GameAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
                GameView(onSessionAvailable: { appDelegate.activeSession = $0 })
                    .frame(minWidth: 800, minHeight: 500)
            #else
                GameView()
            #endif
        }
        #if os(macOS)
            .defaultSize(width: 1100, height: 720)
        #endif
    }
}

struct GameView: View {
    var onSessionAvailable: ((GameSession) -> Void)? = nil
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MetalSurface(session: session)
                .ignoresSafeArea()
            #if os(iOS)
                TouchControls(session: session)
            #endif
            GameHUD(session: session)
            if session.isMultiplayer && !session.isLoading { GameChatOverlay(session: session) }
            if session.inventoryOpen {
                InventoryPanel(session: session)
            } else if session.isPaused {
                PausePanel(session: session)
            }
            if session.worldMenuOpen { WorldLibraryPanel(session: session) }
            if session.signEditorOpen { SignEditorPanel(session: session) }
            if session.isLoading {
                ZStack {
                    Color.black.opacity(0.75).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white)
                        Text(session.statusText.isEmpty ? "Building terrain…" : session.statusText)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.white)
                        if session.isMultiplayer {
                            Button("Cancel") { session.disconnectMultiplayer() }.buttonStyle(
                                GameMenuButtonStyle()
                            ).frame(width: 160)
                        }
                    }
                }
            }
            if let message = session.errorMessage {
                VStack(spacing: 12) {
                    Text(message)
                    Button("Dismiss") { session.errorMessage = nil }.buttonStyle(GameMenuButtonStyle())
                }
                .padding(24)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
        }
        .onAppear { onSessionAvailable?(session) }
        .onDisappear {
            session.returnCursorAndCrafting()
            session.saveWorld()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.primaryAction(isPressed: false)
                session.resetInput()
                if !session.isPaused && !session.inventoryOpen { session.togglePause() }
                if phase == .background {
                    session.returnCursorAndCrafting()
                    session.saveWorld()
                }
            }
        }
        #if os(macOS)
            .onExitCommand {
                session.dismissOverlay()
            }
        #endif
    }
}

#if os(macOS)
    @MainActor
    final class GameAppDelegate: NSObject, NSApplicationDelegate {
        weak var activeSession: GameSession?
        private var waitingForSave = false

        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            guard let activeSession else { return .terminateNow }
            guard !waitingForSave else { return .terminateLater }
            waitingForSave = true
            activeSession.streamingTask?.cancel()
            activeSession.returnCursorAndCrafting()
            activeSession.saveWorld { [weak self] in
                self?.waitingForSave = false
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }
#endif
