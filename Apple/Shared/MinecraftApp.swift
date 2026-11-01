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
        #if os(macOS)
            Window("Minecraft", id: "minecraft") {
                GameView(onSessionAvailable: { appDelegate.activeSession = $0 })
                    .frame(minWidth: 320, minHeight: 240)
            }
            .defaultSize(width: 854, height: 480)
        #else
            WindowGroup { GameView() }
        #endif
    }
}

struct GameView: View {
    var onSessionAvailable: ((GameSession) -> Void)? = nil
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    private var showsChat: Bool {
        !session.isLoading && (session.isMultiplayer || session.chatOpen || !session.chatLines.isEmpty)
    }

    var body: some View {
        ZStack {
            MetalSurface(session: session)
                .ignoresSafeArea()
            #if os(iOS)
                TouchControls(session: session)
            #endif
            GameHUD(session: session)
            if showsChat { GameChatOverlay(session: session) }
            if session.inventoryOpen && !session.worldMenuOpen && !session.showDeathScreen {
                InventoryPanel(session: session)
            } else if session.isPaused && !session.worldMenuOpen && !session.showDeathScreen {
                PausePanel(session: session)
            }
            if session.worldMenuOpen { WorldLibraryPanel(session: session) }
            if session.signEditorOpen { SignEditorPanel(session: session) }
            if session.showDeathScreen && !session.worldMenuOpen && !session.isLoading {
                DeathPanel(session: session)
            }
            if session.isLoading { GameLoadingPanel(session: session) }
            if let message = session.errorMessage {
                BetaGUI(option: session.options.guiScale) { gui in
                    ZStack {
                        Color.black.opacity(0.8)
                        VStack(spacing: 12) {
                            BetaText(message)
                            BetaButton(title: "Dismiss", session: session) { session.errorMessage = nil }
                        }.frame(maxWidth: CGFloat(gui.width - 16))
                    }
                }
            }
        }
        .onAppear { onSessionAvailable?(session) }
        .onDisappear { session.persist() }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            session.releaseInputAndPause()
            if phase == .background { session.persist() }
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
            activeSession.persist { [weak self] in
                self?.waitingForSave = false
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }
#endif
