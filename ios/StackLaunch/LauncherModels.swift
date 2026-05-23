import Combine
import Foundation
import ImageIO
import SwiftUI
import UIKit
import WidgetKit

let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
let widgetConfigurationsKey = "widgetConfigurations"
let appLibraryKey = "globalAppLibrary"
let maxAppsPerStack = 10

// MARK: - Modèles de données
nonisolated enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case standard, grayscale, liquidGlass
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

nonisolated struct LauncherApplication: Codable, Identifiable, Hashable {
    var id: UUID // 'var' obligatoire pour forcer le rafraîchissement UI
    var displayName: String
    var urlScheme: String
    var symbolName: String
    var appStoreId: String?
    var iconRemoteURL: String?
    var iconFileName: String?
    var textColorHex: String

    init(id: UUID = UUID(), displayName: String, urlScheme: String, symbolName: String = "app.fill", appStoreId: String? = nil, iconRemoteURL: String? = nil, iconFileName: String? = nil, textColorHex: String = "#FFFFFF") {
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

nonisolated enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var title: String {
        switch self { case .leading: return "Left"; case .center: return "Center"; case .trailing: return "Right" }
    }
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

    init(id: UUID = UUID(), name: String, applicationIds: [UUID] = [], applications: [LauncherApplication] = [], itemLimit: Int = 4, textAlignment: TextAlignmentOption = .leading, showIcon: Bool = true, backgroundColorHex: String = "#07131F", iconStyle: IconStyle = .standard) {
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
    
    var visibleApplications: [LauncherApplication] {
        Array(applications.prefix(min(maxAppsPerStack, max(1, itemLimit))))
    }
}

// MARK: - Helper de lecture partagée (Utilisé par le Widget)
struct SharedWidgetReader {
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func configurations() -> [WidgetConfigurationList] {
        guard let data = defaults?.data(forKey: widgetConfigurationsKey) else { return [] }
        do {
            return try JSONDecoder().decode([WidgetConfigurationList].self, from: data)
        } catch {
            print("Widget Reader Error: \(error)")
            return []
        }
    }
    
    static func configuration(id: String?) -> WidgetConfigurationList? {
        guard let id = id else { return configurations().first }
        return configurations().first(where: { $0.id.uuidString == id })
    }

    static func getIconURL(fileName: String?) -> URL? {
        guard let fileName = fileName,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        return container.appendingPathComponent("DownloadedIcons").appendingPathComponent(fileName)
    }
}

// MARK: - Store Principal (Utilisé par l'App)
@MainActor
final class SharedConfigurationStore: ObservableObject {
    @Published var configurations: [WidgetConfigurationList] = []
    @Published var library: [LauncherApplication] = []
    @Published var isAppGroupAvailable: Bool = true
    
    private let defaults: UserDefaults

    init() {
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.defaults = groupDefaults
            self.isAppGroupAvailable = true
        } else {
            print("🚨 ERREUR CRITIQUE: App Group non disponible. Le widget ne fonctionnera pas.")
            self.defaults = .standard
            self.isAppGroupAvailable = false
        }
        load()
    }

    func load() {
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

    func save() {
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

    func addToLibrary(_ app: LauncherApplication) {
        if !library.contains(where: { $0.appStoreId == app.appStoreId && $0.displayName == app.displayName }) {
            var newApp = app
            newApp.id = UUID() // Force SwiftUI à voir ceci comme un nouvel objet
            library.append(newApp)
            library.sort { $0.displayName < $1.displayName }
            save()
        }
    }

    func addBulkToLibrary(_ apps: [LauncherApplication]) {
        for app in apps { addToLibrary(app) }
    }

    func deleteFromLibrary(at offsets: IndexSet) {
        library.remove(atOffsets: offsets)
        save()
    }
    
    func updateLibraryApp(_ app: LauncherApplication) {
        if let index = library.firstIndex(where: { $0.id == app.id }) {
            library[index] = app
            save()
        }
    }

    func addConfiguration() {
        let selected = Array(library.prefix(4))
        configurations.append(WidgetConfigurationList(name: "Nouvelle Pile", applications: selected, itemLimit: 4, textAlignment: .leading))
        save()
    }

    func update(_ configuration: WidgetConfigurationList) {
        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            var copy = configuration
            copy.applicationIds = Array(copy.applicationIds.prefix(maxAppsPerStack))
            copy.applications = copy.applicationIds.compactMap { id in library.first(where: { $0.id == id }) ?? copy.applications.first(where: { $0.id == id }) }
            configurations[index] = copy
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        save()
    }
}