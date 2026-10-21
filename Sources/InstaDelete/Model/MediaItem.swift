import CoreGraphics
import Foundation

struct MediaItem: Identifiable, Hashable {
    enum Kind: String { case image, video }

    let id: URL
    let name: String
    let kind: Kind
    let typeDescription: String
    let size: Int64
    let modified: Date
    let folder: Folder
    /// Path relative to the granted root, shown as "~/Pictures" style in the UI.
    let displayFolder: String
    var duration: Double?
    var pixelSize: CGSize?

    var isVideo: Bool { kind == .video }
}
