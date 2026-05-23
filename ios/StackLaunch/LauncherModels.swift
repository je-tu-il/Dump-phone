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
    public var iconRemoteURL: String?
    public var iconFileName: String?
    public var textColorHex: String

    public init(id: UUID = UUID(), displayName: String, urlScheme: String, symbolName: String = "app.fill", appStoreId: String? = nil, iconRemoteURL: String? = nil, iconFileName: String? = nil, textColorHex: String = "#FFFFFF") {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.symbolName = symbolName
        self.appStoreId = appStoreId
        self.iconRemoteURL = iconRemoteURL
        self.iconFileName = iconFileName
        self.textColorHex = textColorHex
    }
}

public enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    public var id: String { rawValue }
    public var title: String {
        switch self { case .leading: return "Left"; case .center: return "Center"; case .trailing: return "Right" }
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
        self.itemLimit = min(max(1, itemLimit), maxAppsPerStack)
        self.textAlignment = textAlignment
        self.showIcon = showIcon
        self.backgroundColorHex = backgroundColorHex
        self.iconStyle = iconStyle
    }
    
    public var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(min(maxAppsPerStack, max(1, itemLimit))))
    }
}

@MainActor
public final class SharedConfigurationStore: ObservableObject {
    @Published public var configurations: [WidgetConfigurationList] = []
    @Published public var library: [LauncherApplication] = []
    @Published public var isAppGroupAvailable: Bool = true
    
    private let defaults: UserDefaults

    public init() {
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.defaults = groupDefaults
            self.isAppGroupAvailable = true
        } else {
            self.defaults = .standard
            self.isAppGroupAvailable = false
        }
        load()
    }

    public func load() {
        if let data = defaults.data(forKey: appLibraryKey) {
            do {
                library = try JSONDecoder().decode([LauncherApplication].self, from: data)
            } catch { print("Erreur de décodage Library: \(error)") }
        }
        
        if let data = defaults.data(forKey: widgetConfigurationsKey) {
            do {
                configurations = try JSONDecoder().decode([WidgetConfigurationList].self, from: data)
            } catch { print("Erreur de décodage Configurations: \(error)") }
        }
    }

    public func save() {
        do {
            let libData = try JSONEncoder().encode(library)
            defaults.set(libData, forKey: appLibraryKey)
            
            let confData = try JSONEncoder().encode(configurations)
            defaults.set(confData, forKey: widgetConfigurationsKey)
            
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Erreur d'encodage lors de la sauvegarde: \(error)")
        }
    }

    public func addToLibrary(_ app: LauncherApplication) {
        if !library.contains(where: { $0.appStoreId == app.appStoreId && $0.displayName == app.displayName }) {
            var newApp = app
            newApp.id = UUID()
            library.append(newApp)
            library.sort { $0.displayName < $1.displayName }
            save()
        }
    }

    public func addBulkToLibrary(_ apps: [LauncherApplication]) {
        for app in apps { addToLibrary(app) }
    }

    public func deleteFromLibrary(at offsets: IndexSet) {
        library.remove(atOffsets: offsets)
        save()
    }
    
    public func updateLibraryApp(_ app: LauncherApplication) {
        if let index = library.firstIndex(where: { $0.id == app.id }) {
            library[index] = app
            save()
        }
    }

    public func addConfiguration() {
        let selected = Array(library.prefix(4))
        configurations.append(WidgetConfigurationList(name: "Nouvelle Pile", applications: selected, itemLimit: 4, textAlignment: .leading))
        save()
    }

    public func update(_ configuration: WidgetConfigurationList) {
        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            var copy = configuration
            copy.applicationIds = Array(copy.applicationIds.prefix(maxAppsPerStack))
            copy.applications = copy.applicationIds.compactMap { id in library.first(where: { $0.id == id }) ?? copy.applications.first(where: { $0.id == id }) }
            configurations[index] = copy
            save()
        }
    }

    public func delete(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        save()
    }
}