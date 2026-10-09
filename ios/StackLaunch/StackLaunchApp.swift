import SwiftUI
import UIKit

@main
struct StackLaunchApp: App {
    @State private var targetAppName: String? = nil
    @State private var isRedirecting = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if isRedirecting {
                    ZStack {
                        Color(red: 0.02, green: 0.04, blue: 0.08)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)

                            if let name = targetAppName, !name.isEmpty {
                                Text("Ouverture de \(name)...")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            } else {
                                Text("Ouverture de l'application...")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
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
        var appName: String?

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            rawTarget = components.queryItems?.first(where: { $0.name == "url" })?.value
            bundleId = components.queryItems?.first(where: { $0.name == "bundle" })?.value
            appName = components.queryItems?.first(where: { $0.name == "name" })?.value
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
        if appName == nil {
            if let range = url.absoluteString.range(of: "name=") {
                let suffix = String(url.absoluteString[range.upperBound...])
                let part = suffix.components(separatedBy: "&").first ?? suffix
                appName = part.removingPercentEncoding ?? part
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

        withAnimation(.easeInOut(duration: 0.12)) {
            targetAppName = appName
            isRedirecting = true
        }

        // Lancement natif: ouvre l'application à sa racine sans écran de composition ou appel
        NativeAppLauncher.openApp(bundleIdentifier: bundleId, fallbackURL: candidateURL)

        // Réinitialisation après le passage en arrière-plan
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                isRedirecting = false
                targetAppName = nil
            }
        }
    }
}
