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

// MARK: - Intention d'ouverture d'application depuis le widget
struct LaunchAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir l'application"
    static var description: IntentDescription = "Ouvre l'application sélectionnée depuis le widget."
    static var openAppWhenRun: Bool = true

    @Parameter(title: "URL Cible")
    var targetURLString: String?

    @Parameter(title: "Bundle ID")
    var bundleID: String?

    @Parameter(title: "Nom de l'application")
    var appName: String?

    init() {}

    init(targetURLString: String?, bundleID: String?, appName: String?) {
        self.targetURLString = targetURLString
        self.bundleID = bundleID
        self.appName = appName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppGroupLogger.log("INTENT: LaunchAppIntent déclenché depuis widget pour '\(appName ?? "inconnu")'")
        if let defaults = AppGroupHelper.sharedDefaults {
            defaults.set(targetURLString, forKey: "pendingLaunchURL")
            defaults.set(bundleID, forKey: "pendingLaunchBundleID")
            defaults.synchronize()
        }
        return .result()
    }
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
                // 1 colonne pour 1 ou 2 apps : texte agrandi
                VStack(spacing: apps.count == 1 ? 8 : 6) {
                    ForEach(apps) { app in
                        Button(intent: LaunchAppIntent(
                            targetURLString: app.parsedURL?.absoluteString,
                            bundleID: app.effectiveBundleIdentifier,
                            appName: app.displayName
                        )) {
                            HStack(spacing: 8) {
                                if configuration.showIcon {
                                    WidgetIconView(app: app, style: configuration.iconStyle)
                                        .frame(width: apps.count == 1 ? 26 : 22, height: apps.count == 1 ? 26 : 22)
                                }
                                Text(app.displayName)
                                    .font(.system(size: apps.count == 1 ? 14 : 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: app.textColorHex))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, apps.count == 1 ? 10 : 7)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // 3 ou 4 apps : grille 2 colonnes avec texte net et bien visible
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(apps) { app in
                        Button(intent: LaunchAppIntent(
                            targetURLString: app.parsedURL?.absoluteString,
                            bundleID: app.effectiveBundleIdentifier,
                            appName: app.displayName
                        )) {
                            VStack(spacing: 4) {
                                if configuration.showIcon {
                                    WidgetIconView(app: app, style: configuration.iconStyle)
                                        .frame(width: 24, height: 24)
                                }
                                Text(app.displayName)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: app.textColorHex))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
    }
}

// MARK: - Mode de disposition et taille des lignes
private enum AppRowLayoutMode {
    case singleColumnLarge   // 1 colonne, très grand (ex: 1-2 apps Medium, 1-3 apps Large)
    case singleColumnMedium  // 1 colonne, grand (ex: 3-4 apps Medium, 4-6 apps Large)
    case twoColumnsStandard  // 2 colonnes, standard (ex: 5-8 apps Medium, 7-12 apps Large)
    case twoColumnsDense     // 2 colonnes, dense (ex: 13-20 apps Large)

    var fontSize: CGFloat {
        switch self {
        case .singleColumnLarge: return 16
        case .singleColumnMedium: return 13.5
        case .twoColumnsStandard: return 11.5
        case .twoColumnsDense: return 10
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .singleColumnLarge: return .bold
        case .singleColumnMedium, .twoColumnsStandard, .twoColumnsDense: return .semibold
        }
    }

    var iconDimension: CGFloat {
        switch self {
        case .singleColumnLarge: return 28
        case .singleColumnMedium: return 24
        case .twoColumnsStandard: return 20
        case .twoColumnsDense: return 16
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .singleColumnLarge: return 12
        case .singleColumnMedium: return 10
        case .twoColumnsStandard: return 8
        case .twoColumnsDense: return 6
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .singleColumnLarge: return 9
        case .singleColumnMedium: return 7
        case .twoColumnsStandard: return 6
        case .twoColumnsDense: return 3.5
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .singleColumnLarge: return 12
        case .singleColumnMedium: return 10
        case .twoColumnsStandard: return 9
        case .twoColumnsDense: return 8
        }
    }
}

// MARK: - Vue Widget Moyen (.systemMedium)
private struct MediumWidgetView: View {
    let configuration: WidgetConfigurationList

    private var apps: [LauncherApplication] {
        Array(configuration.visibleApplications.prefix(8))
    }

    private var isSingleColumn: Bool {
        apps.count <= 4
    }

    private var rowMode: AppRowLayoutMode {
        if apps.count <= 2 {
            return .singleColumnLarge
        } else if apps.count <= 4 {
            return .singleColumnMedium
        } else {
            return .twoColumnsStandard
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSingleColumn ? 6 : 4) {
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
            } else if isSingleColumn {
                // 1 colonne adaptée au nombre d'apps avec texte agrandi
                VStack(spacing: apps.count <= 2 ? 8 : 5) {
                    ForEach(apps) { app in
                        if let url = app.widgetLaunchURL {
                            Link(destination: url) {
                                LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                            }
                        } else {
                            LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                        }
                    }
                }
            } else {
                // 2 colonnes quand 5 à 8 applications
                let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(apps) { app in
                        if let url = app.widgetLaunchURL {
                            Link(destination: url) {
                                LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                            }
                        } else {
                            LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(isSingleColumn ? 10 : 8)
    }
}

// MARK: - Vue Widget Grand (.systemLarge)
private struct LargeWidgetView: View {
    let configuration: WidgetConfigurationList

    private var apps: [LauncherApplication] {
        Array(configuration.visibleApplications.prefix(20))
    }

    private var isSingleColumn: Bool {
        apps.count <= 6
    }

    private var rowMode: AppRowLayoutMode {
        if apps.count <= 3 {
            return .singleColumnLarge
        } else if apps.count <= 6 {
            return .singleColumnMedium
        } else if apps.count <= 12 {
            return .twoColumnsStandard
        } else {
            return .twoColumnsDense
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSingleColumn ? 6 : (apps.count > 12 ? 3 : 5)) {
            // Entête
            HStack {
                Text(configuration.name)
                    .font(isSingleColumn ? .headline.weight(.bold) : .subheadline.weight(.bold))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                Spacer()
                Text("\(apps.count) app\(apps.count > 1 ? "s" : "")")
                    .font(.caption2)
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
            } else if isSingleColumn {
                // 1 colonne adaptée au nombre d'apps (jusqu'à 6 apps) avec texte agrandi
                VStack(spacing: apps.count <= 3 ? 10 : 6) {
                    ForEach(apps) { app in
                        if let url = app.widgetLaunchURL {
                            Link(destination: url) {
                                LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                            }
                        } else {
                            LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                        }
                    }
                }
            } else {
                // 2 colonnes (de 7 à 20 apps)
                let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
                LazyVGrid(columns: columns, spacing: apps.count > 12 ? 3 : 5) {
                    ForEach(apps) { app in
                        if let url = app.widgetLaunchURL {
                            Link(destination: url) {
                                LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                            }
                        } else {
                            LauncherAppRow(app: app, configuration: configuration, mode: rowMode)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(apps.count > 12 ? 8 : 10)
    }
}

// MARK: - Bouton d'application cliquable
private struct LauncherAppRow: View {
    let app: LauncherApplication
    let configuration: WidgetConfigurationList
    var mode: AppRowLayoutMode = .twoColumnsStandard

    var body: some View {
        HStack(spacing: mode == .twoColumnsDense ? 6 : 8) {
            if configuration.showIcon {
                WidgetIconView(app: app, style: configuration.iconStyle)
                    .frame(width: mode.iconDimension, height: mode.iconDimension)
            }
            Text(app.displayName)
                .font(.system(size: mode.fontSize, weight: mode.fontWeight, design: .rounded))
                .foregroundStyle(Color(hex: app.textColorHex))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, mode.horizontalPadding)
        .padding(.vertical, mode.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: mode.cornerRadius)
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