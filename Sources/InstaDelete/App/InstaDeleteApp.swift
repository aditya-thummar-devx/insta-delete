import Sparkle
import SwiftUI

@main
struct InstaDeleteApp: App {
    @State private var store = LibraryStore()
    /// Release builds only: a debug build would fetch the latest release over itself.
    private let updater: SPUStandardUpdaterController? = {
        #if DEBUG
        nil
        #else
        SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil)
        #endif
    }()

    init() {
        // Unit tests host the app: they must not count as an install or an update.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil { AppVersion.recordLaunch() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                if let updater { Button("Check for Updates…") { updater.checkForUpdates(nil) } }
            }
        }

        Settings { SettingsView(onCheckForUpdates: updater.map { u in { u.checkForUpdates(nil) } }) }
    }
}
