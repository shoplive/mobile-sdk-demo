import UIKit

/// Checks, one product at a time, whether products have their own shortform (by `sku`), for the ▶ badge.
/// Uses an invisible embedded list view; results go to `AvailabilityStore`.
final class AvailabilityChecker {
    private let probe = ShortformEmbedView()
    private var queue: [Product] = []
    private var current: Product?

    /// Adds the invisible probe view to `container`.
    init(container: UIView) {
        probe.alpha = 0
        probe.isUserInteractionEnabled = false
        probe.accessibilityElementsHidden = true
        probe.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(probe, at: 0)
        NSLayoutConstraint.activate([
            probe.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            probe.widthAnchor.constraint(equalToConstant: 240),
            probe.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        probe.onResult = { [weak self] result in self?.handle(result) }
    }

    /// Checks products that have a `sku` and were not checked yet.
    func check(_ products: [Product]) {
        let store = AvailabilityStore.shared
        queue = products.filter { $0.sku.nonEmpty != nil && store.hasShortform($0.productId) == nil }
        if current == nil { next() }
    }

    private func next() {
        guard !queue.isEmpty else {
            current = nil
            probe.stopVideos()
            return
        }
        let product = queue.removeFirst()
        current = product
        guard let query = ShortformMatcher.ownQuery(for: product, surface: .embedded) else { return next() }
        var style = ShortformEmbedView.Style()
        style.autoplay = false
        probe.configure(kind: .horizontal, query: query, style: style, height: 120)
    }

    private func handle(_ result: ShortformEmbedView.LoadResult) {
        if let product = current, result != .failed {
            AvailabilityStore.shared.set(product.productId, hasShortform: result == .found)
            EventLog.shared.add("availability", "\(product.productId)=\(result == .found)")
        }
        next()
    }
}
