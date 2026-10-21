import SwiftUI

struct ToastView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.successFG)
                .frame(width: 36, height: 36)
                .background(Theme.successBG, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.toastTitle).font(.system(size: 14, weight: .semibold))
                Text(store.toastSubtitle).font(.system(size: 12)).foregroundStyle(Color(hex: 0xA1A1A6))
            }
            Spacer(minLength: 8)
            Button("Undo") { store.undoMove() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(hex: 0x2E2E33), in: RoundedRectangle(cornerRadius: 7))
            Button { store.dismissToast() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(hex: 0xC7C7CC))
            .accessibilityLabel("Dismiss")
        }
        .foregroundStyle(Color(hex: 0xF5F5F7))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 620)
        .background(Color(hex: 0x1D1D1F), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 16)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }
}
