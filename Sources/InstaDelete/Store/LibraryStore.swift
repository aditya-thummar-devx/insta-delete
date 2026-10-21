import Observation
import SwiftUI

enum AppPhase { case access, scanning, library, review, complete }
enum LibraryMode { case all, bin }

@Observable
@MainActor
final class LibraryStore {
    var phase: AppPhase = .access
    var libraryView: LibraryMode = .all
    var selectedFolder: Folder = .all
    var items: [MediaItem] = []
    private(set) var root: URL?

    @ObservationIgnored private let access = AccessManager()
    @ObservationIgnored private var bootstrapped = false

    /// Called once at launch: skip the Access screen if the stored bookmark is still valid.
    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        if let url = access.restore() { adopt(root: url) }
    }

    func grantAccess(home: Bool) {
        if let url = access.requestAccess(home: home) { adopt(root: url) }
    }

    private func adopt(root url: URL) {
        root = url
        items = []
        selectedFolder = .all
        libraryView = .all
        phase = .library  // M3: .scanning
    }


    func count(in folder: Folder) -> Int {
        folder == .all ? items.count : items.filter { $0.folder == folder }.count
    }
}
