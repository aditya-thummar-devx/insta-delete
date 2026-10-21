import SwiftUI

struct RootView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        Group {
            switch store.phase {
            case .access:
                AccessView()
            case .library, .scanning, .review, .complete:
                // Later milestones route to dedicated screens.
                LibraryScreen()
            }
        }
        .task { store.bootstrap() }
    }
}
