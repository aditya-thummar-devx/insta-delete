import Foundation

/// Sidebar buckets: the first path component under the granted root.
enum Folder: String, CaseIterable, Identifiable, Hashable {
    case all = "All Media"
    case pictures = "Pictures"
    case movies = "Movies"
    case desktop = "Desktop"
    case downloads = "Downloads"
    case documents = "Documents"
    case other = "Other"

    var id: String { rawValue }

    /// Folders listed in the sidebar and the scanner (in scan order).
    static let named: [Folder] = [.pictures, .movies, .desktop, .downloads, .documents]

    static func bucket(forTopLevelName name: String) -> Folder {
        named.first { $0.rawValue == name } ?? .other
    }
}
