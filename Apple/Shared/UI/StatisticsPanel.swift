import MinecraftCore
import SwiftUI

struct StatisticsPanel: View {
    @ObservedObject var session: GameSession
    var initialTab = 0
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var sortedColumn: Int?
    @State private var descending = true

    var body: some View {
        Group {
            if initialTab == 3 {
                AchievementPanel(session: session, closed: close)
            } else {
                BetaGUI(option: session.options.guiScale) { resolution in
                    ZStack(alignment: .topLeading) {
                        if session.worldMenuOpen { DirtMenuBackground() } else { BetaScreenShade() }
                        DirtMenuBackground(brightness: 32).frame(height: CGFloat(resolution.height - 96))
                            .offset(y: 32)
                        ScrollView {
                            VStack(spacing: 0) {
                                if tab != 0 { tableHeader }
                                ForEach(Array(definitions.enumerated()), id: \.element.id) {
                                    index, definition in row(definition, index: index)
                                }
                            }.padding(.top, 4).frame(maxWidth: .infinity)
                        }.scrollIndicators(.hidden).frame(height: CGFloat(max(0, resolution.height - 96)))
                            .offset(y: 32)
                        BetaText("Statistics").offset(
                            x: CGFloat(resolution.width / 2 - BetaBitmapFont.shared.width("Statistics") / 2),
                            y: 20)
                        BetaButton(title: "General", width: 100, session: session) {
                            tab = 0
                            sortedColumn = nil
                        }.offset(x: CGFloat(resolution.width / 2 - 154), y: CGFloat(resolution.height - 52))
                        BetaButton(title: "Blocks", width: 100, enabled: !blocks.isEmpty, session: session) {
                            tab = 1
                            sortedColumn = nil
                        }.offset(x: CGFloat(resolution.width / 2 - 46), y: CGFloat(resolution.height - 52))
                        BetaButton(title: "Items", width: 100, enabled: !items.isEmpty, session: session) {
                            tab = 2
                            sortedColumn = nil
                        }.offset(x: CGFloat(resolution.width / 2 + 62), y: CGFloat(resolution.height - 52))
                        BetaButton(title: "Done", width: 150, session: session, action: close).offset(
                            x: CGFloat(resolution.width / 2 + 4), y: CGFloat(resolution.height - 28))
                    }
                }
            }
        }.onAppear { tab = initialTab }
    }

    private var tableHeader: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<3) { index in
                let textureX = tab == 1 ? [18, 36, 54][index] : [72, 18, 36][index]
                BetaSprite(name: "gui/slot.png", rect: CGRect(x: textureX, y: 18, width: 18, height: 18))
                    .offset(x: CGFloat(97 + index * 50), y: 1)
                    .contentShape(Rectangle()).onTapGesture {
                        if sortedColumn == index {
                            descending.toggle()
                        } else {
                            sortedColumn = index
                            descending = true
                        }
                    }
            }
        }.frame(width: 220, height: 20, alignment: .topLeading)
    }

    private func row(_ definition: StatisticDefinition, index: Int) -> some View {
        let color: UInt32 = index % 2 == 0 ? 0xFFFFFF : 0x909090
        return ZStack(alignment: .topLeading) {
            if tab == 0 {
                BetaText(definition.name, color: color).offset(x: 2, y: 1)
                let value = definition.formatted(session.statistics.value(for: definition.id))
                BetaText(value, color: color).offset(
                    x: CGFloat(215 - BetaBitmapFont.shared.width(value)), y: 1)
            } else if let id = definition.itemID {
                BetaSprite(name: "gui/slot.png", rect: CGRect(x: 0, y: 0, width: 18, height: 18)).offset(
                    x: 41, y: 1)
                GameItemIcon(stack: ItemStack(id: id), size: 16).offset(x: 42, y: 2)
                ForEach(0..<3) { column in
                    let value = String(value(id: id, column: column))
                    BetaText(value, color: color).offset(
                        x: CGFloat(115 + column * 50 - BetaBitmapFont.shared.width(value)), y: 5)
                }
            }
        }.frame(width: 220, height: tab == 0 ? 10 : 20, alignment: .topLeading)
    }

    private var blocks: [StatisticDefinition] {
        StatisticRegistry.blocks.filter { definition in
            guard let id = definition.itemID else { return false }
            return (0..<3).contains { value(id: id, column: $0, blocks: true) > 0 }
        }
    }
    private var items: [StatisticDefinition] {
        StatisticRegistry.items.filter { definition in
            guard let id = definition.itemID else { return false }
            return (0..<3).contains { value(id: id, column: $0, blocks: false) > 0 }
        }
    }
    private var definitions: [StatisticDefinition] {
        var rows = tab == 0 ? StatisticRegistry.general : (tab == 1 ? blocks : items)
        if let column = sortedColumn {
            rows.sort { left, right in
                let a = value(id: left.itemID ?? 0, column: column)
                let b = value(id: right.itemID ?? 0, column: column)
                return a == b ? left.id < right.id : (descending ? a > b : a < b)
            }
        }
        return rows
    }
    private func value(id: UInt16, column: Int, blocks: Bool? = nil) -> Int {
        let block = blocks ?? (tab == 1)
        let definition: StatisticDefinition?
        if block {
            definition =
                column == 0
                ? StatisticRegistry.craft(itemID: id)
                : (column == 1 ? StatisticRegistry.use(itemID: id) : StatisticRegistry.mine(blockID: id))
        } else {
            definition =
                column == 0
                ? StatisticRegistry.depleted(itemID: id)
                : (column == 1 ? StatisticRegistry.craft(itemID: id) : StatisticRegistry.use(itemID: id))
        }
        return definition.map { session.statistics.value(for: $0.id) } ?? 0
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
}

