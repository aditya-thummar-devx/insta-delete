import SwiftUI

struct RootView: View {
    @Environment(LibraryStore.self) private var store

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
    }
}
