import SwiftUI
import UIKit

@main
struct StackLaunchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLaunchFailure = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert("Impossible d’ouvrir ce raccourci", isPresented: $showLaunchFailure) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Vérifiez que l’application est installée et que son lien est valide.")
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    checkPendingLaunch()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        checkPendingLaunch()
                    }
                }
        }
    }

    private func checkPendingLaunch() {
        guard let defaults = AppGroupHelper.sharedDefaults else { return }
        let pendingURLString = defaults.string(forKey: "pendingLaunchURL")
        let pendingBundle = defaults.string(forKey: "pendingLaunchBundleID")
        if pendingURLString != nil || pendingBundle != nil {
            defaults.removeObject(forKey: "pendingLaunchURL")
            defaults.removeObject(forKey: "pendingLaunchBundleID")
            open(bundle: pendingBundle, url: pendingURLString.flatMap { URL(string: $0) })
        }
    }


    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "stacklaunch", url.host == "launch",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let rawTarget = components.queryItems?.first(where: { $0.name == "url" })?.value
        let bundle = components.queryItems?.first(where: { $0.name == "bundle" })?.value
        open(bundle: bundle, url: rawTarget.flatMap { URL(string: $0) })
    }

    private func open(bundle: String?, url: URL?) {
        NativeAppLauncher.openApp(bundleIdentifier: bundle, fallbackURL: url) { showLaunchFailure = true }
    }
}
