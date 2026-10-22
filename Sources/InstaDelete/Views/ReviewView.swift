import SwiftUI

struct ReviewView: View {
    @Environment(LibraryStore.self) private var store
    let session: ReviewSession
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TopBar(session: session)
            HStack(spacing: 0) {
                HStack(spacing: 20) {
                    NavCircle(symbol: "chevron.left", label: "Previous") { session.previous() }
                    if let item = session.current {
                        Viewer(item: item, marked: store.isMarked(item), video: session.video)
                    } else {
                        Spacer()
                    }
                    NavCircle(symbol: "chevron.right", label: "Next") { next() }
                }
                .padding(20)
                .frame(maxWidth: .infinity)

                if let item = session.current {
                    DetailsPanel(session: session, item: item, onNext: next, onToggle: toggleMarkAndAdvance)
                }
            }
            Filmstrip(session: session)
        }
        .background(Theme.reviewBG)
        .foregroundStyle(Theme.text)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in handle(press) }
        // Moving to another item (or leaving) stops any playing video.
        .onChange(of: session.index, initial: true) { session.video.load(session.current) }
        .onDisappear { session.video.load(nil) }
        .task(id: session.index) { await prefetchNeighbours() }
    }

    private func next() {
        if !session.advance() { store.finishReview() }
    }

    /// Toggle mark on the current item, then move on. Stays put on the last item (no auto-finish).
    private func toggleMarkAndAdvance() {
        guard let item = session.current else { return }
        store.toggleMark(item)
        session.advance()
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: session.previous()
        case .rightArrow: next()
        // The Mac Delete (backspace) key sends U+007F, which is neither `.delete` (U+0008) nor `.deleteForward` (U+F728).
        case .delete, .deleteForward, KeyEquivalent("\u{7F}"):
            toggleMarkAndAdvance()
        case .escape: store.exitReview()
        case .space:
            guard session.current?.isVideo == true else { return .ignored }
            session.video.toggle()
        default: return .ignored
        }
        return .handled
    }

    private func prefetchNeighbours() async {
        for i in [session.index + 1, session.index - 1] where session.queue.indices.contains(i) {
            let item = session.queue[i]
            if !item.isVideo { _ = await ImageLoader.shared.image(for: item.id) }
        }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @Environment(LibraryStore.self) private var store
    let session: ReviewSession

    var body: some View {
        HStack(spacing: 16) {
            Button { store.exitReview() } label: {
                Label("Exit", systemImage: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Theme.reviewChip, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exit review")

            Text(session.scopeLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.infoText)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Theme.accentSoftBG, in: Capsule())

            Spacer()
            VStack(spacing: 6) {
                Text("\(session.queue.isEmpty ? 0 : session.index + 1) of \(session.queue.count)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                ProgressView(value: Double(session.index + 1), total: Double(max(1, session.queue.count)))
                    .tint(Theme.accent)
                    .frame(width: 300)
                    .accessibilityHidden(true)
            }
            Spacer()

            Button { store.openBin() } label: {
                Label("\(store.markedItems.count) to be binned", systemImage: "trash")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.destructiveSoftFG)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Theme.destructiveSoftBG, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open To Be Binned list, \(store.markedItems.count) items")
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.reviewDivider).frame(height: 1) }
    }
}

private struct NavCircle: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Theme.reviewChip, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Viewer

private struct Viewer: View {
    let item: MediaItem
    let marked: Bool
    let video: VideoController

    var body: some View {
        ZStack {
            Color.black
            if item.isVideo {
                VideoPlayerView(video: video)
            } else {
                ReviewImage(url: item.id)
            }
            if marked {
                ZStack {
                    Color(red: 20 / 255, green: 0, blue: 4 / 255).opacity(0.58)
                    VStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 28, weight: .semibold))
                            .frame(width: 64, height: 64)
                            .background(Theme.markRing, in: Circle())
                            .shadow(radius: 8, y: 6)
                        Text("Marked to be binned").font(.system(size: 18, weight: .bold))
                        Text("Nothing moves until you confirm the list")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: 0xE5E5EA))
                    }
                    .foregroundStyle(.white)
                }
                .allowsHitTesting(false)  // keep the video controls usable while marked
                .accessibilityElement(children: .combine)
            }
        }
        .overlay(alignment: .topLeading) {
            Text(item.isVideo ? "VIDEO" : "IMAGE")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                .padding(12)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.reviewMarkRing, lineWidth: marked ? 4 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("\(item.name)\(marked ? ", marked to be binned" : "")")
    }
}

