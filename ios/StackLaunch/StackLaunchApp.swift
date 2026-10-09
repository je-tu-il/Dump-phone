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
        // Redirection personnalisée si le widget appelle stacklaunch://launch?url=...
        if url.scheme == "stacklaunch" {
            if url.host == "launch",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let targetParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetURL = URL(string: targetParam) {
                UIApplication.shared.open(targetURL)
            }
        }
    }
}
