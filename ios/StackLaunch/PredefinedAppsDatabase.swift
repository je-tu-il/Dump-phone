import Foundation

nonisolated struct PredefinedApp: Identifiable, Hashable {
    let id: String
    let name: String
    let urlScheme: String
    let appStoreId: String
    let iconName: String?
    let iconURL: String?

    init(name: String, urlScheme: String, appStoreId: String, iconName: String? = nil, iconURL: String? = nil) {
        self.id = appStoreId
        self.name = name
        self.urlScheme = urlScheme
        self.appStoreId = appStoreId
        self.iconName = iconName
        self.iconURL = iconURL
    }

    var launcherApplication: LauncherApplication {
        LauncherApplication(displayName: name, urlScheme: urlScheme, symbolName: iconName ?? "app.fill", appStoreId: appStoreId, iconRemoteURL: iconURL)
    }
}

nonisolated enum PredefinedAppsDatabase {
    static let all: [PredefinedApp] = [
        // Apple built-in
        PredefinedApp(name: "Calendar", urlScheme: "calshow://", appStoreId: "0-calendar", iconName: "calendar"),
        PredefinedApp(name: "Clock", urlScheme: "clock-alarm://", appStoreId: "0-clock", iconName: "clock.fill"),
        PredefinedApp(name: "Maps", urlScheme: "maps://", appStoreId: "0-maps", iconName: "map.fill"),
        PredefinedApp(name: "Messages", urlScheme: "messages://", appStoreId: "0-messages", iconName: "message.fill"),
        PredefinedApp(name: "Notes", urlScheme: "mobilenotes://", appStoreId: "0-notes", iconName: "note.text"),
        PredefinedApp(name: "Phone", urlScheme: "tel://", appStoreId: "0-phone", iconName: "phone.fill"),
        PredefinedApp(name: "Photos", urlScheme: "photos-redirect://", appStoreId: "0-photos", iconName: "photo.fill"),
        PredefinedApp(name: "Reminders", urlScheme: "x-apple-reminderkit://", appStoreId: "0-reminders", iconName: "checklist"),
        PredefinedApp(name: "Safari", urlScheme: "x-web-search://", appStoreId: "0-safari", iconName: "safari.fill"),
        PredefinedApp(name: "Settings", urlScheme: "App-prefs://", appStoreId: "0-settings", iconName: "gear"),
        PredefinedApp(name: "Shortcuts", urlScheme: "shortcuts://", appStoreId: "0-shortcuts", iconName: "square.stack.3d.up.fill"),
        PredefinedApp(name: "Weather", urlScheme: "weather://", appStoreId: "0-weather", iconName: "cloud.sun.fill"),

        // Third-party
        PredefinedApp(name: "Discord", urlScheme: "discord://", appStoreId: "985746746", iconName: "bubble.left.fill"),
        PredefinedApp(name: "Gmail", urlScheme: "googlegmail://", appStoreId: "422689480", iconName: "envelope.fill"),
        PredefinedApp(name: "Google Chrome", urlScheme: "googlechrome://", appStoreId: "535886823", iconName: "globe"),
        PredefinedApp(name: "Google Maps", urlScheme: "comgooglemaps://", appStoreId: "585027354", iconName: "map.fill"),
        PredefinedApp(name: "Instagram", urlScheme: "instagram://", appStoreId: "389801252", iconName: "camera.fill"),
        PredefinedApp(name: "Messenger", urlScheme: "fb-messenger://", appStoreId: "454638411", iconName: "bubble.right.fill"),
        PredefinedApp(name: "Netflix", urlScheme: "nflx://", appStoreId: "363590051", iconName: "play.tv.fill"),
        PredefinedApp(name: "Reddit", urlScheme: "reddit://", appStoreId: "1064216828", iconName: "quote.bubble.fill"),
        PredefinedApp(name: "Slack", urlScheme: "slack://", appStoreId: "618783545", iconName: "number"),
        PredefinedApp(name: "Snapchat", urlScheme: "snapchat://", appStoreId: "447188370", iconName: "camera.viewfinder"),
        PredefinedApp(name: "Spotify", urlScheme: "spotify://", appStoreId: "324684580", iconName: "music.note"),
        PredefinedApp(name: "Telegram", urlScheme: "telegram://", appStoreId: "686449807", iconName: "paperplane.fill"),
        PredefinedApp(name: "TikTok", urlScheme: "snssdk1233://", appStoreId: "835599320", iconName: "music.note.tv.fill"),
        PredefinedApp(name: "Twitch", urlScheme: "twitch://", appStoreId: "460177396", iconName: "play.rectangle.fill"),
        PredefinedApp(name: "WhatsApp", urlScheme: "whatsapp://", appStoreId: "310633997", iconName: "phone.bubble.fill"),
        PredefinedApp(name: "X", urlScheme: "twitter://", appStoreId: "333903271", iconName: "at"),
        PredefinedApp(name: "YouTube", urlScheme: "youtube://", appStoreId: "544007664", iconName: "play.rectangle.fill"),
    ]

    static let allById: [String: PredefinedApp] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
