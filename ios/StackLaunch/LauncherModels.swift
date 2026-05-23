// ios/StackLaunch/LauncherModels.swift
import Combine
import Foundation
import ImageIO
import SwiftUI
import UIKit
import os
import WidgetKit

let appGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
let widgetConfigurationsKey = "widgetConfigurations"
let appLibraryKey = "globalAppLibrary"
let maxAppsPerStack = 10

nonisolated enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case standard
    case grayscale
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .grayscale: return "Grayscale"
        case .liquidGlass: return "Liquid Glass"
        }
    }
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
    var applicationIds: [UUID]
    var applications: [LauncherApplication]
    var itemLimit: Int
    var textAlignment: TextAlignmentOption
    var showIcon: Bool
    var backgroundColorHex: String
    var iconStyle: IconStyle

    init(id: UUID = UUID(), name: String, applicationIds: [UUID] = [], applications: [LauncherApplication] = [], itemLimit: Int, textAlignment: TextAlignmentOption, showIcon: Bool = true, backgroundColorHex: String = "#07131F", iconStyle: IconStyle = .standard) {
        self.id = id
        self.name = name
        self.applicationIds = applicationIds.isEmpty ? applications.map(\.id) : applicationIds
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

    func hexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
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
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 0.72)
    }
}

nonisolated struct ITunesLookupResponse: Decodable {
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
        guard !appId.isEmpty, let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)") else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else { throw URLError(.badServerResponse) }
        let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
        guard let app = decoded.results.first else { throw URLError(.resourceUnavailable) }
        let iconURLString = app.artworkUrl512 ?? app.artworkUrl100
        var iconFileName: String?
        if let iconURLString, let iconURL = URL(string: iconURLString) {
            iconFileName = try await SharedIconStorage.saveIcon(from: iconURL, appStoreId: String(app.trackId))
        }
        return LauncherApplication(displayName: app.trackName, urlScheme: app.trackViewUrl ?? "https://apps.apple.com/app/id\(app.trackId)", appStoreId: String(app.trackId), iconRemoteURL: iconURLString, iconFileName: iconFileName)
    }

    static func extractAppStoreId(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.allSatisfy({ $0.isNumber }) { return trimmed }
        if let range = trimmed.range(of: #"id(\d+)"#, options: .regularExpression) {
            return String(trimmed[range]).replacingOccurrences(of: "id", with: "")
        }
        return ""
    }

    func bulkLookup(idsText: String) async -> [LauncherApplication] {
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

@MainActor
final class SharedConfigurationStore: ObservableObject {
    @Published var configurations: [WidgetConfigurationList] = []
    @Published var library: [LauncherApplication] = []
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "app.rork.stacklaunch", category: "SharedConfigurationStore")

    init(defaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
        load()
    }

    func load() {
        library = decode([LauncherApplication].self, key: appLibraryKey) ?? []
        let saved = decode([WidgetConfigurationList].self, key: widgetConfigurationsKey) ?? []
        configurations = saved.map { hydrated($0) }
        save()
    }

    func save() {
        configurations = configurations.map { hydrated($0) }
        encode(library, key: appLibraryKey)
        encode(configurations, key: widgetConfigurationsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addToLibrary(_ app: LauncherApplication) {
        guard !library.contains(where: { $0.appStoreId == app.appStoreId && $0.displayName == app.displayName }) else {
            logger.info("Skipped duplicate: \(app.displayName)")
            return
        }
        let copy = LauncherApplication(id: UUID(), displayName: app.displayName, urlScheme: app.urlScheme, symbolName: app.symbolName, appStoreId: app.appStoreId, iconRemoteURL: app.iconRemoteURL, iconFileName: app.iconFileName, textColorHex: app.textColorHex)
        library.append(copy)
        library.sort { $0.displayName < $1.displayName }
        save()
        logger.info("Added to library: \(copy.displayName) (\(copy.id))")
    }

    func addBulkToLibrary(_ apps: [LauncherApplication]) {
        for app in apps {
            guard !library.contains(where: { $0.appStoreId == app.appStoreId && $0.displayName == app.displayName }) else { continue }
            let copy = LauncherApplication(id: UUID(), displayName: app.displayName, urlScheme: app.urlScheme, symbolName: app.symbolName, appStoreId: app.appStoreId, iconRemoteURL: app.iconRemoteURL, iconFileName: app.iconFileName, textColorHex: app.textColorHex)
            library.append(copy)
        }
        library.sort { $0.displayName < $1.displayName }
        save()
        logger.info("Bulk added \(apps.count) apps, library now \(self.library.count)")
    }

    func updateLibraryApp(_ app: LauncherApplication) {
        guard let index = library.firstIndex(where: { $0.id == app.id }) else { return }
        library[index] = app
        save()
    }

    func addConfiguration() {
        let selected = Array(library.prefix(4))
        configurations.append(WidgetConfigurationList(name: "New Stack", applications: selected, itemLimit: 4, textAlignment: .leading))
        save()
    }

    func update(_ configuration: WidgetConfigurationList) {
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else { return }
        configurations[index] = hydrated(configuration)
        save()
    }

    func delete(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        save()
    }

    func deleteFromLibrary(at offsets: IndexSet) {
        let idsToRemove = Set(offsets.map { library[$0].id })
        library.remove(atOffsets: offsets)
        for i in configurations.indices {
            configurations[i].applicationIds.removeAll { idsToRemove.contains($0) }
            configurations[i].applications.removeAll { idsToRemove.contains($0.id) }
        }
        save()
        logger.info("Deleted \(idsToRemove.count) apps from library")
    }

    private func hydrated(_ configuration: WidgetConfigurationList) -> WidgetConfigurationList {
        var copy = configuration
        copy.itemLimit = min(maxAppsPerStack, max(1, copy.itemLimit))
        copy.applicationIds = Array(copy.applicationIds.prefix(maxAppsPerStack))
        copy.applications = copy.applicationIds.compactMap { id in library.first(where: { $0.id == id }) ?? copy.applications.first(where: { $0.id == id }) }
        return copy
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Decode FAILED for key '\(key)': \(error.localizedDescription)")
            return nil
        }
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            logger.error("Encode FAILED for key '\(key)': \(error.localizedDescription)")
        }
    }
}