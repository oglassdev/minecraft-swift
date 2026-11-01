import SwiftUI

struct BetaButton: View {
    let title: String
    var width: Int = 200
    var enabled = true
    var session: GameSession? = nil
    var action: () -> Void
    @State private var hovered = false
    @Environment(\.isEnabled) private var parentEnabled

    var body: some View {
        let active = enabled && parentEnabled
        let state = active ? (hovered ? 2 : 1) : 0
        Button {
            session?.play("random.click")
            action()
        } label: {
            ZStack(alignment: .topLeading) {
                BetaSprite(
                    name: "gui/gui.png", rect: CGRect(x: 0, y: 46 + state * 20, width: width / 2, height: 20))
                BetaSprite(
                    name: "gui/gui.png",
                    rect: CGRect(x: 200 - width / 2, y: 46 + state * 20, width: width / 2, height: 20)
                ).offset(x: CGFloat(width / 2))
                BetaText(title, color: active ? (hovered ? 0xFFFFA0 : 0xE0E0E0) : 0xA0A0A0)
                    .offset(x: CGFloat(width / 2 - BetaBitmapFont.shared.width(title) / 2), y: 6)
            }.frame(width: CGFloat(width), height: 20, alignment: .topLeading).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!active).onHover { hovered = $0 }.accessibilityLabel(title)
    }
}

struct DeathPanel: View {
    @ObservedObject var session: GameSession
    var body: some View {
        BetaGUI(option: session.options.guiScale) { resolution in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0x50 / 255.0, green: 0, blue: 0).opacity(0x60 / 255.0),
                        Color(red: 0x80 / 255.0, green: 0x30 / 255.0, blue: 0x30 / 255.0).opacity(
                            0xA0 / 255.0),
                    ], startPoint: .top, endPoint: .bottom)
                BetaText("Game over!").scaleEffect(2, anchor: .topLeading)
                    .offset(
                        x: CGFloat(resolution.width / 4 * 2 - BetaBitmapFont.shared.width("Game over!")),
                        y: 60)
                BetaText("Score: &e\(session.playerScore)")
                    .offset(
                        x: CGFloat(
                            (resolution.width - BetaBitmapFont.shared.width("Score: &e\(session.playerScore)"))
                                / 2), y: 100)
                BetaButton(title: "Respawn") {
                    if session.isMultiplayer {
                        session.respawnMultiplayer()
                    } else {
                        session.respawnSingleplayer()
                    }
                }
                .offset(x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 72))
                BetaButton(title: "Title menu") { session.showWorldMenu() }
                    .offset(x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 96))
            }
        }
    }
}
