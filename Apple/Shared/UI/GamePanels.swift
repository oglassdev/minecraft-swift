import MinecraftCore
import SwiftUI

struct PausePanel: View {
    @ObservedObject var session: GameSession
    @State private var optionsOpen = false
    @State private var statisticsTab: Int?

    var body: some View {
        if optionsOpen {
            GameOptionsPanel(session: session, onClose: { optionsOpen = false })
        } else if let statisticsTab {
            StatisticsPanel(
                session: session, initialTab: statisticsTab, onClose: { self.statisticsTab = nil })
        } else {
            BetaGUI(option: session.options.guiScale) { resolution in
                ZStack(alignment: .topLeading) {
                    BetaScreenShade()
                    BetaText("Game menu").offset(
                        x: CGFloat(resolution.width / 2 - BetaBitmapFont.shared.width("Game menu") / 2), y: 40
                    )
                    BetaButton(title: "Back to game", session: session) { session.togglePause() }.offset(
                        x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 8))
                    BetaButton(title: "Achievements", width: 98, session: session) { statisticsTab = 3 }
                        .offset(
                            x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 32))
                    BetaButton(title: "Statistics", width: 98, session: session) { statisticsTab = 0 }.offset(
                        x: CGFloat(resolution.width / 2 + 2), y: CGFloat(resolution.height / 4 + 32))
                    BetaButton(title: "Options...", session: session) { optionsOpen = true }.offset(
                        x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 80))
                    BetaButton(
                        title: session.isMultiplayer ? "Disconnect" : "Save and quit to title",
                        session: session
                    ) { session.showWorldMenu() }.offset(
                        x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 104))
                }
            }
        }
    }
}

struct MultiplayerPanel: View {
    @ObservedObject var session: GameSession
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var focused = true

    var body: some View {
        BetaGUI(option: session.options.guiScale) { resolution in
            ZStack(alignment: .topLeading) {
                DirtMenuBackground()
                BetaText("Play Multiplayer").offset(
                    x: CGFloat(resolution.width / 2 - BetaBitmapFont.shared.width("Play Multiplayer") / 2),
                    y: CGFloat(resolution.height / 4 - 40))
                BetaText("Minecraft Multiplayer is currently not finished, but there", color: 0xA0A0A0)
                    .offset(x: CGFloat(resolution.width / 2 - 140), y: CGFloat(resolution.height / 4))
                BetaText("is some buggy early testing going on.", color: 0xA0A0A0)
                    .offset(x: CGFloat(resolution.width / 2 - 140), y: CGFloat(resolution.height / 4 + 9))
                BetaText("Enter the IP of a server to connect to it:", color: 0xA0A0A0)
                    .offset(x: CGFloat(resolution.width / 2 - 140), y: CGFloat(resolution.height / 4 + 36))
                BetaTextField(text: $address, focused: $focused, maximumLength: 128, submitted: connect)
                    .offset(
                        x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 58))
                BetaButton(title: "Connect", enabled: !address.isEmpty, session: session, action: connect)
                    .offset(x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 108))
                BetaButton(title: "Cancel", session: session) { close() }.offset(
                    x: CGFloat(resolution.width / 2 - 100), y: CGFloat(resolution.height / 4 + 132))
            }
        }.onAppear { address = session.options.lastServer.replacingOccurrences(of: "_", with: ":") }
    }

    private func connect() {
        var host = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        var port: UInt16 = 25565
        if host.hasPrefix("["), let end = host.firstIndex(of: "]") {
            let remainder = host[host.index(after: end)...].trimmingCharacters(in: .whitespacesAndNewlines)
            let address = String(host[host.index(after: host.startIndex)..<end])
            if remainder.hasPrefix(":"), let value = UInt16(remainder.dropFirst()) { port = value }
            host = address
        } else if host.filter({ $0 == ":" }).count == 1, let colon = host.firstIndex(of: ":") {
            port =
                UInt16(host[host.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines))
                ?? 25565
            host = String(host[..<colon])
        }
        session.options.lastServer = address.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "_")
        session.saveOptions()
        session.connectMultiplayer(host: host, port: port, username: "Player")
        close()
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
}