private struct AchievementPanel: View {
    @ObservedObject var session: GameSession
    var closed: () -> Void
    @State private var camera = CGPoint(x: -82, y: -70)
    @State private var dragOrigin: CGPoint?
    @State private var pointer: CGPoint?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { _ in
            BetaGUI(option: session.options.guiScale) { r in
                let origin = CGPoint(x: (r.width - 256) / 2, y: (r.height - 202) / 2)
                ZStack(alignment: .topLeading) {
                    BetaScreenShade()
                    graph.frame(width: 224, height: 155, alignment: .topLeading).clipped()
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onChanged { value in
                                if dragOrigin == nil { dragOrigin = camera }
                                let start = dragOrigin ?? camera
                                camera = clamped(
                                    CGPoint(
                                        x: start.x - value.translation.width,
                                        y: start.y - value.translation.height))
                            }.onEnded { _ in dragOrigin = nil }
                        )
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let point): pointer = point
                            case .ended: pointer = nil
                            }
                        }
                        .offset(x: origin.x + 16, y: origin.y + 17)
                    BetaSprite(name: "achievement/bg.png", rect: CGRect(x: 0, y: 0, width: 256, height: 202))
                        .offset(x: origin.x, y: origin.y).allowsHitTesting(false)
                    BetaText("Achievements", color: 0x404040, shadow: false).offset(
                        x: origin.x + 15, y: origin.y + 5)
                    BetaButton(title: "Done", width: 80, session: session, action: closed).offset(
                        x: CGFloat(r.width / 2 + 24), y: CGFloat(r.height / 2 + 74))
                    if let pointer, let achievement = hovered(pointer) {
                        tooltip(achievement).offset(
                            x: origin.x + 16 + pointer.x + 12, y: origin.y + 17 + pointer.y - 4
                        ).allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var graph: some View {
        let x = Int(floor(camera.x))
        let y = Int(floor(camera.y))
        return ZStack(alignment: .topLeading) {
            ForEach(0..<11) { row in
                ForEach(0..<15) { column in
                    let tile = terrain(column: column, row: row)
                    BetaSprite(
                        name: "terrain.png",
                        rect: CGRect(x: tile % 16 * 16, y: tile / 16 * 16, width: 16, height: 16)
                    )
                    .colorMultiply(Color(white: max(0, 0.6 - Double(((y + 288) >> 4) + row) / 25 * 0.3)))
                    .offset(x: CGFloat(column * 16 - (x + 288) % 16), y: CGFloat(row * 16 - (y + 288) % 16))
                }
            }
            ForEach(Achievements.all) { achievement in
                if let parent = achievement.parentID.flatMap({ Achievements.definition(for: $0) }) {
                    let a = point(achievement)
                    let b = point(parent)
                    let color: Color =
                        session.statistics.isUnlocked(achievement.id)
                        ? Color(white: 0x70 / 255.0)
                        : (session.statistics.canUnlock(achievement)
                            ? Color.green.opacity(
                                sin(
                                    Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 0.6) / 0.6
                                        * Double.pi * 2) > 0.6 ? 1 : 130.0 / 255) : .black)
                    Rectangle().fill(color).frame(width: abs(a.x - b.x) + 1, height: 1).offset(
                        x: min(a.x, b.x) + 11, y: a.y + 11)
                    Rectangle().fill(color).frame(width: 1, height: abs(a.y - b.y) + 1).offset(
                        x: b.x + 11, y: min(a.y, b.y) + 11)
                }
            }
            ForEach(Achievements.all) { achievement in
                let point = point(achievement)
                let accessible = session.statistics.canUnlock(achievement)
                let unlocked = session.statistics.isUnlocked(achievement.id)
                BetaSprite(
                    name: "achievement/bg.png",
                    rect: CGRect(x: achievement.isSpecial ? 26 : 0, y: 202, width: 26, height: 26)
                )
                .colorMultiply(
                    Color(
                        white: unlocked
                            ? 1
                            : (accessible
                                ? (sin(
                                    Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 0.6) / 0.6
                                        * Double.pi * 2) < 0.6 ? 0.6 : 0.8) : 0.3))
                ).offset(
                    x: point.x - 2, y: point.y - 2)
                GameItemIcon(stack: achievement.icon, size: 16).colorMultiply(
                    Color(white: accessible ? 1 : 0.1)
                ).offset(x: point.x + 3, y: point.y + 3)
            }
        }
    }

    private func terrain(column: Int, row: Int) -> Int {
        let x = (Int(floor(camera.x)) + 288) >> 4
        let y = ((Int(floor(camera.y)) + 288) >> 4) + row
        var random = JavaRandom(seed: Int64(1234 + x + column))
        _ = random.nextInt()
        let depth = random.nextInt(bound: max(1, 1 + y)) + y / 2
        if depth > 37 || y == 35 { return 17 }
        if depth == 22 { return random.nextInt(bound: 2) == 0 ? 50 : 51 }
        if depth == 10 { return 33 }
        if depth == 8 { return 34 }
        if depth > 4 { return 1 }
        if depth > 0 { return 2 }
        return 18
    }
    private func point(_ achievement: AchievementDefinition) -> CGPoint {
        CGPoint(
            x: achievement.column * 24 - Int(floor(camera.x)), y: achievement.row * 24 - Int(floor(camera.y)))
    }
    private func hovered(_ pointer: CGPoint) -> AchievementDefinition? {
        Achievements.all.last {
            let p = point($0)
            return CGRect(x: p.x, y: p.y, width: 23, height: 23).contains(pointer)
        }
    }
    private func clamped(_ point: CGPoint) -> CGPoint {
        let columns = Achievements.all.map(\.column)
        let rows = Achievements.all.map(\.row)
        return CGPoint(
            x: min(
                CGFloat((columns.max() ?? 0) * 24 - 78),
                max(CGFloat((columns.min() ?? 0) * 24 - 112), point.x)),
            y: min(CGFloat((rows.max() ?? 0) * 24 - 78), max(CGFloat((rows.min() ?? 0) * 24 - 112), point.y)))
    }
    private func tooltip(_ achievement: AchievementDefinition) -> some View {
        let accessible = session.statistics.canUnlock(achievement)
        let width = max(120, BetaBitmapFont.shared.width(achievement.title))
        let text =
            accessible
            ? achievement.description
            : "Requires '\(achievement.parentID.flatMap { Achievements.definition(for: $0)?.title } ?? "")'"
        let lines = wrapped(text, width: width)
        let unlocked = session.statistics.isUnlocked(achievement.id)
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.75).frame(
                width: CGFloat(width + 6), height: CGFloat(lines.count * 8 + (unlocked ? 30 : 18))
            ).offset(x: -3, y: -3)
            BetaText(
                achievement.title,
                color: achievement.isSpecial ? 0xFFFF80 : (accessible ? 0xFFFFFF : 0x808080))
            BetaText(lines.joined(separator: "\n"), color: accessible ? 0xA0A0A0 : 0x705050, shadow: false)
                .offset(y: 12)
            if unlocked {
                BetaText("Achievement get!", color: 0x9090FF).offset(y: CGFloat(lines.count * 8 + 16))
            }
        }
    }
    private func wrapped(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ") {
            if !line.isEmpty && BetaBitmapFont.shared.width(line + " " + word) >= width {
                lines.append(line)
                line = String(word)
            } else {
                line += (line.isEmpty ? "" : " ") + word
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }
}
