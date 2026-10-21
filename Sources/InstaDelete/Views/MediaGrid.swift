import SwiftUI

struct MediaGrid: View {
    @Environment(LibraryStore.self) private var store
    let items: [MediaItem]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    Button {
                        if let i = items.firstIndex(where: { $0.id == item.id }) { store.startReview(at: i) }
                    } label: {
                        MediaTile(item: item, marked: store.isMarked(item))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }
}

struct MediaTile: View {
    let item: MediaItem
    let marked: Bool

    var body: some View {
        Theme.tilePlaceholder
            .aspectRatio(1, contentMode: .fit)
            .overlay { ThumbnailImage(url: item.id) }
            .overlay(alignment: .bottom) { caption }
            .overlay { if marked { Theme.windowBG.opacity(0.5) } }
            .overlay(alignment: .topLeading) {
                if item.isVideo {
                    Text("VIDEO")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) { if marked { TrashBadge(size: 24).padding(6) } }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                if marked { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.markRing, lineWidth: 3) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.isVideo ? "Video" : "Image") \(item.name)\(marked ? ", marked to be binned" : ""). Open in review")
    }

    private var caption: some View {
        HStack(spacing: 6) {
            if item.isVideo { Image(systemName: "play.fill").font(.system(size: 9)) }
            Text(item.name).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
            if item.isVideo { VideoDuration(url: item.id, item: item) }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
    }
}

struct ThumbnailImage: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geo in
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        }
        .task(id: url) {
            image = ThumbnailCache.shared.cached(url)
            if image == nil { image = await ThumbnailCache.shared.thumbnail(for: url) }
        }
    }
}

struct TrashBadge: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "trash")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.markRing, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Lazily loaded video duration text ("1:05"), empty until known.
struct VideoDuration: View {
    let url: URL
    let item: MediaItem
    @State private var text = ""

    var body: some View {
        Text(text)
            .monospacedDigit()
            .task(id: url) {
                if let d = await MetadataLoader.shared.metadata(for: item).duration { text = Format.duration(d) }
            }
    }
}

/// "▶ 1:05" pill used on bin-list tiles.
struct VideoBadge: View {
    let url: URL
    let item: MediaItem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill").font(.system(size: 9))
            VideoDuration(url: url, item: item)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
        .padding(6)
    }
}
