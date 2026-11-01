import MinecraftCore
import SwiftUI

struct InventoryPanel: View {
    @ObservedObject var session: GameSession

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                ScrollView {
                    panel(slotSize: geometry.size.height < 480 ? 30 : 44)
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func panel(slotSize: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(slotSize), spacing: 4), count: 9)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(panelTitle).font(.headline)
                Spacer()
                Button("Done") { session.toggleInventory() }.buttonStyle(GameMenuButtonStyle())
            }
            if !session.containerLabels.isEmpty {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(session.containerLabels.indices, id: \.self) { index in
                        slot(
                            label: session.containerLabels[index], item: item(session.containerItems, index),
                            size: slotSize,
                            secondaryAction: { session.containerClick(slot: index, secondary: true) }
                        ) {
                            session.containerClick(slot: index)
                        }
                        .accessibilityLabel("Container slot \(index + 1), \(session.containerLabels[index])")
                    }
                }
                cursorHelp
            } else {
                HStack(alignment: .center, spacing: 16) {
                    if session.furnaceOpen {
                        furnace(slotSize: slotSize)
                    } else {
                        crafting(slotSize: slotSize)
                    }
                    Spacer()
                    cursorHelp.frame(maxWidth: 160, alignment: .leading)
                }
            }
            if session.containerLabels.isEmpty && !session.furnaceOpen && session.craftingWidth == 2 {
                HStack(spacing: 4) {
                    Text("Armor").font(.system(size: 11)).frame(width: 52, alignment: .leading)
                    ForEach(0..<4) { index in
                        slot(label: armorLabel(index), item: item(session.armorItems, index), size: slotSize)
                        { session.armorClick(slot: index) }
                        .accessibilityLabel("Armor slot \(index + 1), \(armorLabel(index))")
                    }
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(9..<36) { index in
                    slot(
                        label: inventoryLabel(index), item: item(session.inventoryItems, index),
                        size: slotSize,
                        secondaryAction: { session.inventoryClick(slot: index, secondary: true) }
                    ) {
                        session.inventoryClick(slot: index)
                    }
                    .accessibilityLabel("Inventory slot \(index + 1), \(inventoryLabel(index))")
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<9) { index in
                    slot(
                        label: inventoryLabel(index), item: item(session.inventoryItems, index),
                        size: slotSize,
                        selected: index == session.selectedHotbar,
                        secondaryAction: { session.inventoryClick(slot: index, secondary: true) }
                    ) {
                        session.inventoryClick(slot: index)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: slotSize * 9 + 64)
        .background(Color(white: 0.78))
        .overlay { Rectangle().strokeBorder(Color(white: 0.25), lineWidth: 3) }
        .foregroundStyle(.black)
    }

    private var panelTitle: String {
        if session.furnaceOpen { return "Furnace" }
        return session.containerTitle.isEmpty ? "Inventory" : session.containerTitle
    }

    private var cursorHelp: some View {
        Text(
            session.cursorLabel.isEmpty
                ? "Click a stack to pick it up.\nRight-click or hold a slot to split."
                : "Holding \(session.cursorLabel)\nRight-click or hold a slot to place one."
        )
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.black.opacity(0.7))
    }

    private func crafting(slotSize: CGFloat) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Crafting").font(.subheadline)
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(slotSize), spacing: 4), count: session.craftingWidth),
                    spacing: 4
                ) {
                    ForEach(0..<(session.craftingWidth * session.craftingWidth), id: \.self) { index in
                        slot(
                            label: craftingLabel(index), item: item(session.craftingItems, index),
                            size: slotSize,
                            secondaryAction: { session.craftingClick(slot: index, secondary: true) }
                        ) {
                            session.craftingClick(slot: index)
                        }
                    }
                }
                .frame(width: CGFloat(session.craftingWidth) * (slotSize + 4) - 4)
            }
            Image(systemName: "arrow.right").foregroundStyle(.gray)
            slot(label: session.craftingResultLabel, item: session.craftingResultItem, size: slotSize) {
                session.takeCraftingResult()
            }
        }
    }

    private func furnace(slotSize: CGFloat) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Input").font(.system(size: 10))
                slot(label: furnaceLabel(0), item: item(session.furnaceItems, 0), size: slotSize) {
                    session.furnaceClick(slot: 0)
                }
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                slot(label: furnaceLabel(1), item: item(session.furnaceItems, 1), size: slotSize) {
                    session.furnaceClick(slot: 1)
                }
                Text("Fuel").font(.system(size: 10))
            }
            VStack(spacing: 6) {
                ProgressView(value: min(max(session.furnaceProgress, 0), 1)).frame(width: 56)
                Image(systemName: "arrow.right").foregroundStyle(.gray)
            }
            VStack(spacing: 6) {
                Text("Output").font(.system(size: 10))
                slot(label: furnaceLabel(2), item: item(session.furnaceItems, 2), size: slotSize) {
                    session.furnaceClick(slot: 2)
                }
            }
        }
    }

    private func slot(
        label: String, item: ItemStack? = nil, size: CGFloat, selected: Bool = false,
        secondaryAction: (() -> Void)? = nil, action: @escaping () -> Void
    )
        -> some View
    {
        Button(action: action) {
            GameItemIcon(stack: item, fallback: label, size: size)
                .background(Color(white: 0.55))
                .overlay { Rectangle().strokeBorder(selected ? .white : Color(white: 0.3), lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? "Empty slot" : label)
        .contextMenu {
            if let secondaryAction {
                Button(session.cursorLabel.isEmpty ? "Take half" : "Place one", action: secondaryAction)
            }
        }
    }

    private func item(_ items: [ItemStack?], _ index: Int) -> ItemStack? {
        items.indices.contains(index) ? items[index] : nil
    }

    private func inventoryLabel(_ index: Int) -> String {
        session.inventoryLabels.indices.contains(index) ? session.inventoryLabels[index] : ""
    }

    private func craftingLabel(_ index: Int) -> String {
        session.craftingLabels.indices.contains(index) ? session.craftingLabels[index] : ""
    }

    private func furnaceLabel(_ index: Int) -> String {
        session.furnaceLabels.indices.contains(index) ? session.furnaceLabels[index] : ""
    }

    private func armorLabel(_ index: Int) -> String {
        session.armorLabels.indices.contains(index) ? session.armorLabels[index] : ""
    }
}

struct PausePanel: View {
    @ObservedObject var session: GameSession
    @State private var multiplayerMenuOpen = false
    @State private var optionsOpen = false
    @State private var statisticsOpen = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text(session.isMultiplayer && session.health <= 0 ? "You died" : "Game menu").font(
                        .title2
                    )
                    .foregroundStyle(.white).padding(.bottom, 8)
                    if session.isMultiplayer && session.health <= 0 {
                        Button("Respawn") { session.respawnMultiplayer() }
                    } else {
                        Button("Back to game") { session.togglePause() }
                    }
                    if !session.isMultiplayer { Button("Save world") { session.saveWorld() } }
                    if session.isMultiplayer {
                        Button("Disconnect") { session.disconnectMultiplayer() }
                    } else {
                        Button("Multiplayer…") { multiplayerMenuOpen = true }
                    }
                    Button("Statistics and achievements…") { statisticsOpen = true }
                    Button("Options…") { optionsOpen = true }
                    Button("Save and return to worlds") { session.showWorldMenu() }
                    if !session.multiplayerStatus.isEmpty {
                        Text(session.multiplayerStatus).font(.system(size: 11)).foregroundStyle(.white)
                    }
                    Text("Worlds save automatically when leaving the app.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(GameMenuButtonStyle())
                .frame(width: 300).padding(20)
            }
        }
        .sheet(isPresented: $multiplayerMenuOpen) { MultiplayerPanel(session: session) }
        .sheet(isPresented: $optionsOpen) { GameOptionsPanel(session: session) }
        .sheet(isPresented: $statisticsOpen) { StatisticsPanel(session: session) }
    }
}

struct MultiplayerPanel: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var host = "localhost"
    @State private var port = "25565"
    @State private var username = "Player"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiplayer").font(.title2)
            Text("Connect to a Minecraft Beta 1.7.3 server.").font(.subheadline)
            TextField("Server address", text: $host)
                .autocorrectionDisabled()
            TextField("Port", text: $port)
            TextField("Player name", text: $username)
                .autocorrectionDisabled()
            Text("Offline-mode servers are supported. Online authentication is not available.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Connect") {
                    guard let portNumber = UInt16(port), portNumber > 0 else { return }
                    session.connectMultiplayer(host: host, port: portNumber, username: username)
                    dismiss()
                }
                .disabled(!validAddress)
            }
            .buttonStyle(GameMenuButtonStyle())
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(minWidth: 320, idealWidth: 400)
    }

    private var validAddress: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && UInt16(port).map({ $0 > 0 }) == true
            && !username.isEmpty && username.utf16.count <= 16
    }
}

struct GameMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white).frame(maxWidth: .infinity)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color(white: configuration.isPressed ? 0.3 : 0.45))
            .overlay { Rectangle().strokeBorder(Color(white: 0.15), lineWidth: 2) }
            .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 1)
    }
}
