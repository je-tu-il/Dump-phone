import Combine
import Foundation
import ImageIO
import ObjectiveC
import SwiftUI
import UIKit
import WidgetKit

public let defaultAppGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
public let widgetConfigurationsKey = "widgetConfigurations"
public let appLibraryKey = "globalAppLibrary"
public let snapshotFileName = "stacklaunch_data.json"
public let maxAppsPerStack = 10

// MARK: - Résolveur dynamique d'App Group
public enum AppGroupHelper {
    public static let fallbackIdentifier = defaultAppGroupIdentifier
    public static let alternativeIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks"

    /// Résout dynamiquement l'identifiant App Group valide actif
    public static var activeIdentifier: String {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: fallbackIdentifier) != nil {
            return fallbackIdentifier
        }
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: alternativeIdentifier) != nil {
            return alternativeIdentifier
        }
        // Recherche dans embedded.mobileprovision au cas où un outil de signature (AltStore, etc.) a réécrit l'App Group
        if let provisionURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let content = try? String(contentsOf: provisionURL, encoding: .isoLatin1) {
            let pattern = #"<string>(group\.[^<]+)</string>"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let candidate = String(content[range])
                        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) != nil {
                            return candidate
                        }
                    }
                }
            }
        }
        return fallbackIdentifier
    }

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: activeIdentifier)
    }

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: activeIdentifier)
    }
}

