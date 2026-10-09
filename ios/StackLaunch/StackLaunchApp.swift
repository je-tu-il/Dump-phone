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
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            rawTarget = components.queryItems?.first(where: { $0.name == "url" })?.value
        }
        
        // Fallback extraction si URLComponents ne parse pas la chaîne complexe
        if rawTarget == nil {
            if let range = url.absoluteString.range(of: "url=") {
                let suffix = String(url.absoluteString[range.upperBound...])
                rawTarget = suffix.removingPercentEncoding ?? suffix
            }
        }

        guard let targetString = rawTarget?.trimmingCharacters(in: .whitespacesAndNewlines), !targetString.isEmpty else {
            AppGroupLogger.log("APP onOpenURL ERR: Aucun paramètre 'url' valide dans \(url)")
            return
        }

        var candidateString = targetString
        if !candidateString.contains("://") && !candidateString.contains(":") {
            candidateString = "\(candidateString)://"
        }

        guard let targetURL = URL(string: candidateString) else {
            AppGroupLogger.log("APP onOpenURL ERR: URL cible invalide: '\(candidateString)'")
            return
        }

        AppGroupLogger.log("APP onOpenURL: Ouverture immédiate de l'app cible -> \(targetURL.absoluteString)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            UIApplication.shared.open(targetURL, options: [:]) { success in
                AppGroupLogger.log("APP UIApplication.open -> \(success ? "Succès" : "Échec") pour \(targetURL)")
            }
        }
    }
}
