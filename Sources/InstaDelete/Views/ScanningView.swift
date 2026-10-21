import SwiftUI

struct ScanningView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SCANNING")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.accent)
                Text("Looking for images and videos in your Home folder…")
                    .font(.system(size: 28, weight: .bold))
                Text("System folders, app bundles and caches are skipped.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    HStack(spacing: 28) {
                        Counter(value: store.imageCount, label: "images")
                        Counter(value: store.videoCount, label: "videos")
                    }
                    Spacer()
                    Text("\(Int(store.scanFraction * 100))%")
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                ProgressView(value: store.scanFraction)
                    .tint(Theme.accent)
                Text(store.currentPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(height: 16, alignment: .leading)
            }

            VStack(spacing: 0) {
                ForEach(Array(Scanner.folderOrder.enumerated()), id: \.element) { index, folder in
                    FolderRow(folder: folder, state: store.folderStatus[folder] ?? .waiting)
                    if index < Scanner.folderOrder.count - 1 { Divider() }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xE5E5EA)))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Spacer()
                Button("Stop Scan") { store.stopScan() }
                    .controlSize(.large)
                Button("Show What’s Found So Far") { store.showFoundSoFar() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.large)
            }
        }
        .frame(width: 600)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .foregroundStyle(Theme.text)
    }
}

private struct Counter: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(size: 36, weight: .bold).monospacedDigit())
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FolderRow: View {
    let folder: Folder
    let state: FolderScanState

    var body: some View {
        HStack(spacing: 12) {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle").foregroundStyle(Color(hex: 0x1E7B34))
                    .accessibilityLabel("Done")
            case .scanning:
                ProgressView().controlSize(.small).accessibilityLabel("Scanning")
            case .waiting:
                Image(systemName: "circle").foregroundStyle(Color(hex: 0xAEAEB2))
                    .accessibilityLabel("Waiting")
            }
            Text(folder == .other ? "Other folders in Home" : folder.rawValue)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text(state == .done ? "Done" : state == .scanning ? "Scanning…" : "Waiting")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