private struct ReviewImage: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: url) {
            image = ImageLoader.shared.cached(url)
            if image == nil {
                // Show the cheap thumbnail immediately, then swap in the full-size one.
                image = ThumbnailCache.shared.cached(url)
                if let full = await ImageLoader.shared.image(for: url) { image = full }
            }
        }
    }
}

// MARK: - Details panel

private struct DetailsPanel: View {
    @Environment(LibraryStore.self) private var store
    let session: ReviewSession
    let item: MediaItem
    let onNext: () -> Void
    let onToggle: () -> Void
    @State private var meta = MediaMetadata()

    var body: some View {
        let marked = store.isMarked(item)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.system(size: 17, weight: .bold)).lineLimit(3)
                Text(item.displayFolder).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 10) {
                row("Kind", item.typeDescription)
                row("Size", Format.size(item.size))
                row("Modified", Format.date(item.modified))
                row(item.isVideo ? "Resolution" : "Dimensions", meta.pixelSize.map(Format.dimensions) ?? "—")
                if item.isVideo { row("Duration", meta.duration.map(Format.duration) ?? "—") }
            }
            .font(.system(size: 13))

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text(marked ? "Unmark" : "Mark to Bin")
                        Kbd("⌫", opacity: 0.8)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(marked ? Color.white : Theme.destructiveSoftFG)
                    .background(marked ? Theme.markRing : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.markRing, lineWidth: marked ? 0 : 1))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text(session.isLast ? "Finish Review" : "Keep & Next")
                        Kbd("→", opacity: 0.7)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(session.isLast ? Color.white : Theme.text)
                    .background(session.isLast ? Theme.accent : Theme.reviewChip, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button { session.previous() } label: {
                    HStack(spacing: 8) {
                        Kbd("←", opacity: 1)
                        Text("Previous")
                    }
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(Theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("← → move · Delete marks or unmarks, then moves on\nSpace plays or pauses a video")
                .font(.system(size: 11))
                .lineSpacing(4)
                .foregroundStyle(Color(hex: 0x8E8E93))
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Theme.reviewDivider).frame(height: 1) }
        }
        .padding(.init(top: 22, leading: 20, bottom: 18, trailing: 20))
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(Theme.reviewPanel)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.reviewDivider).frame(width: 1) }
        .task(id: item.id) {
            meta = MediaMetadata()
            meta = await MetadataLoader.shared.metadata(for: item)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key).foregroundStyle(Color(hex: 0x8E8E93)).frame(width: 96, alignment: .leading)
            Text(value).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct Kbd: View {
    let key: String
    let opacity: Double
    init(_ key: String, opacity: Double) { self.key = key; self.opacity = opacity }

    var body: some View {
        Text(key)
            .font(.system(size: 12))
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 1))
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}

// MARK: - Filmstrip

private struct Filmstrip: View {
    @Environment(LibraryStore.self) private var store
    let session: ReviewSession

    var body: some View {
        let range = max(0, session.index - 5)...min(session.queue.count - 1, session.index + 5)
        HStack(spacing: 8) {
            if !session.queue.isEmpty {
                ForEach(range, id: \.self) { i in
                    FilmCell(item: session.queue[i], current: i == session.index,
                             marked: store.isMarked(session.queue[i])) { session.go(to: i) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(Theme.reviewFilmstrip)
        .overlay(alignment: .top) { Rectangle().fill(Theme.reviewDivider).frame(height: 1) }
    }
}

private struct FilmCell: View {
    let item: MediaItem
    let current: Bool
    let marked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Theme.reviewChip
                .overlay { ThumbnailImage(url: item.id) }
                .overlay(alignment: .bottomLeading) {
                    if item.isVideo {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill").font(.system(size: 7))
                            VideoDuration(url: item.id, item: item)
                        }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
                .overlay {
                    if marked {
                        Color(red: 20 / 255, green: 0, blue: 4 / 255).opacity(0.55)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if marked {
                        Image(systemName: "trash")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Theme.markRing, in: Circle())
                            .padding(4)
                    }
                }
                .frame(width: 80, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay {
                    if marked && !current {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.reviewMarkRing, lineWidth: 2)
                    }
                }
                .padding(2)
                .overlay {
                    if current { RoundedRectangle(cornerRadius: 7).stroke(Theme.text, lineWidth: 2) }
                }
                .opacity(current || marked ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to \(item.name)\(marked ? ", marked" : "")")
    }
}