// MARK: - Logger partagé pour le diagnostic
public struct AppGroupLogger {
    public static func log(_ message: String) {
        guard let container = AppGroupHelper.containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
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
        guard let container = AppGroupHelper.containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return "Conteneur inaccessible."
        }
        let logFile = container.appendingPathComponent("stacklaunch_debug.txt")
        return (try? String(contentsOf: logFile, encoding: .utf8)) ?? "Aucun log enregistré."
    }
    
    public static func clear() {
        guard let container = AppGroupHelper.containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
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
    public var bundleIdentifier: String?

    public init(
        id: UUID = UUID(),
        displayName: String,
        urlScheme: String,
        symbolName: String = "app.fill",
        appStoreId: String? = nil,
        iconRemoteURL: String? = nil,
        iconFileName: String? = nil,
        textColorHex: String = "#FFFFFF",
        bundleIdentifier: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.symbolName = symbolName
        self.appStoreId = appStoreId
        self.iconRemoteURL = iconRemoteURL
        self.iconFileName = iconFileName
        self.textColorHex = textColorHex
        self.bundleIdentifier = bundleIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.urlScheme = try container.decode(String.self, forKey: .urlScheme)
        self.symbolName = try container.decode(String.self, forKey: .symbolName)
        self.appStoreId = try container.decodeIfPresent(String.self, forKey: .appStoreId)
        self.iconRemoteURL = try container.decodeIfPresent(String.self, forKey: .iconRemoteURL)
        self.iconFileName = try container.decodeIfPresent(String.self, forKey: .iconFileName)
        self.textColorHex = try container.decode(String.self, forKey: .textColorHex)
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
    }

    public var parsedURL: URL? {
        var trimmed = urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        // Mail: ouvrir la boîte de réception sans feuille de rédaction
        if lower.starts(with: "mailto") {
            trimmed = "message://"
        }
        // Téléphone: ouvrir le journal d'appels directement sans invite d'appel
        else if lower.starts(with: "tel:") || lower == "tel://" || lower == "tel:" || lower.starts(with: "mobilephone:") {
            trimmed = "mobilephone-recents://"
        }
        // Appareil photo: rediriger vers Photos si camera:// n'est pas supporté nativement
        else if lower == "camera://" || lower == "camera:" {
            trimmed = "photos-redirect://"
        }
        if let direct = URL(string: trimmed) {
            return direct
        }
        if !trimmed.contains("://") && !trimmed.contains(":") {
            return URL(string: "\(trimmed)://")
        }
        return nil
    }

    public var effectiveBundleIdentifier: String? {
        if let bundle = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !bundle.isEmpty {
            return bundle
        }
        // Recherche dans PredefinedAppsDatabase
        if let predefined = PredefinedAppsDatabase.all.first(where: {
            ($0.appStoreId == self.appStoreId && self.appStoreId != nil && !self.appStoreId!.isEmpty) ||
            $0.name.caseInsensitiveCompare(self.displayName) == .orderedSame ||
            $0.urlScheme.lowercased() == self.urlScheme.lowercased()
        }), let bundle = predefined.bundleIdentifier, !bundle.isEmpty {
            return bundle
        }
        return Self.inferBundleIdentifier(fromScheme: urlScheme)
    }

    public static func inferBundleIdentifier(fromScheme scheme: String) -> String? {
        let clean = scheme.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.starts(with: "tel") || clean.starts(with: "mobilephone") { return "com.apple.mobilephone" }
        if clean.starts(with: "sms") { return "com.apple.MobileSMS" }
        if clean.starts(with: "message") || clean.starts(with: "mailto") { return "com.apple.mobilemail" }
        if clean.starts(with: "photos") { return "com.apple.mobileslideshow" }
        if clean.starts(with: "safari") || clean.starts(with: "x-web-search") { return "com.apple.mobilesafari" }
        if clean.starts(with: "music") { return "com.apple.Music" }
        if clean.starts(with: "podcasts") { return "com.apple.podcasts" }
        if clean.starts(with: "shoebox") { return "com.apple.Passbook" }
        if clean.starts(with: "calshow") { return "com.apple.mobilecal" }
        if clean.starts(with: "reminders") || clean.starts(with: "x-apple-reminderkit") { return "com.apple.reminders" }
        if clean.starts(with: "mobilenotes") || clean.starts(with: "applenotes") { return "com.apple.mobilenotes" }
        if clean.starts(with: "applehealth") || clean.starts(with: "x-apple-health") { return "com.apple.Health" }
        if clean.starts(with: "camera") { return "com.apple.camera" }
        if clean.starts(with: "app-prefs") || clean.starts(with: "prefs") { return "com.apple.Preferences" }
        if clean.starts(with: "clock") { return "com.apple.mobiletimer" }
        if clean.starts(with: "calc") { return "com.apple.calculator" }
        if clean.starts(with: "shortcuts") { return "com.apple.shortcuts" }
        if clean.starts(with: "weather") { return "com.apple.weather" }
        if clean.starts(with: "shareddocuments") { return "com.apple.DocumentsApp" }
        if clean.starts(with: "itms-apps") { return "com.apple.AppStore" }
        if clean.starts(with: "spotify") { return "com.spotify.client" }
        if clean.starts(with: "whatsapp") { return "net.whatsapp.WhatsApp" }
        if clean.starts(with: "instagram") { return "com.burbn.instagram" }
        if clean.starts(with: "snssdk") || clean.starts(with: "tiktok") { return "com.zhiliaoapp.musically" }
        if clean.starts(with: "twitter") { return "com.atebits.Tweetie2" }
        if clean.starts(with: "tg") { return "ph.telegra.Telegraph" }
        if clean.starts(with: "discord") { return "com.hammerandchisel.discord" }
        if clean.starts(with: "snapchat") { return "com.toyopagroup.picaboo" }
        if clean.starts(with: "fb-messenger") { return "com.facebook.Messenger" }
        if clean.starts(with: "youtube") { return "com.google.ios.youtube" }
        if clean.starts(with: "googlechrome") { return "com.google.chrome.ios" }
        if clean.starts(with: "comgooglemaps") { return "com.google.Maps" }
        if clean.starts(with: "googlegmail") { return "com.google.Gmail" }
        return nil
    }

    /// URL universelle pour le WidgetKit: route vers l'app hôte StackLaunch avec URL scheme et Bundle ID
    public var widgetLaunchURL: URL? {
        var queryParts: [String] = []
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")

        if let directURL = parsedURL,
           let encodedURL = directURL.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) {
            queryParts.append("url=\(encodedURL)")
        }
        if let bundle = effectiveBundleIdentifier,
           let encodedBundle = bundle.addingPercentEncoding(withAllowedCharacters: allowed) {
            queryParts.append("bundle=\(encodedBundle)")
        }
        if let encodedName = displayName.addingPercentEncoding(withAllowedCharacters: allowed) {
            queryParts.append("name=\(encodedName)")
        }
        guard !queryParts.isEmpty else { return nil }
        return URL(string: "stacklaunch://launch?\(queryParts.joined(separator: "&"))")
    }
}

// MARK: - Lanceur d'applications natif (Supporte l'ouverture directe sans invite d'action)
public enum NativeAppLauncher {
    public static func openApp(bundleIdentifier: String?, fallbackURL: URL?) {
        AppGroupLogger.log("LAUNCHER: Ouverture demandée -> BundleID: '\(bundleIdentifier ?? "nil")' | URL: '\(fallbackURL?.absoluteString ?? "nil")'")

        var finalURL = fallbackURL
        if let scheme = finalURL?.scheme?.lowercased() {
            if scheme == "mailto" {
                finalURL = URL(string: "message://")
            } else if scheme == "tel" || scheme == "tel:" {
                finalURL = URL(string: "mobilephone-recents://")
            }
        }

        // 1. Priorité absolue: UIApplication.shared.open (transition directe ultra-rapide par SpringBoard)
        if let url = finalURL {
            AppGroupLogger.log("LAUNCHER: Ouverture via UIApplication.open pour \(url.absoluteString)")
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { success in
                    AppGroupLogger.log("LAUNCHER: Résultat UIApplication.open -> \(success ? "Succès" : "Échec")")
                    if !success {
                        // 2. Si l'URL scheme n'a pas pu s'ouvrir, tenter via le workspace natif
                        fallbackToWorkspace(bundleIdentifier: bundleIdentifier, fallbackURL: url)
                    }
                }
            }
            return
        }

