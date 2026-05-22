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
        PredefinedApp(name: "Messages", urlScheme: "messages://", appStoreId: "0", iconName: "message.fill"),
        PredefinedApp(name: "Calendar", urlScheme: "calshow://", appStoreId: "0-calendar", iconName: "calendar"),
        PredefinedApp(name: "Instagram", urlScheme: "instagram://", appStoreId: "389801252", iconName: "camera.fill", iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/70/e8/57/70e85731-e215-39ee-0164-5287d7d04d0c/Prod-0-0-1x_U007emarketing-0-7-0-0-85-220.png/512x512bb.jpg"),
        PredefinedApp(name: "Spotify", urlScheme: "spotify://", appStoreId: "324684580", iconName: "music.note", iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/7a/99/80/7a99805d-0a03-fcef-1ace-4325367f45b7/AppIcon-0-0-1x_U007emarketing-0-11-0-85-220.png/512x512bb.jpg"),
        PredefinedApp(name: "YouTube", urlScheme: "youtube://", appStoreId: "544007664", iconName: "play.rectangle.fill")
    ]
}
