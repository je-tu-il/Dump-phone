import Foundation
import SwiftUI
import os

let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
let widgetConfigurationsKey = "widgetConfigurations"
let appLibraryKey = "globalAppLibrary"
let maxAppsPerStack = 10

nonisolated enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case standard
    case grayscale
    case liquidGlass
    var id: String { rawValue }
}

nonisolated struct LauncherApplication: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var urlScheme: String
    var symbolName: String
    var appStoreId: String?
    var iconRemoteURL: String?
    var iconFileName: String?
    var textColorHex: String
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
    var applicationIds: [UUID]
    var applications: [LauncherApplication]
    var itemLimit: Int
    var textAlignment: TextAlignmentOption
    var showIcon: Bool
    var backgroundColorHex: String
    var iconStyle: IconStyle

    var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(min(maxAppsPerStack, max(1, itemLimit))))
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r: Double
        let g: Double
        let b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

nonisolated enum SharedWidgetReader {
    private static let logger = Logger(subsystem: "app.rork.stacklaunch.widget", category: "SharedWidgetReader")

    static func configurations() -> [WidgetConfigurationList] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("App Group container '\(appGroupIdentifier)' is NOT available. Check entitlements and provisioning profile.")
            return []
        }
        let library: [LauncherApplication] = decodeOrEmpty([LauncherApplication].self, key: appLibraryKey, defaults: defaults)
        logger.info("Widget reader loaded \(library.count) library apps")
        let stacks: [WidgetConfigurationList] = decodeOrEmpty([WidgetConfigurationList].self, key: widgetConfigurationsKey, defaults: defaults)
        logger.info("Widget reader loaded \(stacks.count) stacks")
        return stacks.map { hydrate($0, library: library) }
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

    private static func hydrate(_ configuration: WidgetConfigurationList, library: [LauncherApplication]) -> WidgetConfigurationList {
        var copy = configuration
        copy.itemLimit = min(maxAppsPerStack, max(1, copy.itemLimit))
        copy.applicationIds = Array(copy.applicationIds.prefix(maxAppsPerStack))
        copy.applications = copy.applicationIds.compactMap { id in library.first(where: { $0.id == id }) ?? copy.applications.first(where: { $0.id == id }) }
        return copy
    }

    private static func decodeOrEmpty<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T where T: RangeReplaceableCollection {
        guard let data = defaults.data(forKey: key) else { return T() }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Decode failed for key '\(key)': \(error.localizedDescription)")
            return T()
        }
    }
}
