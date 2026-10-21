import SwiftUI

struct LibraryScreen: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(230)
        } detail: {
            VStack(spacing: 0) {
                if store.isScanning { ScanBanner() }
                if store.libraryView == .bin {
                    BinListView()
                } else {
                    FilterBar()
                    if store.scope.isEmpty {
                        EmptyState(scanning: store.isScanning)
                    } else {
                        MediaGrid(items: store.scope)
                    }
                }
            }
            .navigationTitle(store.libraryView == .bin ? "To Be Binned" : store.selectedFolder.rawValue)
            .navigationSubtitle(summary)
            .toolbar { LibraryToolbar() }
        }
    }

    private var summary: String {
        if store.libraryView == .bin { return "\(Format.mix(store.markedItems)) · \(Format.size(store.markedBytes))" }
        let v = store.scope.filter(\.isVideo).count
        let i = store.scope.count - v
        return "\(Format.plural(i, "image")) · \(Format.plural(v, "video"))"
    }
}

private struct LibraryToolbar: ToolbarContent {
    @Environment(LibraryStore.self) private var store

    var body: some ToolbarContent {
        ToolbarItemGroup {
            if store.libraryView == .all {
                Button { store.startScan() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Rescan")
                    .accessibilityLabel("Rescan folder")
                    .disabled(store.isScanning)
                Button { store.libraryView = .bin } label: {
                    Label("To Be Binned (\(store.markedItems.count))", systemImage: "trash")
                }
                Button { store.startReview() } label: {
                    Label("Start Slideshow Review", systemImage: "play.fill")
                }
                .disabled(store.scope.isEmpty)
            } else {
                Button("Review Again") { store.libraryView = .all; store.startReview() }
                    .disabled(store.scope.isEmpty)
                Button("Unmark All") { store.unmarkAll() }
                    .disabled(store.markedItems.isEmpty)
            }
        }
    }
}

private struct FilterBar: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        @Bindable var store = store
        HStack(spacing: 12) {
            Picker("Filter by type", selection: $store.typeFilter) {
                ForEach(TypeFilter.allCases) { f in
                    Text("\(f.rawValue) \(store.typeCounts[f] ?? 0)").tag(f)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            Menu {
                Picker("Sort by", selection: Binding(get: { store.sortKey }, set: { store.setSort($0) })) {
                    ForEach(SortKey.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Picker("Order", selection: $store.sortAscending) {
                    Text(store.sortKey.orderLabels.asc).tag(true)
                    Text(store.sortKey.orderLabels.desc).tag(false)
                }
                .pickerStyle(.inline)
            } label: {
                Label {
                    Text("Sort: ").foregroundStyle(Theme.textSecondary)
                        + Text(store.sortKey.rawValue).fontWeight(.semibold)
                        + Text(store.sortAscending ? " ↑" : " ↓").foregroundStyle(Theme.textSecondary)
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            .fixedSize()
            .accessibilityLabel("Sort: \(store.sortKey.rawValue), \(store.sortAscending ? store.sortKey.orderLabels.asc : store.sortKey.orderLabels.desc)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

private struct EmptyState: View {
    let scanning: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(scanning ? "Scanning…" : "No photos or videos here")
                .font(.system(size: 17, weight: .semibold))
            Text(scanning ? "Items appear as they’re found." : "Try another folder or rescan.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScanBanner: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Still scanning… \(store.imageCount + store.videoCount) found so far")
                .font(.system(size: 13))
            Spacer()
            Button("Stop") { store.stopScan() }.controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(hex: 0xEEF4FC))
    }
}

struct SidebarView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding(
                get: { store.libraryView == .all ? store.selectedFolder : nil },
                set: { if let f = $0 { store.selectedFolder = f; store.libraryView = .all } }
            )) {
                Section("Library") {
                    ForEach([Folder.all] + Folder.named) { folder in
                        HStack {
                            Label(folder.rawValue, systemImage: "folder")
                            Spacer()
                            Text("\(store.count(in: folder))")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .tag(folder)
                    }
                }
                Section("Review") {
                    Button {
                        store.libraryView = .bin
                    } label: {
                        HStack {
                            Label("To Be Binned", systemImage: "trash")
                            Spacer()
                            let n = store.markedItems.count
                            Text("\(n)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(n == 0 ? Theme.textSecondary : .white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 1)
                                .background(n == 0 ? Color.clear : Theme.destructive, in: Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(store.libraryView == .bin ? Theme.sidebarSelected : Color.clear)
                }
            }
            .listStyle(.sidebar)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield")
                Text("InstaDelete never deletes. Approved files move to the Bin.")
            }
            .font(.system(size: 11))
            .foregroundStyle(Color(hex: 0x4A4A4F))
            .padding(10)
            .background(Color(hex: 0xE9E9EE), in: RoundedRectangle(cornerRadius: 8))
            .padding(10)
        }
    }
}
