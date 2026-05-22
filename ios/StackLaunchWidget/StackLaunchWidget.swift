import AppIntents
import SwiftUI
import WidgetKit

nonisolated struct LauncherStackEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Launcher Stack"
    static var defaultQuery = LauncherStackQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

nonisolated struct LauncherStackQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LauncherStackEntity] {
        SharedWidgetReader.configurations()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func suggestedEntities() async throws -> [LauncherStackEntity] {
        SharedWidgetReader.configurations().map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> LauncherStackEntity? {
        SharedWidgetReader.configurations().first.map { LauncherStackEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

nonisolated struct SelectLauncherStackIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Launcher Stack"
    static var description = IntentDescription("Choose which launcher list this widget instance displays.")

    @Parameter(title: "Stack")
    var stack: LauncherStackEntity?
}

nonisolated struct LauncherEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfigurationList?
}

nonisolated struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now, configuration: SharedWidgetReader.configurations().first)
    }

    func snapshot(for configuration: SelectLauncherStackIntent, in context: Context) async -> LauncherEntry {
        LauncherEntry(date: .now, configuration: SharedWidgetReader.configuration(id: configuration.stack?.id))
    }

    func timeline(for configuration: SelectLauncherStackIntent, in context: Context) async -> Timeline<LauncherEntry> {
        let selected = SharedWidgetReader.configuration(id: configuration.stack?.id)
        return Timeline(entries: [LauncherEntry(date: .now, configuration: selected)], policy: .after(.now.addingTimeInterval(300)))
    }
}

struct StackLaunchWidgetView: View {
    let entry: LauncherEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.08), Color(red: 0.00, green: 0.16, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let configuration = entry.configuration {
                VStack(alignment: horizontalAlignment(for: configuration.textAlignment), spacing: 7) {
                    Text(configuration.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity, alignment: frameAlignment(for: configuration.textAlignment))
                    ForEach(configuration.visibleApplications) { app in
                        if let url = URL(string: app.urlScheme) {
                            Link(destination: url) {
                                HStack(spacing: 8) {
                                    if configuration.showIcon {
                                        WidgetIconView(app: app)
                                            .frame(width: 20, height: 20)
                                    }
                                    Text(app.displayName)
                                        .font(.system(.callout, design: .rounded, weight: .semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.white.opacity(0.10), in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Create a stack in StackLaunch")
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
                .padding()
            }
        }
    }

    private func horizontalAlignment(for option: TextAlignmentOption) -> HorizontalAlignment {
        switch option {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func frameAlignment(for option: TextAlignmentOption) -> Alignment {
        switch option {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

private struct WidgetIconView: View {
    let app: LauncherApplication

    var body: some View {
        Group {
            if let iconURL = SharedWidgetReader.iconURL(fileName: app.iconFileName),
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
        .clipShape(.rect(cornerRadius: 5))
    }
}

struct StackLaunchWidget: Widget {
    let kind: String = "StackLaunchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLauncherStackIntent.self, provider: LauncherProvider()) { entry in
            StackLaunchWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("StackLaunch")
        .description("Display one of your saved launcher stacks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
