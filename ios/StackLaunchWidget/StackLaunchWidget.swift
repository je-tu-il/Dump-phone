import AppIntents
import SwiftUI
import WidgetKit

// MARK: - AppEntity pour la sélection de la pile
struct LauncherStackEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Pile de lancement"
    static var defaultQuery = LauncherStackQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: name)
    }
}

// MARK: - Requête d'entités pour le Widget
struct LauncherStackQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LauncherStackEntity] {
        let configs = SharedWidgetReader.configurations()
        return configs
            .filter { identifiers.contains($0.id.uuidString) }
            .map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [LauncherStackEntity] {
        let configs = SharedWidgetReader.configurations()
        AppGroupLogger.log("INTENT: suggestedEntities a trouvé \(configs.count) piles : \(configs.map(\.name).joined(separator: ", "))")
        return configs.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
    
    func defaultResult() async -> LauncherStackEntity? {
        let configs = SharedWidgetReader.configurations()
        return configs.first.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func entities(matching string: String) async throws -> [LauncherStackEntity] {
        let configs = SharedWidgetReader.configurations()
        return configs
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Intention de configuration du widget
struct SelectLauncherStackIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sélectionner la pile"
    static var description: IntentDescription = "Choisissez la pile d'applications à afficher sur ce widget."

    @Parameter(title: "Pile", default: nil)
    var stack: LauncherStackEntity?
}

// MARK: - Entrée de chronologie
struct LauncherEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfigurationList
}

// MARK: - Fournisseur de chronologie
struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: Date(), configuration: WidgetConfigurationList.defaultStack)
    }

    func snapshot(for intent: SelectLauncherStackIntent, in context: Context) async -> LauncherEntry {
        let config = SharedWidgetReader.configuration(id: intent.stack?.id)
        return LauncherEntry(date: Date(), configuration: config)
    }

    func timeline(for intent: SelectLauncherStackIntent, in context: Context) async -> Timeline<LauncherEntry> {
        let config = SharedWidgetReader.configuration(id: intent.stack?.id)
        AppGroupLogger.log("WIDGET: timeline générée pour '\(config.name)' avec \(config.visibleApplications.count) apps")
        return Timeline(entries: [LauncherEntry(date: Date(), configuration: config)], policy: .atEnd)
    }
}

// MARK: - Vue Principale du Widget
struct StackLaunchWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: LauncherEntry

    var configuration: WidgetConfigurationList {
        entry.configuration
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(configuration: configuration)
            case .systemMedium:
                MediumWidgetView(configuration: configuration)
            case .systemLarge, .systemExtraLarge:
                LargeWidgetView(configuration: configuration)
            @unknown default:
                MediumWidgetView(configuration: configuration)
            }
        }
        .containerBackground(Color(hex: configuration.backgroundColorHex), for: .widget)
    }
}

// MARK: - Vue Widget Petit (.systemSmall)
private struct SmallWidgetView: View {
    let configuration: WidgetConfigurationList

    private var apps: [LauncherApplication] {
        Array(configuration.visibleApplications.prefix(4))
    }

    private var primaryLaunchURL: URL? {
        apps.first?.widgetLaunchURL ?? URL(string: "stacklaunch://")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Entête
            HStack {
                Text(configuration.name)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.cyan.opacity(0.8))
            }

            if apps.isEmpty {
                VStack {
                    Spacer()
                    Text("Aucune app")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if apps.count <= 2 {
                VStack(spacing: 6) {
                    ForEach(apps) { app in
                        HStack(spacing: 8) {
                            if configuration.showIcon {
                                WidgetIconView(app: app, style: configuration.iconStyle)
                                    .frame(width: 22, height: 22)
                            }
                            Text(app.displayName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: app.textColorHex))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)))
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(apps) { app in
                        VStack(spacing: 4) {
                            if configuration.showIcon {
                                WidgetIconView(app: app, style: configuration.iconStyle)
                                    .frame(width: 26, height: 26)
                            }
                            Text(app.displayName)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: app.textColorHex))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .widgetURL(primaryLaunchURL)
    }
}

// MARK: - Vue Widget Moyen (.systemMedium)
private struct MediumWidgetView: View {
    let configuration: WidgetConfigurationList

    private var apps: [LauncherApplication] {
        configuration.visibleApplications
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Entête
            HStack {
                Text(configuration.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                Spacer()
                Text("\(apps.count) app\(apps.count > 1 ? "s" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            if apps.isEmpty {
                VStack {
                    Spacer()
                    Text("Aucune application dans cette pile")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(apps) { app in
                        if let url = app.widgetLaunchURL {
                            Link(destination: url) {
                                LauncherAppRow(app: app, configuration: configuration)
                            }
                        } else {
                            LauncherAppRow(app: app, configuration: configuration)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
    }
}

// MARK: - Vue Widget Grand (.systemLarge)
private struct LargeWidgetView: View {
    let configuration: WidgetConfigurationList

    private var apps: [LauncherApplication] {
        configuration.visibleApplications
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Entête
            HStack {
                Text(configuration.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                Spacer()
                Text("\(apps.count) app\(apps.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if apps.isEmpty {
                VStack {
                    Spacer()
                    Text("Aucune application configurée")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(apps) { app in
                        if let url = app.widgetLaunchURL {
                            Link(destination: url) {
                                LauncherAppRow(app: app, configuration: configuration, isLarge: true)
                            }
                        } else {
                            LauncherAppRow(app: app, configuration: configuration, isLarge: true)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

// MARK: - Bouton d'application cliquable
private struct LauncherAppRow: View {
    let app: LauncherApplication
    let configuration: WidgetConfigurationList
    var isLarge: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if configuration.showIcon {
                WidgetIconView(app: app, style: configuration.iconStyle)
                    .frame(width: isLarge ? 24 : 20, height: isLarge ? 24 : 20)
            }
            Text(app.displayName)
                .font(.system(size: isLarge ? 12 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: app.textColorHex))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, isLarge ? 9 : 7)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.12))
        )
    }
}

// MARK: - Affichage de l'icône
private struct WidgetIconView: View {
    let app: LauncherApplication
    let style: IconStyle

    var body: some View {
        iconBody
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .applyIconStyle(style)
    }

    @ViewBuilder
    private var iconBody: some View {
        if let iconURL = SharedWidgetReader.iconURL(fileName: app.iconFileName),
           let image = UIImage(contentsOfFile: iconURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.cyan.opacity(0.2)
                Image(systemName: app.symbolName.isEmpty ? "app.fill" : app.symbolName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.cyan)
                    .padding(3)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func applyIconStyle(_ style: IconStyle) -> some View {
        switch style {
        case .standard:
            self
        case .grayscale:
            self.grayscale(1.0)
        case .liquidGlass:
            self.opacity(0.9).overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Définition du WidgetKit
struct StackLaunchWidget: Widget {
    let kind: String = "StackLaunchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectLauncherStackIntent.self,
            provider: LauncherProvider()
        ) { entry in
            StackLaunchWidgetView(entry: entry)
        }
        .configurationDisplayName("StackLaunch")
        .description("Lancez vos applications favorites directement depuis votre écran d'accueil.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}