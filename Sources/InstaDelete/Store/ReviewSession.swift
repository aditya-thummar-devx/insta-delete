import Observation

/// One slideshow pass over a frozen queue (the scope at the moment review started).
@Observable
@MainActor
final class ReviewSession {
    let queue: [MediaItem]
    let scopeLabel: String
    private(set) var index: Int

    init(queue: [MediaItem], index: Int, scopeLabel: String) {
        self.queue = queue
        self.scopeLabel = scopeLabel
        self.index = queue.isEmpty ? 0 : min(max(0, index), queue.count - 1)
    }

    var current: MediaItem? { queue.indices.contains(index) ? queue[index] : nil }
    var isLast: Bool { index >= queue.count - 1 }

    func go(to i: Int) {
        guard !queue.isEmpty else { return }
        index = min(max(0, i), queue.count - 1)
    }

    func previous() { go(to: index - 1) }

    /// Moves forward; returns false when already on the last item (caller finishes the review).
    @discardableResult
    func advance() -> Bool {
        if isLast { return false }
        index += 1
        return true
    }
}
