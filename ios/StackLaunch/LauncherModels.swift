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

// MARK: - Extensions requises par ContentView
extension Color {
    init(hex: String) {
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

    func hexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

// MARK: - Stockage des images
@MainActor
public enum SharedIconStorage {
    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
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

// MARK: - Services iTunes
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
        return LauncherApplication(displayName: app.trackName, urlScheme: app.trackViewUrl ?? "https://apps.apple.com/app/id\(app.trackId)", appStoreId: String(app.trackId), iconRemoteURL: iconURLString, iconFileName: iconFileName)
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
        let parts = idsText.components(separatedBy: CharacterSet(charactersIn: ",\n\r\t "))
            .map(Self.extractAppStoreId(from:))
            .filter { !$0.isEmpty }
        var apps: [LauncherApplication] = []
        for id in Array(Set(parts)) {
            if let app = try? await lookup(input: id) { apps.append(app) }
        }
        return apps.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Store Principal
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
        if let data = defaults.data(forKey: appLibraryKey), let decoded = try? JSONDecoder().decode([LauncherApplication].self, from: data) {
            library = decoded
        }
        if let data = defaults.data(forKey: widgetConfigurationsKey), let decoded = try? JSONDecoder().decode([WidgetConfigurationList].self, from: data) {
            configurations = decoded
        }
    }

    public func save() {
        if let libData = try? JSONEncoder().encode(library) { defaults.set(libData, forKey: appLibraryKey) }
        if let confData = try? JSONEncoder().encode(configurations) { defaults.set(confData, forKey: widgetConfigurationsKey) }
        WidgetCenter.shared.reloadAllTimelines()
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