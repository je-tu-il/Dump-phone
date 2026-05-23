import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Lecteur Widget
struct WidgetDataReader {
    static func configurations() -> [WidgetConfigurationList] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetConfigurationsKey),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else {
            return []
        }
        return decoded
    }

    static func getIconURL(fileName: String?) -> URL? {
        guard let fileName = fileName,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        return container.appendingPathComponent("DownloadedIcons").appendingPathComponent(fileName)
    }
}

// MARK: - Widget
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

// Le reste des structs (Provider, View, etc.) reste inchangé mais doit utiliser AppGroupLogger.log()