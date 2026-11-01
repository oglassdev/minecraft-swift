import SwiftUI

struct GameLoadingPanel: View {
    @ObservedObject var session: GameSession

    var body: some View {
        BetaGUI(option: session.options.guiScale) { gui in
            ZStack(alignment: .topLeading) {
                DirtMenuBackground()
                if session.isMultiplayer {
                    BetaText("Downloading terrain").position(
                        x: CGFloat(gui.width / 2), y: CGFloat(gui.height / 2 - 46))
                    BetaButton(title: "Cancel", session: session) { session.disconnectMultiplayer() }
                        .position(x: CGFloat(gui.width / 2), y: CGFloat(gui.height / 4 + 130))
                } else {
                    BetaText("Loading level").position(
                        x: CGFloat(gui.width / 2), y: CGFloat(gui.height / 2 - 16))
                    BetaText("Building terrain").position(
                        x: CGFloat(gui.width / 2), y: CGFloat(gui.height / 2 + 8))
                    if let progress = session.loadingProgress {
                        Rectangle().fill(Color(white: 128.0 / 255)).frame(width: 100, height: 2)
                            .offset(x: CGFloat(gui.width / 2 - 50), y: CGFloat(gui.height / 2 + 16))
                        Rectangle().fill(Color(red: 128.0 / 255, green: 1, blue: 128.0 / 255))
                            .frame(width: CGFloat(min(1, max(0, progress)) * 100), height: 2)
                            .offset(x: CGFloat(gui.width / 2 - 50), y: CGFloat(gui.height / 2 + 16))
                    }
                }
            }
        }.ignoresSafeArea()
    }
}
