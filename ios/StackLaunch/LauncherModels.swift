import Combine
import Foundation
import ImageIO
import SwiftUI
import UIKit
import WidgetKit

public let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
public let widgetConfigurationsKey = "widgetConfigurations"
public let appLibraryKey = "globalAppLibrary"
public let snapshotFileName = "stacklaunch_data.json"
public let maxAppsPerStack = 10

// MARK: - Logger partagé pour le diagnostic
public struct AppGroupLogger {
    public static func log(_ message: String) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        let logFile = container.appendingPathComponent("stacklaunch_debug.txt")
        let entry = "[\(Date().formatted(date: .omitted, time: .standard))] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
    
    public static func read() -> String {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return "App Group container indisponible sur ce périphérique."
        }
        let logFile = container.appendingPathComponent("stacklaunch_debug.txt")
        return (try? String(contentsOf: logFile, encoding: .utf8)) ?? "Aucun log enregistré."
    }
    
    public static func clear() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        try? FileManager.default.removeItem(at: container.appendingPathComponent("stacklaunch_debug.txt"))
    }
}

// MARK: - Options de style
public enum IconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard, grayscale, liquidGlass
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .grayscale: return "Gris"
        case .liquidGlass: return "Verre"
        }
    }
}

public enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading, center, trailing
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .leading: return "Gauche"
        case .center: return "Centre"
        case .trailing: return "Droite"
        }
    }
}

// MARK: - Modèle d'application
public struct LauncherApplication: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String
    public var urlScheme: String
    public var symbolName: String
    public var appStoreId: String?
    public var iconRemoteURL: String?
    public var iconFileName: String?
    public var textColorHex: String

    public init(
        id: UUID = UUID(),
        displayName: String,
        urlScheme: String,
        symbolName: String = "app.fill",
        appStoreId: String? = nil,
        iconRemoteURL: String? = nil,
        iconFileName: String? = nil,
        textColorHex: String = "#FFFFFF"
    ) {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.symbolName = symbolName
        self.appStoreId = appStoreId
        self.iconRemoteURL = iconRemoteURL
        self.iconFileName = iconFileName
        self.textColorHex = textColorHex
    }

    public var parsedURL: URL? {
        let trimmed = urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed) {
            return direct
        }
        if !trimmed.contains("://") && !trimmed.contains(":") {
            return URL(string: "\(trimmed)://")
        }
        return nil
    }
}

// MARK: - Modèle de Pile de Widget
public struct WidgetConfigurationList: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var applicationIds: [UUID]
    public var applications: [LauncherApplication]
    public var itemLimit: Int
    public var textAlignment: TextAlignmentOption
    public var showIcon: Bool
    public var backgroundColorHex: String
    public var iconStyle: IconStyle

    public init(
        id: UUID = UUID(),
        name: String,
        applicationIds: [UUID] = [],
        applications: [LauncherApplication] = [],
        itemLimit: Int = 4,
        textAlignment: TextAlignmentOption = .leading,
        showIcon: Bool = true,
        backgroundColorHex: String = "#07131F",
        iconStyle: IconStyle = .standard
    ) {
        self.id = id
        self.name = name
        let resolvedAppIds = applicationIds.isEmpty ? applications.map(\.id) : applicationIds
        self.applicationIds = resolvedAppIds
        self.applications = applications
        self.itemLimit = min(max(1, itemLimit), maxAppsPerStack)
        self.textAlignment = textAlignment
        self.showIcon = showIcon
        self.backgroundColorHex = backgroundColorHex
        self.iconStyle = iconStyle
    }
    
    public var visibleApplications: [LauncherApplication] {
        let count = min(maxAppsPerStack, max(1, itemLimit))
        return Array(applications.prefix(count))
    }

    public static var defaultStack: WidgetConfigurationList {
        let defaults = PredefinedAppsDatabase.defaultFavorites
        return WidgetConfigurationList(
            name: "Favoris",
            applicationIds: defaults.map(\.id),
            applications: defaults,
            itemLimit: 4,
            textAlignment: .leading,
            showIcon: true,
            backgroundColorHex: "#0D1826",
            iconStyle: .standard
        )
    }
}

// MARK: - Snapshot partagé (fichier JSON pour robustesse App Group)
public struct SharedSnapshot: Codable, Sendable {
    public let library: [LauncherApplication]
    public let configurations: [WidgetConfigurationList]
    public let updatedAt: Date

