import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Modèles d'Intention (AppIntent)
struct LauncherStackEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Launcher Stack"
    static var defaultQuery = LauncherStackQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct LauncherStackQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LauncherStackEntity] {
        let configs = loadConfigs()
        return configs.filter { identifiers.contains($0.id.uuidString) }.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func suggestedEntities() async throws -> [LauncherStackEntity] {
        loadConfigs().map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func defaultResult() async -> LauncherStackEntity? {
        loadConfigs().first.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    private func loadConfigs() -> [WidgetConfigurationList] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetConfigurationsKey),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else { return [] }
        return decoded
    }
}

struct SelectLauncherStackIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Stack"
    @Parameter(title: "Stack") var stack: LauncherStackEntity?
}

// MARK: - Provider
struct LauncherEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfigurationList?
}

struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: Date(), configuration: nil)
    }
    func snapshot(for intent: SelectLauncherStackIntent, in context: Context) async -> LauncherEntry {
        let config = loadConfig(for: intent.stack?.id)
        return LauncherEntry(date: Date(), configuration: config)
    }
    func timeline(for intent: SelectLauncherStackIntent, in context: Context) async -> Timeline<LauncherEntry> {
        let config = loadConfig(for: intent.stack?.id)
        return Timeline(entries: [LauncherEntry(date: Date(), configuration: config)], policy: .atEnd)
    }
    private func loadConfig(for id: String?) -> WidgetConfigurationList? {
        guard let id = id,
              let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetConfigurationsKey),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else { return nil }
        return decoded.first(where: { $0.id.uuidString == id })
    }
}

// MARK: - Vue du Widget
struct StackLaunchWidgetView: View {
    let entry: LauncherEntry
    var body: some View {
        VStack {
            if let config = entry.configuration {
                Text(config.name).font(.headline)
            } else {
                Text("Select a stack").font(.caption)
            }
        }
        .containerBackground(Color.black.opacity(0.8), for: .widget)
    }
}

// MARK: - Widget Bundle
struct StackLaunchWidget: Widget {
    let kind: String = "StackLaunchWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLauncherStackIntent.self, provider: LauncherProvider()) { entry in
            StackLaunchWidgetView(entry: entry)
        }
        .configurationDisplayName("StackLaunch")
        .description("Display your stacks.")
    }
}