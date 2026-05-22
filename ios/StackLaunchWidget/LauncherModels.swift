import Foundation

let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
let widgetConfigurationsKey = "widgetConfigurations"

nonisolated struct LauncherApplication: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var urlScheme: String
    var symbolName: String
    var appStoreId: String?
    var iconRemoteURL: String?
    var iconFileName: String?
}

nonisolated enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case leading
    case center
    case trailing
    var id: String { rawValue }
}

nonisolated struct WidgetConfigurationList: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var applications: [LauncherApplication]
    var itemLimit: Int
    var textAlignment: TextAlignmentOption
    var showIcon: Bool

    var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(max(1, itemLimit)))
    }
}

nonisolated enum SharedWidgetReader {
    static func configurations() -> [WidgetConfigurationList] {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: widgetConfigurationsKey),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else {
            return []
        }
        return decoded
    }

    static func configuration(id: String?) -> WidgetConfigurationList? {
        let all = configurations()
        guard let id, let uuid = UUID(uuidString: id) else { return all.first }
        return all.first(where: { $0.id == uuid }) ?? all.first
    }

    static func iconURL(fileName: String?) -> URL? {
        guard let fileName,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        return container.appendingPathComponent("DownloadedIcons", isDirectory: true).appendingPathComponent(fileName)
    }
}
