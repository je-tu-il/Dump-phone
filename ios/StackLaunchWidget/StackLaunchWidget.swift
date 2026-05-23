import AppIntents
import SwiftUI
import WidgetKit

let widgetAppGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"

// MARK: - Widget Data Reader Sécurisé & Allégé
struct WidgetDataReader {
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: widgetAppGroupIdentifier)
    }

    static func configurations() -> [WidgetConfigurationList] {
        guard let data = defaults?.data(forKey: "widgetConfigurations") else { return [] }
        do {
            return try JSONDecoder().decode([WidgetConfigurationList].self, from: data)
        } catch {
            return []
        }
    }
    
    static func configuration(id: String?) -> WidgetConfigurationList? {
        guard let id = id else { return configurations().first }
        return configurations().first(where: { $0.id.uuidString == id })
    }

    // OPTIMISATION: Suppression de fileExists qui surchargeait le thread de rendu.
    // UIImage retournera simplement nil si le fichier n'est pas là.
    static func getIconURL(fileName: String?) -> URL? {
        guard let fileName = fileName, !fileName.isEmpty,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetAppGroupIdentifier) else { 
            return nil 
        }
        return container.appendingPathComponent("DownloadedIcons").appendingPathComponent(fileName)
    }
}

// MARK: - App Intents & Entités
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
        WidgetDataReader.configurations()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func suggestedEntities() async throws -> [LauncherStackEntity] {
        let configs = WidgetDataReader.configurations()
        if configs.isEmpty {
            return [LauncherStackEntity(id: "empty_fallback", name: "⚠️ Create a stack in the app")]
        }
        return configs.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> LauncherStackEntity? {
        guard let first = WidgetDataReader.configurations().first else { return nil }
        return LauncherStackEntity(id: first.id.uuidString, name: first.name)
    }
}

struct SelectLauncherStackIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Launcher Stack"
    static var description = IntentDescription("Choose which launcher list this widget instance displays.")

    @Parameter(title: "Stack")
    var stack: LauncherStackEntity?
}

struct LauncherEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfigurationList?
}

struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now, configuration: WidgetDataReader.configurations().first)
    }

    func snapshot(for configuration: SelectLauncherStackIntent, in context: Context) async -> LauncherEntry {
        LauncherEntry(date: .now, configuration: WidgetDataReader.configuration(id: configuration.stack?.id))
    }

    func timeline(for configuration: SelectLauncherStackIntent, in context: Context) async -> Timeline<LauncherEntry> {
        let selected = WidgetDataReader.configuration(id: configuration.stack?.id)
        return Timeline(entries: [LauncherEntry(date: .now, configuration: selected)], policy: .after(.now.addingTimeInterval(300)))
    }
}

// MARK: - Vues du Widget (Optimisées pour le Render Server)
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
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.title)
                    .foregroundStyle(.gray)
                Text("Select a Stack")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
            }
            .padding()
            .containerBackground(Color(red: 0.05, green: 0.05, blue: 0.08), for: .widget)
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
                WidgetIconView(app: app, style: configuration.iconStyle)
                    .frame(width: 20, height: 20)
            }
            Text(app.displayName)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(hex: app.textColorHex))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
    }

    // OPTIMISATION: .ultraThinMaterial est trop lourd pour le Widget Server si répété.
    // Remplacé par des opacités simples qui imitent le rendu sans crasher le GPU.
    @ViewBuilder
    private var rowBackground: some View {
        if configuration.iconStyle == .liquidGlass {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        } else {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
        }
    }
}

private struct WidgetIconView: View {
    let app: LauncherApplication
    let style: IconStyle

    var body: some View {
        Group {
            if let iconURL = WidgetDataReader.getIconURL(fileName: app.iconFileName),
               let image = UIImage(contentsOfFile: iconURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: app.symbolName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.orange)
                    .padding(2)
            }
        }
        .grayscale(style == .grayscale ? 1 : 0)
        .padding(style == .liquidGlass ? 2 : 0)
        .background(style == .liquidGlass ? Color.white.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 6))
        .overlay {
            if style == .liquidGlass { 
                RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 0.5) 
            }
        }
        .clipShape(.rect(cornerRadius: 5))
    }
}

struct StackLaunchWidget: Widget {
    let kind: String = "StackLaunchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLauncherStackIntent.self, provider: LauncherProvider()) { entry in
            StackLaunchWidgetView(entry: entry)
        }
        .configurationDisplayName("StackLaunch")
        .description("Display your application stacks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}