import SwiftUI

struct RootView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        switch store.phase {
        case .library, .access, .scanning, .review, .complete:
            // Later milestones route to dedicated screens.
            LibraryScreen()
        }
    }
}
