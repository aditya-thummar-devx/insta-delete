import SwiftUI

struct ReviewCompleteView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        let queue = store.review?.queue ?? []
        let markedInQueue = queue.filter { store.isMarked($0) }.count
        VStack(spacing: 28) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.successFG)
                .frame(width: 72, height: 72)
                .background(Theme.successBG, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("You’ve reviewed all \(queue.count) items")
                    .font(.system(size: 30, weight: .bold))
                Text("\(store.review?.scopeLabel ?? "") · \(Format.mix(queue)). Nothing has been moved yet — check your list before anything goes to the Bin.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: 0xA1A1A6))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                StatCard(title: "To be binned", value: store.markedItems.count,
                         caption: Format.size(store.markedBytes),
                         titleColor: Color(hex: 0xFFB4B0), border: Color(hex: 0x3A1A1E))
                StatCard(title: "Kept", value: queue.count - markedInQueue,
                         caption: "Stay exactly where they are",
                         titleColor: Color(hex: 0xA1A1A6), border: Color(hex: 0x2A2A2E))
            }

            HStack(spacing: 12) {
                Button { store.exitReview() } label: {
                    Text("Back to Gallery").font(.system(size: 14, weight: .medium)).padding(.horizontal, 20).frame(height: 44)
                        .background(Color(hex: 0x2A2A2E), in: RoundedRectangle(cornerRadius: 10))
                }
                Button { store.openBin() } label: {
                    Text("Check To Be Binned (\(store.markedItems.count))")
                        .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 22).frame(height: 44)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: 620)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.reviewBG)
        .foregroundStyle(Color(hex: 0xF5F5F7))
        .preferredColorScheme(.dark)
    }
}

private struct StatCard: View {
    let title: String
    let value: Int
    let caption: String
    let titleColor: Color
    let border: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(titleColor)
            Text("\(value)").font(.system(size: 32, weight: .bold).monospacedDigit())
            Text(caption).font(.system(size: 13)).foregroundStyle(Color(hex: 0xA1A1A6))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0x1F1F23), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border))
        .accessibilityElement(children: .combine)
    }
}
