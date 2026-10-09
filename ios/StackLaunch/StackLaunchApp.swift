import SwiftUI
import UIKit

@main
struct StackLaunchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        AppGroupLogger.log("APP onOpenURL: \(url.absoluteString)")
        guard url.scheme == "stacklaunch" else { return }

        var rawTarget: String?
        var bundleId: String?

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            rawTarget = components.queryItems?.first(where: { $0.name == "url" })?.value
            bundleId = components.queryItems?.first(where: { $0.name == "bundle" })?.value
        }
        
        // Extraction de secours si URLComponents échoue sur un format complexe
        if rawTarget == nil {
            if let range = url.absoluteString.range(of: "url=") {
                let suffix = String(url.absoluteString[range.upperBound...])
                let part = suffix.components(separatedBy: "&").first ?? suffix
                rawTarget = part.removingPercentEncoding ?? part
            }
        }
        if bundleId == nil {
            if let range = url.absoluteString.range(of: "bundle=") {
                let suffix = String(url.absoluteString[range.upperBound...])
                let part = suffix.components(separatedBy: "&").first ?? suffix
                bundleId = part.removingPercentEncoding ?? part
            }
        }

        var candidateURL: URL? = nil
        if let targetString = rawTarget?.trimmingCharacters(in: .whitespacesAndNewlines), !targetString.isEmpty {
            var formatted = targetString
            if !formatted.contains("://") && !formatted.contains(":") {
                formatted = "\(formatted)://"
            }
            candidateURL = URL(string: formatted)
        }

        // Lancement immédiat ultra-rapide sans délai d'animation
        NativeAppLauncher.openApp(bundleIdentifier: bundleId, fallbackURL: candidateURL)
    }
}
