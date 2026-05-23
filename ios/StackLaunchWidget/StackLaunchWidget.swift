import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Data Reader Sécurisé
struct WidgetDataReader {
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func configurations() -> [WidgetConfigurationList] {
        SharedLogger.log("WidgetDataReader reading configs")
        guard let data = defaults?.data(forKey: widgetConfigurationsKey) else {
            SharedLogger.log("Err: No data for key \(widgetConfigurationsKey)")
            return []
        }
        do {
            let decoded = try JSONDecoder().decode([WidgetConfigurationList].self, from: data)
            SharedLogger.log("WidgetDataReader decoded \(decoded.count) configs")
            return decoded
        } catch {
            SharedLogger.log("WidgetDataReader Decode Err: \(error.localizedDescription)")
            return []
        }
    }
    
    static func configuration(id: String?) -> WidgetConfigurationList? {
        guard let id = id else { return configurations().first }
        return configurations().first(where: { $0.id.uuidString == id })
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
        SharedLogger.log("Intent requested suggestedEntities")
        let configs = WidgetDataReader.configurations()
        if configs.isEmpty {
            SharedLogger.log("Intent found no configs, returning fallback")
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
        SharedLogger.log("Widget timeline requested")
        let selected = WidgetDataReader.configuration(id: configuration.stack?.id)
        if selected == nil { SharedLogger.log("Timeline selected config is nil") }
        return Timeline(entries: [LauncherEntry(date: .now, configuration: selected)], policy: .after(.now.addingTimeInterval(300)))
    }
}

// MARK: - Vues du Widget
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
                Text("Diagnostics")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                ScrollView {
                    Text(SharedLogger.read())
                        .font(.system(size: 8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .containerBackground(Color(red: 0.02, green: 0.04, blue: 0.08), for: .widget)
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

    @ViewBuilder
    private var rowBackground: some View {
        if configuration.iconStyle == .liquidGlass {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.26), lineWidth: 0.8))
        } else {
            RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.10))
        }
    }
}

private struct WidgetIconView: View {
    let app: LauncherApplication
    let style: IconStyle

    var body: some View {
        Group {
            if let image = loadImage() {
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
        .background(style == .liquidGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
        .overlay {
            if style == .liquidGlass { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.36), lineWidth: 0.7) }
        }
        .clipShape(.rect(cornerRadius: 5))
    }

    private func loadImage() -> UIImage? {
        guard let fileName = app.iconFileName, let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        let url = container.appendingPathComponent("DownloadedIcons").appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
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