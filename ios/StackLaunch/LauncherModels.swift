import Combine
import Foundation
import SwiftUI
import WidgetKit

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

    init(id: UUID = UUID(), displayName: String, urlScheme: String, symbolName: String = "app.fill", appStoreId: String? = nil, iconRemoteURL: String? = nil, iconFileName: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.symbolName = symbolName
        self.appStoreId = appStoreId
        self.iconRemoteURL = iconRemoteURL
        self.iconFileName = iconFileName
    }
}

nonisolated enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }
}

nonisolated struct WidgetConfigurationList: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var applications: [LauncherApplication]
    var itemLimit: Int
    var textAlignment: TextAlignmentOption
    var showIcon: Bool

    init(id: UUID = UUID(), name: String, applications: [LauncherApplication], itemLimit: Int, textAlignment: TextAlignmentOption, showIcon: Bool = true) {
        self.id = id
        self.name = name
        self.applications = applications
        self.itemLimit = itemLimit
        self.textAlignment = textAlignment
        self.showIcon = showIcon
    }

    var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(max(1, itemLimit)))
    }
}

@MainActor
enum SharedIconStorage {
    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static func iconsDirectoryURL() throws -> URL {
        guard let container = containerURL() else { throw URLError(.cannotCreateFile) }
        let directory = container.appendingPathComponent("DownloadedIcons", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func saveIcon(from remoteURL: URL, appStoreId: String) async throws -> String {
        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        let fileName = "app-icon-\(appStoreId).jpg"
        let destination = try iconsDirectoryURL().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return fileName
    }
}

nonisolated struct ITunesLookupResponse: Decodable {
    let resultCount: Int
    let results: [ITunesAppResult]
}

nonisolated struct ITunesAppResult: Decodable {
    let trackName: String
    let trackId: Int
    let artworkUrl512: String?
    let artworkUrl100: String?
    let trackViewUrl: String?
}

@MainActor
final class ITunesAppLookupService {
    func lookup(input: String) async throws -> LauncherApplication {
        let appId = Self.extractAppStoreId(from: input)
        guard !appId.isEmpty, let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
        guard let app = decoded.results.first else { throw URLError(.resourceUnavailable) }
        let iconURLString = app.artworkUrl512 ?? app.artworkUrl100
        var iconFileName: String?
        if let iconURLString, let iconURL = URL(string: iconURLString) {
            iconFileName = try await SharedIconStorage.saveIcon(from: iconURL, appStoreId: String(app.trackId))
        }
        return LauncherApplication(displayName: app.trackName, urlScheme: app.trackViewUrl ?? "https://apps.apple.com/app/id\(app.trackId)", symbolName: "app.fill", appStoreId: String(app.trackId), iconRemoteURL: iconURLString, iconFileName: iconFileName)
    }

    static func extractAppStoreId(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.allSatisfy({ $0.isNumber }) { return trimmed }
        if let range = trimmed.range(of: #"id(\d+)"#, options: .regularExpression) {
            return String(trimmed[range]).replacingOccurrences(of: "id", with: "")
        }
        return ""
    }
}

@MainActor
final class SharedConfigurationStore: ObservableObject {
    @Published var configurations: [WidgetConfigurationList] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
        load()
    }

    func load() {
        guard let data = defaults.data(forKey: widgetConfigurationsKey),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else {
            configurations = Self.sampleConfigurations
            save()
            return
        }
        configurations = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        defaults.set(data, forKey: widgetConfigurationsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addConfiguration() {
        configurations.append(WidgetConfigurationList(name: "Focus Stack", applications: Array(PredefinedAppsDatabase.all.prefix(4)).map(\.launcherApplication), itemLimit: 12, textAlignment: .leading))
        save()
    }

    func update(_ configuration: WidgetConfigurationList) {
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else { return }
        configurations[index] = configuration
        save()
    }

    func delete(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        if configurations.isEmpty { configurations = Self.sampleConfigurations }
        save()
    }

    static let sampleConfigurations: [WidgetConfigurationList] = [
        WidgetConfigurationList(name: "Morning Launch", applications: Array(PredefinedAppsDatabase.all.prefix(4)).map(\.launcherApplication), itemLimit: 8, textAlignment: .leading),
        WidgetConfigurationList(name: "Social Stack", applications: Array(PredefinedAppsDatabase.all.suffix(2)).map(\.launcherApplication), itemLimit: 6, textAlignment: .center)
    ]
}
