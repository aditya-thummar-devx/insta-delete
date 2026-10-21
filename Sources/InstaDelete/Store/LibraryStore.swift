import Observation
import SwiftUI

enum AppPhase { case access, scanning, library, review, complete }
enum LibraryMode { case all, bin }

@Observable
@MainActor
final class LibraryStore {
    var phase: AppPhase = .library
    var libraryView: LibraryMode = .all
    var selectedFolder: Folder = .all
    var items: [MediaItem] = []

    func count(in folder: Folder) -> Int {
        folder == .all ? items.count : items.filter { $0.folder == folder }.count
    }
}
