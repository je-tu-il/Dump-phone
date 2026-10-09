import Foundation
import SwiftUI
import os

public let defaultAppGroupIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks.stacklaunch"
public let widgetConfigurationsKey = "widgetConfigurations"
public let appLibraryKey = "globalAppLibrary"
public let snapshotFileName = "stacklaunch_data.json"
public let maxAppsPerStack = 10

// MARK: - Résolveur dynamique d'App Group
public enum AppGroupHelper {
    public static let fallbackIdentifier = defaultAppGroupIdentifier
    public static let alternativeIdentifier = "group.app.rork.7xhlz1b8jysl5d26x7cks"

    public static var activeIdentifier: String {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: fallbackIdentifier) != nil {
            return fallbackIdentifier
        }
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: alternativeIdentifier) != nil {
            return alternativeIdentifier
        }
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

// MARK: - Logger partagé pour le widget
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

// MARK: - Snapshot partagé
public struct SharedSnapshot: Codable, Sendable {
    public let library: [LauncherApplication]
    public let configurations: [WidgetConfigurationList]
    public let updatedAt: Date
}

// MARK: - Extension Color Hex
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
}

// MARK: - Lecteur Résilient pour le Widget
public enum SharedWidgetReader {
    private static let logger = Logger(subsystem: "app.rork.stacklaunch.widget", category: "SharedWidgetReader")

    public static func configurations() -> [WidgetConfigurationList] {
        var library: [LauncherApplication] = []
        var configs: [WidgetConfigurationList] = []

        // 1. Essai depuis App Group UserDefaults
        if let defaults = AppGroupHelper.sharedDefaults {
            library = decodeOrEmpty([LauncherApplication].self, key: appLibraryKey, defaults: defaults)
            configs = decodeOrEmpty([WidgetConfigurationList].self, key: widgetConfigurationsKey, defaults: defaults)
            if !configs.isEmpty {
                AppGroupLogger.log("WIDGET: \(configs.count) piles chargées depuis UserDefaults suite '\(AppGroupHelper.activeIdentifier)'")
            }
        }

        // 2. Essai de secours: Lire le snapshot JSON sur le disque du conteneur partagé
        if configs.isEmpty {
            if let snapshot = loadSnapshotFromFile() {
                AppGroupLogger.log("WIDGET: \(snapshot.configurations.count) piles chargées depuis le fichier snapshot JSON")
                library = snapshot.library
                configs = snapshot.configurations
            }
        }

        // 3. Essai de secours: UserDefaults standard
        if configs.isEmpty {
            let defaults = UserDefaults.standard
            library = decodeOrEmpty([LauncherApplication].self, key: appLibraryKey, defaults: defaults)
            configs = decodeOrEmpty([WidgetConfigurationList].self, key: widgetConfigurationsKey, defaults: defaults)
            if !configs.isEmpty {
                AppGroupLogger.log("WIDGET: \(configs.count) piles chargées depuis UserDefaults.standard")
            }
        }

        // 4. Si toujours vide: générer la configuration par défaut avec les applications préinstallées
        if configs.isEmpty {
            AppGroupLogger.log("WIDGET: Aucune pile enregistrée trouvée, utilisation du secours 'Favoris'")
            configs = [WidgetConfigurationList.defaultStack]
        }

        // Hydrater chaque configuration pour garantir la validité et la présence d'applications
        return configs.map { hydrate($0, library: library) }
    }

    public static func configuration(id: String?) -> WidgetConfigurationList {
        let all = configurations()
        if let id, let uuid = UUID(uuidString: id), let match = all.first(where: { $0.id == uuid }) {
            return match
        }
        return all.first ?? WidgetConfigurationList.defaultStack
    }

    public static func iconURL(fileName: String?) -> URL? {
        guard let fileName else { return nil }
        if let container = AppGroupHelper.containerURL {
            let path = container.appendingPathComponent("DownloadedIcons", isDirectory: true).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let path = docs.appendingPathComponent("DownloadedIcons", isDirectory: true).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        return nil
    }

    private static func loadSnapshotFromFile() -> SharedSnapshot? {
        guard let container = AppGroupHelper.containerURL else { return nil }
        let fileURL = container.appendingPathComponent(snapshotFileName)
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(SharedSnapshot.self, from: data) else { return nil }
        return snapshot
    }

    private static func hydrate(_ configuration: WidgetConfigurationList, library: [LauncherApplication]) -> WidgetConfigurationList {
        var copy = configuration
        copy.itemLimit = min(maxAppsPerStack, max(1, copy.itemLimit))
        
        // Synchroniser applicationIds si vide
        if copy.applicationIds.isEmpty && !copy.applications.isEmpty {
            copy.applicationIds = copy.applications.map(\.id)
        }

        // Résoudre les applications depuis la bibliothèque si nécessaire
        if !library.isEmpty && !copy.applicationIds.isEmpty {
            let resolved = copy.applicationIds.compactMap { id in
                library.first(where: { $0.id == id }) ?? copy.applications.first(where: { $0.id == id })
            }
            if !resolved.isEmpty {
                copy.applications = resolved
            }
        }

        // Si la pile est toujours vide, charger les applications par défaut
        if copy.applications.isEmpty {
            copy.applications = PredefinedAppsDatabase.defaultFavorites
            copy.applicationIds = copy.applications.map(\.id)
        }

        return copy
    }

    private static func decodeOrEmpty<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T where T: RangeReplaceableCollection {
        guard let data = defaults.data(forKey: key) else { return T() }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Décodage échoué pour la clé '\(key)': \(error.localizedDescription)")
            return T()
        }
    }
}