        // 2. Si aucune URL n'est disponible, tenter directement via LSApplicationWorkspace
        fallbackToWorkspace(bundleIdentifier: bundleIdentifier, fallbackURL: nil)
    }

    private static func fallbackToWorkspace(bundleIdentifier: String?, fallbackURL: URL?) {
        var resolvedBundleID = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedBundleID == nil || resolvedBundleID!.isEmpty {
            if let scheme = fallbackURL?.scheme {
                resolvedBundleID = LauncherApplication.inferBundleIdentifier(fromScheme: scheme)
            }
        }

        guard let bundleID = resolvedBundleID, !bundleID.isEmpty else { return }

        if openViaWorkspace(bundleID: bundleID) {
            AppGroupLogger.log("LAUNCHER: Succès via LSApplicationWorkspace pour \(bundleID)")
            suspendCurrentApp()
        } else {
            AppGroupLogger.log("LAUNCHER: Échec via LSApplicationWorkspace pour \(bundleID)")
        }
    }

    public static func suspendCurrentApp() {
        let suspendSel = NSSelectorFromString("suspend")
        DispatchQueue.main.async {
            if UIApplication.shared.responds(to: suspendSel) {
                _ = UIApplication.shared.perform(suspendSel)
            }
            UIApplication.shared.sendAction(suspendSel, to: UIApplication.shared, from: nil, for: nil)
        }
    }

    private static func openViaWorkspace(bundleID: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return false
        }
        let defaultWorkspaceSel = NSSelectorFromString("defaultWorkspace")
        guard workspaceClass.responds(to: defaultWorkspaceSel),
              let workspace = workspaceClass.perform(defaultWorkspaceSel)?.takeUnretainedValue() as? NSObject else {
            return false
        }
        let openAppSel = NSSelectorFromString("openApplicationWithBundleID:")
        guard let method = class_getInstanceMethod(type(of: workspace), openAppSel) else {
            if workspace.responds(to: openAppSel) {
                _ = workspace.perform(openAppSel, with: bundleID)
                return true
            }
            return false
        }
        
        let imp = method_getImplementation(method)
        typealias OpenAppFn = @convention(c) (AnyObject, Selector, NSString) -> Bool
        let openApp = unsafeBitCast(imp, to: OpenAppFn.self)
        let success = openApp(workspace, openAppSel, bundleID as NSString)
        return success
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
        AppGroupHelper.containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
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
        self.defaults = AppGroupHelper.sharedDefaults ?? .standard
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
        AppGroupLogger.log("APP: Store Init/Load (App Group: \(AppGroupHelper.activeIdentifier))")
        
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
        guard let container = AppGroupHelper.containerURL else { return nil }
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

        // 3. Sauvegarde dans UserDefaults standard (secours local)
        if let lib = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(lib, forKey: appLibraryKey)
        }
        if let conf = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(conf, forKey: widgetConfigurationsKey)
        }

        AppGroupLogger.log("APP: Sauvegarde effectuée (\(configurations.count) piles, \(library.count) apps). Actualisation WidgetCenter.")
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "StackLaunchWidget")
    }

    private func saveSnapshotToFile() {
        guard let container = AppGroupHelper.containerURL else {
            AppGroupLogger.log("APP ERR: containerURL inaccessible pour snapshot (App Group: \(AppGroupHelper.activeIdentifier))")
            return
        }
        let fileURL = container.appendingPathComponent(snapshotFileName)
        let snapshot = SharedSnapshot(library: library, configurations: configurations, updatedAt: Date())
        if let data = try? JSONEncoder().encode(snapshot) {
            do {
                try data.write(to: fileURL, options: .atomic)
                AppGroupLogger.log("APP: Snapshot sauvegardé dans \(fileURL.lastPathComponent)")
            } catch {
                AppGroupLogger.log("APP ERR: Écriture snapshot échouée: \(error)")
            }
        }
    }

    public func forceReload() {
        save()
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "StackLaunchWidget")
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