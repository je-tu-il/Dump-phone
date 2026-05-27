import AppIntents
import SwiftUI
import WidgetKit

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
        AppGroupLogger.log("INTENT: appel suggestedEntities")
        let configs = loadConfigs()
        if configs.isEmpty {
            AppGroupLogger.log("INTENT: 0 pile renvoyée")
            return [LauncherStackEntity(id: "empty", name: "Aucune pile (Ouvrez l'app)")]
        }
        return configs.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    
    func defaultResult() async -> LauncherStackEntity? {
        loadConfigs().first.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    
    private func loadConfigs() -> [WidgetConfigurationList] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetConfigurationsKey) else {
            AppGroupLogger.log("INTENT ERR: UserDefaults data nil")
            return []
        }
        do {
            return try JSONDecoder().decode([WidgetConfigurationList].self, from: data)
        } catch {
            AppGroupLogger.log("INTENT ERR: Décodage - \(error)")
            return []
        }
    }
}

struct SelectLauncherStackIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Stack"
    @Parameter(title: "Stack") var stack: LauncherStackEntity?
}

struct LauncherEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfigurationList?
}

struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: Date(), configuration: nil)
    }
    func snapshot(for intent: SelectLauncherStackIntent, in context: Context) async -> LauncherEntry {
        LauncherEntry(date: Date(), configuration: loadConfig(for: intent.stack?.id))
    }
    func timeline(for intent: SelectLauncherStackIntent, in context: Context) async -> Timeline<LauncherEntry> {
        AppGroupLogger.log("WIDGET: timeline générée pour \(intent.stack?.id ?? "nil")")
        return Timeline(entries: [LauncherEntry(date: Date(), configuration: loadConfig(for: intent.stack?.id))], policy: .atEnd)
    }
    
    private func loadConfig(for id: String?) -> WidgetConfigurationList? {
        guard let id = id,
              let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetConfigurationsKey),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else { return nil }
        return decoded.first(where: { $0.id.uuidString == id })
    }
}

struct StackLaunchWidgetView: View {
    let entry: LauncherEntry
    
    var body: some View {
        if let configuration = entry.configuration, !configuration.id.uuidString.contains("empty") {
            VStack(alignment: horizontalAlignment(for: configuration.textAlignment), spacing: 7) {
                Text(configuration.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: configuration.textAlignment))
                
                ForEach(configuration.visibleApplications) { app in
                    if let url = URL(string: app.urlScheme) {
                        Link(destination: url) {
                            LauncherLinkRow(app: app, configuration: configuration)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .containerBackground(Color(hex: configuration.backgroundColorHex), for: .widget)
        } else {
            VStack {
                Text("Select a Stack").font(.caption).foregroundColor(.gray)
            }
            .containerBackground(Color.black, for: .widget)
        }
    }
    
    private func horizontalAlignment(for option: TextAlignmentOption) -> HorizontalAlignment {
        switch option { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    private func frameAlignment(for option: TextAlignmentOption) -> Alignment {
        switch option { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}

private struct LauncherLinkRow: View {
    let app: LauncherApplication
    let configuration: WidgetConfigurationList

    var body: some View {
        HStack(spacing: 8) {
            if configuration.showIcon {
                WidgetIconView(app: app, style: configuration.iconStyle).frame(width: 20, height: 20)
            }
            Text(app.displayName)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(hex: app.textColorHex))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
    }
}

private struct WidgetIconView: View {
    let app: LauncherApplication
    let style: IconStyle

    var body: some View {
        Group {
            if let iconURL = getIconURL(fileName: app.iconFileName), let image = UIImage(contentsOfFile: iconURL.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: app.symbolName).resizable().scaledToFit().foregroundStyle(.orange).padding(2)
            }
        }.clipShape(.rect(cornerRadius: 5))
    }
    
    private func getIconURL(fileName: String?) -> URL? {
        guard let fileName = fileName, let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        return container.appendingPathComponent("DownloadedIcons").appendingPathComponent(fileName)
    }
}

struct StackLaunchWidget: Widget {
    let kind: String = "StackLaunchWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLauncherStackIntent.self, provider: LauncherProvider()) { entry in
            StackLaunchWidgetView(entry: entry)
        }
        .configurationDisplayName("StackLaunch")
        .description("Display your stacks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}