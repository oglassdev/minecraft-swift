import MinecraftCore
import SwiftUI

struct StatisticsPanel: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 14) {
            Text("Statistics and achievements").font(.title2)
            Picker("Category", selection: $tab) {
                Text("General").tag(0)
                Text("Blocks").tag(1)
                Text("Items").tag(2)
                Text("Achievements").tag(3)
            }.pickerStyle(.segmented)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if tab == 3 {
                        ForEach(Achievements.all) { achievement in
                            HStack(spacing: 12) {
                                GameItemIcon(stack: achievement.icon, size: 36)
                                    .background(
                                        session.statistics.isUnlocked(achievement.id)
                                            ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(achievement.title).fontWeight(.semibold)
                                    Text(achievement.description).font(.system(size: 11))
                                    if let parent = achievement.parentID,
                                        !session.statistics.isUnlocked(parent)
                                    {
                                        Text(
                                            "Requires \(Achievements.definition(for: parent)?.title ?? "previous achievement")"
                                        )
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if session.statistics.isUnlocked(achievement.id) {
                                    Image(systemName: "checkmark").foregroundStyle(.green)
                                }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.gray.opacity(0.08))
                        }
                    } else {
                        ForEach(definitions) { definition in
                            HStack {
                                if let id = definition.itemID {
                                    GameItemIcon(stack: ItemStack(id: id), size: 28)
                                }
                                Text(definition.name)
                                Spacer()
                                Text(definition.formatted(session.statistics.value(for: definition.id)))
                                    .monospacedDigit()
                            }.font(.system(size: 12)).padding(8).background(.gray.opacity(0.08))
                        }
                    }
                }
            }
            Button("Done") { dismiss() }.buttonStyle(GameMenuButtonStyle())
        }.padding(20).frame(minWidth: 340, idealWidth: 560, minHeight: 360, idealHeight: 550)
    }

    private var definitions: [StatisticDefinition] {
        tab == 0 ? StatisticRegistry.general : (tab == 1 ? StatisticRegistry.blocks : StatisticRegistry.items)
    }
}
