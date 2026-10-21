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
                if store.scope.isEmpty {
                    EmptyState(scanning: store.isScanning)
                } else {
                    MediaGrid(items: store.scope)
                }
            }
            .navigationTitle(store.selectedFolder.rawValue)
            .navigationSubtitle(summary)
            .toolbar {
                ToolbarItem {
                    Button { store.startScan() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Rescan")
                        .accessibilityLabel("Rescan folder")
                        .disabled(store.isScanning)
                }
            }
        }
    }

    private var summary: String {
        let v = store.scope.filter(\.isVideo).count
        let i = store.scope.count - v
        return "\(i) image\(i == 1 ? "" : "s") · \(v) video\(v == 1 ? "" : "s")"
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
                        Label("To Be Binned", systemImage: "trash")
                            .foregroundStyle(Theme.text)
                    }
                    .buttonStyle(.plain)
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