    public init(library: [LauncherApplication], configurations: [WidgetConfigurationList], updatedAt: Date = Date()) {
        self.library = library
        self.configurations = configurations
        self.updatedAt = updatedAt
    }
}

// MARK: - Extension Couleur Hex
extension Color {
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
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

    public func hexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

// MARK: - Stockage des icônes partagées
@MainActor
public enum SharedIconStorage {
    public static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    public static func iconsDirectoryURL() throws -> URL {
        guard let container = containerURL() else { throw URLError(.cannotCreateFile) }
        let directory = container.appendingPathComponent("DownloadedIcons", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func saveIcon(from remoteURL: URL, appStoreId: String) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        guard let downsampled = downsample(imageData: data, maxPixelSize: 96) else { throw URLError(.cannotDecodeContentData) }
        let fileName = "app-icon-\(appStoreId).jpg"
        let destination = try iconsDirectoryURL().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try downsampled.write(to: destination, options: .atomic)
        AppGroupLogger.log("APP: Icône sauvegardée sous \(fileName)")
        return fileName
    }

    private static func downsample(imageData: Data, maxPixelSize: CGFloat) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(imageData as CFData, options) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72)
    }
}

// MARK: - Service de recherche App Store iTunes
public struct ITunesLookupResponse: Decodable {
    let results: [ITunesAppResult]
}

public struct ITunesAppResult: Decodable {
    let trackName: String
    let trackId: Int
    let artworkUrl512: String?
    let artworkUrl100: String?
    let trackViewUrl: String?
}

@MainActor
public final class ITunesAppLookupService {
    public init() {}
    
    public func lookup(input: String) async throws -> LauncherApplication {
        let appId = Self.extractAppStoreId(from: input)
        guard !appId.isEmpty, let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)") else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else { throw URLError(.badServerResponse) }
        let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
        guard let app = decoded.results.first else { throw URLError(.resourceUnavailable) }
        
