import SwiftUI

struct MediaGrid: View {
    let items: [MediaItem]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    MediaTile(item: item)
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

    var body: some View {
        Color(hex: 0xE5E5EA)
            .aspectRatio(1, contentMode: .fit)
            .overlay { ThumbnailImage(url: item.id) }
            .overlay(alignment: .bottom) { caption }
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.isVideo ? "Video" : "Image") \(item.name)")
    }

    private var caption: some View {
        HStack(spacing: 6) {
            if item.isVideo { Image(systemName: "play.fill").font(.system(size: 9)) }
            Text(item.name).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
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
