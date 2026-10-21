import Foundation

enum TypeFilter: String, CaseIterable, Identifiable {
    case all = "All", images = "Images", videos = "Videos"
    var id: String { rawValue }

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: true
        case .images: !item.isVideo
        case .videos: item.isVideo
        }
    }
}

enum SortKey: String, CaseIterable, Identifiable {
    case name = "Name", size = "Size", modified = "Date Modified", type = "Type"
    var id: String { rawValue }

    var defaultAscending: Bool {
        switch self {
        case .name, .type: true
        case .size, .modified: false
        }
    }

    /// (ascending label, descending label)
    var orderLabels: (asc: String, desc: String) {
        switch self {
        case .name: ("A to Z", "Z to A")
        case .size: ("Smallest first", "Largest first")
        case .modified: ("Oldest first", "Newest first")
        case .type: ("Images first", "Videos first")
        }
    }
}

enum MediaQuery {
    static func apply(_ items: [MediaItem], folder: Folder, filter: TypeFilter,
                      key: SortKey, ascending: Bool) -> [MediaItem] {
        let inFolder = folder == .all ? items : items.filter { $0.folder == folder }
        return sort(inFolder.filter(filter.matches), key: key, ascending: ascending)
    }

    static func sort(_ items: [MediaItem], key: SortKey, ascending: Bool) -> [MediaItem] {
        items.sorted { a, b in
            let c = compare(a, b, key)
            if c == .orderedSame { return a.id.path < b.id.path }  // stable tie-break either direction
            return ascending ? c == .orderedAscending : c == .orderedDescending
        }
    }

    private static func compare(_ a: MediaItem, _ b: MediaItem, _ key: SortKey) -> ComparisonResult {
        switch key {
        case .name:
            return a.name.localizedStandardCompare(b.name)
        case .size:
            return a.size == b.size ? .orderedSame : (a.size < b.size ? .orderedAscending : .orderedDescending)
        case .modified:
            return a.modified == b.modified ? .orderedSame : (a.modified < b.modified ? .orderedAscending : .orderedDescending)
        case .type:
            if a.isVideo != b.isVideo { return a.isVideo ? .orderedDescending : .orderedAscending }
            let t = a.typeDescription.localizedCompare(b.typeDescription)
            return t != .orderedSame ? t : a.name.localizedStandardCompare(b.name)
        }
    }
}
