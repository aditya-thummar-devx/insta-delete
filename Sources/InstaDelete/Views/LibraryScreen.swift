import SwiftUI

struct LibraryScreen: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(230)
        } detail: {
            VStack(spacing: 8) {
                Text("No photos or videos yet")
                    .font(.system(size: 17, weight: .semibold))
                Text("Grant access to a folder to start scanning.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(store.selectedFolder.rawValue)
        }
    }
}

struct SidebarView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        @Bindable var store = store
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