        let iconURLString = app.artworkUrl512 ?? app.artworkUrl100
        var iconFileName: String?
        if let iconURLString, let iconURL = URL(string: iconURLString) {
            iconFileName = try? await SharedIconStorage.saveIcon(from: iconURL, appStoreId: String(app.trackId))
        }
        return LauncherApplication(
            displayName: app.trackName,
            urlScheme: app.trackViewUrl ?? "https://apps.apple.com/app/id\(app.trackId)",
            appStoreId: String(app.trackId),
            iconRemoteURL: iconURLString,
            iconFileName: iconFileName
        )
    }

    public static func extractAppStoreId(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.allSatisfy({ $0.isNumber }) { return trimmed }
        if let range = trimmed.range(of: #"id(\d+)"#, options: .regularExpression) {
            return String(trimmed[range]).replacingOccurrences(of: "id", with: "")
        }
        return ""
    }

    public func bulkLookup(idsText: String) async -> [LauncherApplication] {
        let parts = idsText.components(separatedBy: CharacterSet(charactersIn: ",\n\r\t ")).map(Self.extractAppStoreId(from:)).filter { !$0.isEmpty }
        var apps: [LauncherApplication] = []
        for id in Array(Set(parts)) {
            if let app = try? await lookup(input: id) { apps.append(app) }
        }
        return apps.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Store Principal de Configuration Partagée
@MainActor
public final class SharedConfigurationStore: ObservableObject {
    @Published public var configurations: [WidgetConfigurationList] = []
    @Published public var library: [LauncherApplication] = []
    
    private let defaults: UserDefaults

    public init() {
        self.defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        load()
        if library.isEmpty && configurations.isEmpty {
            seedDefaults()
        }
    }

    public func seedDefaults() {
        AppGroupLogger.log("APP: Seeding default library & stack")
        library = PredefinedAppsDatabase.defaultLibrary
        configurations = [WidgetConfigurationList.defaultStack]
        save()
    }

    public func load() {
        AppGroupLogger.log("APP: Store Init/Load")
        
        // 1. Lire depuis UserDefaults App Group
        if let data = defaults.data(forKey: appLibraryKey),
           let decoded = try? JSONDecoder().decode([LauncherApplication].self, from: data) {
            library = decoded
        }
        if let data = defaults.data(forKey: widgetConfigurationsKey),
           let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) {
            configurations = decoded
        }

        // 2. Fallback: Lire depuis le fichier JSON partagé si UserDefaults est vide
        if configurations.isEmpty, let snapshot = loadSnapshotFromFile() {
            library = snapshot.library
            configurations = snapshot.configurations
        }
    }

    private func loadSnapshotFromFile() -> SharedSnapshot? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        let fileURL = container.appendingPathComponent(snapshotFileName)
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(SharedSnapshot.self, from: data) else { return nil }
        return snapshot
    }

    public func save() {
        // 1. Sauvegarde dans UserDefaults App Group
        if let lib = try? JSONEncoder().encode(library) {
            defaults.set(lib, forKey: appLibraryKey)
        }
        if let conf = try? JSONEncoder().encode(configurations) {
            defaults.set(conf, forKey: widgetConfigurationsKey)
        }
        defaults.synchronize()

        // 2. Sauvegarde dans le fichier JSON partagé sur disque
        saveSnapshotToFile()

        // 3. Sauvegarde dans UserDefaults standard (secours)
        if let lib = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(lib, forKey: appLibraryKey)
        }
        if let conf = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(conf, forKey: widgetConfigurationsKey)
        }

        AppGroupLogger.log("APP: Sauvegarde effectuée (\(configurations.count) piles, \(library.count) apps). Actualisation WidgetCenter.")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveSnapshotToFile() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            AppGroupLogger.log("APP ERR: containerURL inaccessible pour snapshot")
            return
        }
        let fileURL = container.appendingPathComponent(snapshotFileName)
        let snapshot = SharedSnapshot(library: library, configurations: configurations, updatedAt: Date())
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
            AppGroupLogger.log("APP: Snapshot sauvegardé dans \(fileURL.lastPathComponent)")
        }
    }

    public func forceReload() {
        save()
        WidgetCenter.shared.reloadAllTimelines()
        AppGroupLogger.log("APP: Rechargement forcé de tous les widgets déclenché")
    }

    public func addToLibrary(_ app: LauncherApplication) {
        if !library.contains(where: { $0.urlScheme == app.urlScheme && $0.displayName == app.displayName }) {
            var newApp = app
            newApp.id = UUID()
            library.append(newApp)
            library.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            save()
        }
    }

    public func addBulkToLibrary(_ apps: [LauncherApplication]) {
        for app in apps {
            if !library.contains(where: { $0.urlScheme == app.urlScheme && $0.displayName == app.displayName }) {
                var newApp = app
                newApp.id = UUID()
                library.append(newApp)
            }
        }
        library.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        save()
    }

    public func deleteFromLibrary(at offsets: IndexSet) {
        let removedIds = offsets.map { library[$0].id }
        library.remove(atOffsets: offsets)
        // Mettre à jour les piles existantes si elles contenaient cette app
        for i in 0..<configurations.count {
            configurations[i].applicationIds.removeAll { removedIds.contains($0) }
            configurations[i].applications.removeAll { removedIds.contains($0.id) }
        }
        save()
    }
    
    public func updateLibraryApp(_ app: LauncherApplication) {
        if let index = library.firstIndex(where: { $0.id == app.id }) {
            library[index] = app
            // Mettre à jour dans les piles
            for i in 0..<configurations.count {
                if let appIndex = configurations[i].applications.firstIndex(where: { $0.id == app.id }) {
                    configurations[i].applications[appIndex] = app
                }
            }
            save()
        }
    }

    public func addConfiguration() {
        let selected = Array(library.prefix(4))
        let newConfig = WidgetConfigurationList(
            name: "Nouvelle pile \(configurations.count + 1)",
            applicationIds: selected.map(\.id),
            applications: selected,
            itemLimit: 4,
            textAlignment: .leading
        )
        configurations.append(newConfig)
        save()
    }

    public func update(_ configuration: WidgetConfigurationList) {
        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            var copy = configuration
            copy.applicationIds = Array(copy.applicationIds.prefix(maxAppsPerStack))
            
            // Si applications est vide mais qu'on a des applicationIds, résorber depuis la bibliothèque
            if copy.applications.isEmpty && !copy.applicationIds.isEmpty {
                copy.applications = copy.applicationIds.compactMap { id in library.first(where: { $0.id == id }) }
            } else if copy.applicationIds.isEmpty && !copy.applications.isEmpty {
                copy.applicationIds = copy.applications.map(\.id)
            } else {
                // S'assurer que les applications correspondent à l'ordre des applicationIds
                copy.applications = copy.applicationIds.compactMap { id in
                    copy.applications.first(where: { $0.id == id }) ?? library.first(where: { $0.id == id })
                }
            }
            
            configurations[index] = copy
            save()
        }
    }

    public func delete(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        save()
    }
}