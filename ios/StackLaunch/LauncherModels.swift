import Combine
import Foundation
import SwiftUI

let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"

nonisolated struct LauncherApplication: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var urlScheme: String
    var symbolName: String

    init(id: UUID = UUID(), displayName: String, urlScheme: String, symbolName: String) {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.symbolName = symbolName
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

    init(id: UUID = UUID(), name: String, applications: [LauncherApplication], itemLimit: Int, textAlignment: TextAlignmentOption) {
        self.id = id
        self.name = name
        self.applications = applications
        self.itemLimit = itemLimit
        self.textAlignment = textAlignment
    }

    var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(max(1, itemLimit)))
    }
}

nonisolated enum KnownApplications {
    static let all: [LauncherApplication] = [
        LauncherApplication(displayName: "Messages", urlScheme: "messages://", symbolName: "message.fill"),
        LauncherApplication(displayName: "Calendar", urlScheme: "calshow://", symbolName: "calendar"),
        LauncherApplication(displayName: "Mail", urlScheme: "message://", symbolName: "envelope.fill"),
        LauncherApplication(displayName: "Phone", urlScheme: "tel://", symbolName: "phone.fill"),
        LauncherApplication(displayName: "Maps", urlScheme: "maps://", symbolName: "map.fill"),
        LauncherApplication(displayName: "Music", urlScheme: "music://", symbolName: "music.note"),
        LauncherApplication(displayName: "Instagram", urlScheme: "instagram://", symbolName: "camera.fill"),
        LauncherApplication(displayName: "Spotify", urlScheme: "spotify://", symbolName: "play.circle.fill"),
        LauncherApplication(displayName: "YouTube", urlScheme: "youtube://", symbolName: "play.rectangle.fill"),
        LauncherApplication(displayName: "Shortcuts", urlScheme: "shortcuts://", symbolName: "sparkles")
    ]
}

@MainActor
final class SharedConfigurationStore: ObservableObject {
    @Published var configurations: [WidgetConfigurationList] = []
    private let defaults: UserDefaults
    private let key = "widgetConfigurations"

    init(defaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
        load()
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) else {
            configurations = Self.sampleConfigurations
            save()
            return
        }
        configurations = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        defaults.set(data, forKey: key)
    }

    func addConfiguration() {
        configurations.append(WidgetConfigurationList(name: "Focus Stack", applications: Array(KnownApplications.all.prefix(4)), itemLimit: 4, textAlignment: .leading))
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
        WidgetConfigurationList(name: "Morning Launch", applications: Array(KnownApplications.all.prefix(5)), itemLimit: 4, textAlignment: .leading),
        WidgetConfigurationList(name: "Social Stack", applications: Array(KnownApplications.all[6...8]), itemLimit: 3, textAlignment: .center)
    ]
}
