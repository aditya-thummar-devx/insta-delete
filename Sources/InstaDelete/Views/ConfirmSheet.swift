import SwiftUI

struct ConfirmSheet: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.destructive)
                        .frame(width: 28, height: 28)
                        .background(Theme.windowBG, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .offset(x: 8, y: 8)
                }
                .accessibilityHidden(true)

            Text("Move \(Format.mix(store.markedItems)) to the Bin?")
                .font(.system(size: 15, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Text("They’ll go to the Bin in Finder (\(Format.size(store.markedBytes))). You can put them back until you empty the Bin. InstaDelete never deletes anything.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
            Text("Next, macOS will ask for Touch ID or your password.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button("Cancel") { store.confirmingMove = false }
                    .keyboardShortcut(.cancelAction)
                    .frame(maxWidth: .infinity)
                Button("Move to Bin") { Task { await store.performMove() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.destructive)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(.init(top: 24, leading: 20, bottom: 18, trailing: 20))
        .frame(width: 380)
    }
}
