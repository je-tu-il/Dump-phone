import Foundation

public struct PredefinedApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let urlScheme: String
    public let appStoreId: String
    public let iconName: String
    public let category: String
    public let bundleIdentifier: String?

    public init(name: String, urlScheme: String, appStoreId: String, iconName: String, category: String = "Général", bundleIdentifier: String? = nil) {
        self.id = appStoreId
        self.name = name
        self.urlScheme = urlScheme
        self.appStoreId = appStoreId
        self.iconName = iconName
        self.category = category
        self.bundleIdentifier = bundleIdentifier
    }

    public var launcherApplication: LauncherApplication {
        LauncherApplication(
            displayName: name,
            urlScheme: urlScheme,
            symbolName: iconName,
            appStoreId: appStoreId,
            bundleIdentifier: bundleIdentifier
        )
    }
}

public enum PredefinedAppsDatabase {
    public static let appleCategory = "Apple & Système"
    public static let socialCategory = "Réseaux & Messages"
    public static let mediaCategory = "Médias & Loisirs"
    public static let utilityCategory = "Navigation & Utilitaires"

    public static let all: [PredefinedApp] = [
        // MARK: - Apple & Système (avec Bundle IDs pour ouverture directe à la racine sans invite)
        PredefinedApp(name: "Téléphone", urlScheme: "mobilephone-recents://", appStoreId: "0-phone", iconName: "phone.fill", category: appleCategory, bundleIdentifier: "com.apple.mobilephone"),
        PredefinedApp(name: "Messages", urlScheme: "messages://", appStoreId: "0-messages", iconName: "message.fill", category: appleCategory, bundleIdentifier: "com.apple.MobileSMS"),
        PredefinedApp(name: "Mail", urlScheme: "message://", appStoreId: "0-mail", iconName: "envelope.fill", category: appleCategory, bundleIdentifier: "com.apple.mobilemail"),
        PredefinedApp(name: "Safari", urlScheme: "x-web-search://", appStoreId: "0-safari", iconName: "safari.fill", category: appleCategory, bundleIdentifier: "com.apple.mobilesafari"),
        PredefinedApp(name: "Photos", urlScheme: "photos-redirect://", appStoreId: "0-photos", iconName: "photo.fill", category: appleCategory, bundleIdentifier: "com.apple.mobileslideshow"),
        PredefinedApp(name: "Appareil photo", urlScheme: "camera://", appStoreId: "0-camera", iconName: "camera.fill", category: appleCategory, bundleIdentifier: "com.apple.camera"),
        PredefinedApp(name: "Plans", urlScheme: "maps://", appStoreId: "0-maps", iconName: "map.fill", category: appleCategory, bundleIdentifier: "com.apple.Maps"),
        PredefinedApp(name: "Réglages", urlScheme: "App-prefs://", appStoreId: "0-settings", iconName: "gear", category: appleCategory, bundleIdentifier: "com.apple.Preferences"),
        PredefinedApp(name: "Horloge", urlScheme: "clock-alarm://", appStoreId: "0-clock", iconName: "clock.fill", category: appleCategory, bundleIdentifier: "com.apple.mobiletimer"),
        PredefinedApp(name: "Calendrier", urlScheme: "calshow://", appStoreId: "0-calendar", iconName: "calendar", category: appleCategory, bundleIdentifier: "com.apple.mobilecal"),
        PredefinedApp(name: "Notes", urlScheme: "mobilenotes://", appStoreId: "0-notes", iconName: "note.text", category: appleCategory, bundleIdentifier: "com.apple.mobilenotes"),
        PredefinedApp(name: "Rappels", urlScheme: "x-apple-reminderkit://", appStoreId: "0-reminders", iconName: "checklist", category: appleCategory, bundleIdentifier: "com.apple.reminders"),
        PredefinedApp(name: "Raccourcis", urlScheme: "shortcuts://", appStoreId: "0-shortcuts", iconName: "square.stack.3d.up.fill", category: appleCategory, bundleIdentifier: "com.apple.shortcuts"),
        PredefinedApp(name: "Météo", urlScheme: "weather://", appStoreId: "0-weather", iconName: "cloud.sun.fill", category: appleCategory, bundleIdentifier: "com.apple.weather"),
        PredefinedApp(name: "Musique", urlScheme: "music://", appStoreId: "0-music", iconName: "music.quarternote.3", category: appleCategory, bundleIdentifier: "com.apple.Music"),
        PredefinedApp(name: "Calculatrice", urlScheme: "calc://", appStoreId: "0-calc", iconName: "function", category: appleCategory, bundleIdentifier: "com.apple.calculator"),
        PredefinedApp(name: "Fichiers", urlScheme: "shareddocuments://", appStoreId: "0-files", iconName: "folder.fill", category: appleCategory, bundleIdentifier: "com.apple.DocumentsApp"),
        PredefinedApp(name: "App Store", urlScheme: "itms-apps://", appStoreId: "0-appstore", iconName: "bag.fill", category: appleCategory, bundleIdentifier: "com.apple.AppStore"),
        PredefinedApp(name: "Santé", urlScheme: "x-apple-health://", appStoreId: "0-health", iconName: "heart.fill", category: appleCategory, bundleIdentifier: "com.apple.Health"),
        PredefinedApp(name: "Podcasts", urlScheme: "podcasts://", appStoreId: "0-podcasts", iconName: "antenna.radiowaves.left.and.right", category: appleCategory, bundleIdentifier: "com.apple.podcasts"),

        // MARK: - Réseaux & Messages
        PredefinedApp(name: "WhatsApp", urlScheme: "whatsapp://", appStoreId: "310633997", iconName: "phone.bubble.fill", category: socialCategory, bundleIdentifier: "net.whatsapp.WhatsApp"),
        PredefinedApp(name: "Instagram", urlScheme: "instagram://", appStoreId: "389801252", iconName: "camera.viewfinder", category: socialCategory, bundleIdentifier: "com.burbn.instagram"),
        PredefinedApp(name: "TikTok", urlScheme: "snssdk1233://", appStoreId: "835599320", iconName: "music.note.tv.fill", category: socialCategory, bundleIdentifier: "com.zhiliaoapp.musically"),
        PredefinedApp(name: "X (Twitter)", urlScheme: "twitter://", appStoreId: "333903271", iconName: "at", category: socialCategory, bundleIdentifier: "com.atebits.Tweetie2"),
        PredefinedApp(name: "Telegram", urlScheme: "tg://", appStoreId: "686449807", iconName: "paperplane.fill", category: socialCategory, bundleIdentifier: "ph.telegra.Telegraph"),
        PredefinedApp(name: "Discord", urlScheme: "discord://", appStoreId: "985746746", iconName: "bubble.left.and.bubble.right.fill", category: socialCategory, bundleIdentifier: "com.hammerandchisel.discord"),
        PredefinedApp(name: "Snapchat", urlScheme: "snapchat://", appStoreId: "447188370", iconName: "camera.fill", category: socialCategory, bundleIdentifier: "com.toyopagroup.picaboo"),
        PredefinedApp(name: "Messenger", urlScheme: "fb-messenger://", appStoreId: "454638411", iconName: "bubble.right.fill", category: socialCategory, bundleIdentifier: "com.facebook.Messenger"),
        PredefinedApp(name: "Reddit", urlScheme: "reddit://", appStoreId: "1064216828", iconName: "quote.bubble.fill", category: socialCategory, bundleIdentifier: "com.reddit.Reddit"),
        PredefinedApp(name: "Slack", urlScheme: "slack://", appStoreId: "618783545", iconName: "number", category: socialCategory, bundleIdentifier: "com.tinyspeck.chatlyio"),

        // MARK: - Médias & Loisirs
        PredefinedApp(name: "Spotify", urlScheme: "spotify://", appStoreId: "324684580", iconName: "music.note", category: mediaCategory, bundleIdentifier: "com.spotify.client"),
        PredefinedApp(name: "YouTube", urlScheme: "youtube://", appStoreId: "544007664", iconName: "play.rectangle.fill", category: mediaCategory, bundleIdentifier: "com.google.ios.youtube"),
        PredefinedApp(name: "Netflix", urlScheme: "nflx://", appStoreId: "363590051", iconName: "play.tv.fill", category: mediaCategory, bundleIdentifier: "com.netflix.Netflix"),
        PredefinedApp(name: "Twitch", urlScheme: "twitch://", appStoreId: "460177396", iconName: "video.fill", category: mediaCategory, bundleIdentifier: "tv.twitch"),

        // MARK: - Navigation & Utilitaires
        PredefinedApp(name: "Google Chrome", urlScheme: "googlechrome://", appStoreId: "535886823", iconName: "globe", category: utilityCategory, bundleIdentifier: "com.google.chrome.ios"),
        PredefinedApp(name: "Google Maps", urlScheme: "comgooglemaps://", appStoreId: "585027354", iconName: "map.fill", category: utilityCategory, bundleIdentifier: "com.google.Maps"),
        PredefinedApp(name: "Gmail", urlScheme: "googlegmail://", appStoreId: "422689480", iconName: "envelope.fill", category: utilityCategory, bundleIdentifier: "com.google.Gmail"),
        PredefinedApp(name: "Waze", urlScheme: "waze://", appStoreId: "323229106", iconName: "location.fill", category: utilityCategory, bundleIdentifier: "com.waze.iphone"),
        PredefinedApp(name: "Uber", urlScheme: "uber://", appStoreId: "368677368", iconName: "car.fill", category: utilityCategory, bundleIdentifier: "com.ubercab.UberClient")
    ]

    public static let categories: [String] = [
        appleCategory,
        socialCategory,
        mediaCategory,
        utilityCategory
    ]

    public static var defaultFavorites: [LauncherApplication] {
        [
            LauncherApplication(displayName: "Téléphone", urlScheme: "mobilephone-recents://", symbolName: "phone.fill", appStoreId: "0-phone", bundleIdentifier: "com.apple.mobilephone"),
            LauncherApplication(displayName: "Messages", urlScheme: "messages://", symbolName: "message.fill", appStoreId: "0-messages", bundleIdentifier: "com.apple.MobileSMS"),
            LauncherApplication(displayName: "Safari", urlScheme: "x-web-search://", symbolName: "safari.fill", appStoreId: "0-safari", bundleIdentifier: "com.apple.mobilesafari"),
            LauncherApplication(displayName: "Photos", urlScheme: "photos-redirect://", symbolName: "photo.fill", appStoreId: "0-photos", bundleIdentifier: "com.apple.mobileslideshow")
        ]
    }

    public static var defaultLibrary: [LauncherApplication] {
        all.map(\.launcherApplication)
    }

    public static let allById: [String: PredefinedApp] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
