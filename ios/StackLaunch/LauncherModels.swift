import Combine
import Foundation
import ImageIO
import SwiftUI
import UIKit
import WidgetKit

public let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
public let widgetConfigurationsKey = "widgetConfigurations"
public let appLibraryKey = "globalAppLibrary"
public let maxAppsPerStack = 10

// MARK: - Logger Partagé (Accessible par App et Widget)
public struct AppGroupLogger {
    public static func log(_ message: String) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        let logFile = container.appendingPathComponent("stacklaunch_debug.txt")
        let entry = "[\(Date().formatted(date: .omitted, time: .standard))] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
                }
            } else { try? data.write(to: logFile) }
        }
    }
    
    public static func read() -> String {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return "Err: No Container" }
        return (try? String(contentsOf: container.appendingPathComponent("stacklaunch_debug.txt"))) ?? "No logs."
    }
    
    public static func clear() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        try? FileManager.default.removeItem(at: container.appendingPathComponent("stacklaunch_debug.txt"))
    }
}

// MARK: - Modèles
public enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case standard, grayscale, liquidGlass
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct LauncherApplication: Codable, Identifiable, Hashable {
    public var id: UUID
    public var displayName: String
    public var urlScheme: String
    public var symbolName: String
    public var appStoreId: String?
    public var iconFileName: String?
    public var textColorHex: String

    public init(id: UUID = UUID(), displayName: String, urlScheme: String, symbolName: String = "app.fill", appStoreId: String? = nil, iconFileName: String? = nil, textColorHex: String = "#FFFFFF") {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.symbolName = symbolName
        self.appStoreId = appStoreId
        self.iconFileName = iconFileName
        self.textColorHex = textColorHex
    }
}

public struct WidgetConfigurationList: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var applicationIds: [UUID]
    public var applications: [LauncherApplication]
    public var itemLimit: Int
    public var textAlignment: TextAlignmentOption
    public var showIcon: Bool
    public var backgroundColorHex: String
    public var iconStyle: IconStyle

    public init(id: UUID = UUID(), name: String, applicationIds: [UUID] = [], applications: [LauncherApplication] = [], itemLimit: Int = 4, textAlignment: TextAlignmentOption = .leading, showIcon: Bool = true, backgroundColorHex: String = "#07131F", iconStyle: IconStyle = .standard) {
        self.id = id
        self.name = name
        self.applicationIds = applicationIds
        self.applications = applications
        self.itemLimit = itemLimit
        self.textAlignment = textAlignment
        self.showIcon = showIcon
        self.backgroundColorHex = backgroundColorHex
        self.iconStyle = iconStyle
    }
    
    public var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(min(maxAppsPerStack, max(1, itemLimit))))
    }
}

public enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    public var id: String { rawValue }
    public var title: String {
        switch self { case .leading: return "Left"; case .center: return "Center"; case .trailing: return "Right" }
    }
}

// MARK: - Store (App uniquement)
@MainActor
public final class SharedConfigurationStore: ObservableObject {
    @Published public var configurations: [WidgetConfigurationList] = []
    @Published public var library: [LauncherApplication] = []
    
    public init() { load() }

    public func load() {
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            if let data = defaults.data(forKey: appLibraryKey) { library = (try? JSONDecoder().decode([LauncherApplication].self, from: data)) ?? [] }
            if let data = defaults.data(forKey: widgetConfigurationsKey) { configurations = (try? JSONDecoder().decode([WidgetConfigurationList].self, from: data)) ?? [] }
        }
    }

    public func save() {
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            if let lib = try? JSONEncoder().encode(library) { defaults.set(lib, forKey: appLibraryKey) }
            if let conf = try? JSONEncoder().encode(configurations) { defaults.set(conf, forKey: widgetConfigurationsKey) }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    public func addToLibrary(_ app: LauncherApplication) {
        var newApp = app
        newApp.id = UUID()
        library.append(newApp)
        save()
    }
}