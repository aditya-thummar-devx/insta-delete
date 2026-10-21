import SwiftUI

struct BinListView: View {
    @Environment(LibraryStore.self) private var store
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield").foregroundStyle(Theme.accent)
                Text("InstaDelete never deletes files. These will move to the Bin in Finder, where you can put them back until you empty it.")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.infoText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.infoBG, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.top, 14)

            if store.markedItems.isEmpty {
                VStack(spacing: 8) {
                    Text("Nothing marked").font(.system(size: 17, weight: .semibold))
                    Text("Start a slideshow review and press Delete on anything you don’t need.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.markedItems) { BinCell(item: $0) }
                    }
                    .padding(20)
                }
            }
        }
    }
}

private struct BinCell: View {
    @Environment(LibraryStore.self) private var store
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Theme.tilePlaceholder
                .aspectRatio(1, contentMode: .fit)
                .overlay { ThumbnailImage(url: item.id) }
                .overlay(alignment: .topLeading) { if item.isVideo { VideoBadge(url: item.id, item: item) } }
                .overlay(alignment: .topTrailing) { TrashBadge(size: 24).padding(6) }
                .overlay(alignment: .bottomLeading) {
                    Button("Unmark") { store.unmark(item) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Theme.windowBG.opacity(0.92), in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                        .padding(6)
                        .accessibilityLabel("Unmark \(item.name)")
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.markRing, lineWidth: 3))
            Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
            Text("\(item.displayFolder) · \(Format.size(item.size))")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
    }
}
