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
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                StatCard(title: "To be binned", value: store.markedItems.count,
                         caption: Format.size(store.markedBytes),
                         titleColor: Theme.destructiveSoftFG, border: Theme.reviewMarkRing.opacity(0.35))
                StatCard(title: "Kept", value: queue.count - markedInQueue,
                         caption: "Stay exactly where they are",
                         titleColor: Theme.textSecondary, border: Theme.reviewDivider)
            }

            HStack(spacing: 12) {
                Button { store.exitReview() } label: {
                    Text("Back to Gallery").font(.system(size: 14, weight: .medium)).padding(.horizontal, 20).frame(height: 44)
                        .background(Theme.reviewChip, in: RoundedRectangle(cornerRadius: 10))
                }
                Button { store.openBin() } label: {
                    Text("Check To Be Binned (\(store.markedItems.count))")
                        .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 22).frame(height: 44)
                        .foregroundStyle(.white)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: 620)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.reviewBG)
        .foregroundStyle(Theme.text)
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
            Text(caption).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.reviewPanel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border))
        .accessibilityElement(children: .combine)
    }
}
