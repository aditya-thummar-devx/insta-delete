import SwiftUI

struct RootView: View {
    @Environment(LibraryStore.self) private var store
    @AppStorage("appTheme") private var theme = AppTheme.system

    var body: some View {
        Group {
            switch store.phase {
            case .access:
                AccessView()
            case .scanning:
                ScanningView()
            case .library:
                LibraryScreen()
            case .review:
                if let session = store.review { ReviewView(session: session) }
            case .complete:
                ReviewCompleteView()
            }
        }
        .task { store.bootstrap() }
        // App-wide, not per-view: `preferredColorScheme` on a subview recolours the whole window and sticks.
        .onChange(of: theme, initial: true) { NSApp.appearance = theme.appearance }
    }
}
