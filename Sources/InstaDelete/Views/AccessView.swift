import SwiftUI

struct AccessView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Find the photos and videos you don’t need anymore")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("InstaDelete scans your Home folder for images and videos — Pictures, Movies, Desktop, Downloads, Documents and the rest — and lets you review them one at a time.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                PromiseRow(symbol: "folder", title: "Read access to your Home folder",
                           text: "Needed to find every image and video. InstaDelete only reads files until you approve a move.")
                PromiseRow(symbol: "checkmark.shield", title: "Never deletes anything",
                           text: "Files you approve are moved to the Bin, so you can put them back from Finder.")
                PromiseRow(symbol: "touchid", title: "You approve every move, twice",
                           text: "Moving to the Bin needs a confirmation and Touch ID or your Mac password.")
            }
            .padding(20)
            .background(Theme.cardBG, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder))

            VStack(spacing: 6) {
                Button { store.grantAccess(home: true) } label: {
                    Text("Grant Access to Home Folder…")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 300, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)

                Button("Choose a Specific Folder Instead") { store.grantAccess(home: false) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14, weight: .medium))
                    .frame(height: 36)
            }

            Text("macOS will ask you to confirm. You can change this later in System Settings › Privacy & Security › Files and Folders.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 580)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBG)
        .foregroundStyle(Theme.text)
    }
}

private struct PromiseRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentSoftBG, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(text).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
