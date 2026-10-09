import Foundation

public struct PredefinedApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let urlScheme: String
    public let appStoreId: String
    public let iconName: String
    public let category: String

    public init(name: String, urlScheme: String, appStoreId: String, iconName: String, category: String = "Général") {
        self.id = appStoreId
        self.name = name
        self.urlScheme = urlScheme
        self.appStoreId = appStoreId
        self.iconName = iconName
        self.category = category
    }

    public var launcherApplication: LauncherApplication {
        LauncherApplication(
            displayName: name,
            urlScheme: urlScheme,
            symbolName: iconName,
            appStoreId: appStoreId
        )
    }
}

public enum PredefinedAppsDatabase {
    public static let appleCategory = "Apple & Système"
    public static let socialCategory = "Réseaux & Messages"
    public static let mediaCategory = "Médias & Loisirs"
    public static let utilityCategory = "Navigation & Utilitaires"

    public static let all: [PredefinedApp] = [
        // MARK: - Apple & Système
        PredefinedApp(name: "Safari", urlScheme: "x-web-search://", appStoreId: "0-safari", iconName: "safari.fill", category: appleCategory),
        PredefinedApp(name: "Messages", urlScheme: "sms://", appStoreId: "0-messages", iconName: "message.fill", category: appleCategory),
        PredefinedApp(name: "Téléphone", urlScheme: "tel://", appStoreId: "0-phone", iconName: "phone.fill", category: appleCategory),
        PredefinedApp(name: "Mail", urlScheme: "mailto://", appStoreId: "0-mail", iconName: "envelope.fill", category: appleCategory),
        PredefinedApp(name: "Photos", urlScheme: "photos-redirect://", appStoreId: "0-photos", iconName: "photo.fill", category: appleCategory),
        PredefinedApp(name: "Appareil photo", urlScheme: "camera://", appStoreId: "0-camera", iconName: "camera.fill", category: appleCategory),
        PredefinedApp(name: "Plans", urlScheme: "maps://", appStoreId: "0-maps", iconName: "map.fill", category: appleCategory),
        PredefinedApp(name: "Réglages", urlScheme: "App-prefs://", appStoreId: "0-settings", iconName: "gear", category: appleCategory),
        PredefinedApp(name: "Horloge", urlScheme: "clock-alarm://", appStoreId: "0-clock", iconName: "clock.fill", category: appleCategory),
        PredefinedApp(name: "Calendrier", urlScheme: "calshow://", appStoreId: "0-calendar", iconName: "calendar", category: appleCategory),
        PredefinedApp(name: "Notes", urlScheme: "mobilenotes://", appStoreId: "0-notes", iconName: "note.text", category: appleCategory),
        PredefinedApp(name: "Rappels", urlScheme: "x-apple-reminderkit://", appStoreId: "0-reminders", iconName: "checklist", category: appleCategory),
        PredefinedApp(name: "Raccourcis", urlScheme: "shortcuts://", appStoreId: "0-shortcuts", iconName: "square.stack.3d.up.fill", category: appleCategory),
        PredefinedApp(name: "Météo", urlScheme: "weather://", appStoreId: "0-weather", iconName: "cloud.sun.fill", category: appleCategory),
        PredefinedApp(name: "Musique", urlScheme: "music://", appStoreId: "0-music", iconName: "music.quarternote.3", category: appleCategory),
        PredefinedApp(name: "Calculatrice", urlScheme: "calc://", appStoreId: "0-calc", iconName: "function", category: appleCategory),
        PredefinedApp(name: "Fichiers", urlScheme: "shareddocuments://", appStoreId: "0-files", iconName: "folder.fill", category: appleCategory),
        PredefinedApp(name: "App Store", urlScheme: "itms-apps://", appStoreId: "0-appstore", iconName: "bag.fill", category: appleCategory),
        PredefinedApp(name: "Santé", urlScheme: "x-apple-health://", appStoreId: "0-health", iconName: "heart.fill", category: appleCategory),
        PredefinedApp(name: "Podcasts", urlScheme: "podcasts://", appStoreId: "0-podcasts", iconName: "antenna.radiowaves.left.and.right", category: appleCategory),

        // MARK: - Réseaux & Messages
        PredefinedApp(name: "WhatsApp", urlScheme: "whatsapp://", appStoreId: "310633997", iconName: "phone.bubble.fill", category: socialCategory),
        PredefinedApp(name: "Instagram", urlScheme: "instagram://", appStoreId: "389801252", iconName: "camera.viewfinder", category: socialCategory),
        PredefinedApp(name: "TikTok", urlScheme: "snssdk1233://", appStoreId: "835599320", iconName: "music.note.tv.fill", category: socialCategory),
        PredefinedApp(name: "X (Twitter)", urlScheme: "twitter://", appStoreId: "333903271", iconName: "at", category: socialCategory),
        PredefinedApp(name: "Telegram", urlScheme: "tg://", appStoreId: "686449807", iconName: "paperplane.fill", category: socialCategory),
        PredefinedApp(name: "Discord", urlScheme: "discord://", appStoreId: "985746746", iconName: "bubble.left.and.bubble.right.fill", category: socialCategory),
        PredefinedApp(name: "Snapchat", urlScheme: "snapchat://", appStoreId: "447188370", iconName: "camera.fill", category: socialCategory),
        PredefinedApp(name: "Messenger", urlScheme: "fb-messenger://", appStoreId: "454638411", iconName: "bubble.right.fill", category: socialCategory),
        PredefinedApp(name: "Reddit", urlScheme: "reddit://", appStoreId: "1064216828", iconName: "quote.bubble.fill", category: socialCategory),
        PredefinedApp(name: "Slack", urlScheme: "slack://", appStoreId: "618783545", iconName: "number", category: socialCategory),

        // MARK: - Médias & Loisirs
        PredefinedApp(name: "Spotify", urlScheme: "spotify://", appStoreId: "324684580", iconName: "music.note", category: mediaCategory),
        PredefinedApp(name: "YouTube", urlScheme: "youtube://", appStoreId: "544007664", iconName: "play.rectangle.fill", category: mediaCategory),
        PredefinedApp(name: "Netflix", urlScheme: "nflx://", appStoreId: "363590051", iconName: "play.tv.fill", category: mediaCategory),
        PredefinedApp(name: "Twitch", urlScheme: "twitch://", appStoreId: "460177396", iconName: "video.fill", category: mediaCategory),

        // MARK: - Navigation & Utilitaires
        PredefinedApp(name: "Google Chrome", urlScheme: "googlechrome://", appStoreId: "535886823", iconName: "globe", category: utilityCategory),
        PredefinedApp(name: "Google Maps", urlScheme: "comgooglemaps://", appStoreId: "585027354", iconName: "map.fill", category: utilityCategory),
        PredefinedApp(name: "Gmail", urlScheme: "googlegmail://", appStoreId: "422689480", iconName: "envelope.fill", category: utilityCategory),
        PredefinedApp(name: "Waze", urlScheme: "waze://", appStoreId: "323229106", iconName: "location.fill", category: utilityCategory),
        PredefinedApp(name: "Uber", urlScheme: "uber://", appStoreId: "368677368", iconName: "car.fill", category: utilityCategory)
    ]

    public static let categories: [String] = [
        appleCategory,
        socialCategory,
        mediaCategory,
        utilityCategory
    ]

    public static var defaultFavorites: [LauncherApplication] {
        [
            LauncherApplication(displayName: "Safari", urlScheme: "x-web-search://", symbolName: "safari.fill", appStoreId: "0-safari"),
            LauncherApplication(displayName: "Messages", urlScheme: "sms://", symbolName: "message.fill", appStoreId: "0-messages"),
            LauncherApplication(displayName: "Photos", urlScheme: "photos-redirect://", symbolName: "photo.fill", appStoreId: "0-photos"),
            LauncherApplication(displayName: "Spotify", urlScheme: "spotify://", symbolName: "music.note", appStoreId: "324684580")
        ]
    }

    public static var defaultLibrary: [LauncherApplication] {
        all.map(\.launcherApplication)
    }

    public static let allById: [String: PredefinedApp] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
