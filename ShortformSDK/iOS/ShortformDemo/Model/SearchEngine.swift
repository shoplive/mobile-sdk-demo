import Foundation

/// Search order (see `demo-config/README.md#search-order`):
/// 1. Demo products — `featuredProductIds`, then the verticals' `productIds` (verticals matching the query first) —
///    whose name, brand or keywords match.
/// 2. Every other matching product.
/// The demo section never disappears: with no match it shows a few featured products instead.
enum SearchEngine {
    struct Result: Equatable {
        /// Demo products, in demo order.
        var demo: [Product]
        /// `true` when nothing matched and `demo` holds featured products as a placeholder.
        var demoIsPlaceholder: Bool
        /// Other matching products, in catalog order.
        var others: [Product]

        /// Demo products followed by other products, without the placeholder ones.
        var allMatches: [Product] { (demoIsPlaceholder ? [] : demo) + others }
    }

    static let placeholderCount = 4

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Demo product ids in demo order, unique. Verticals whose title or keywords match `query` come first.
    static func demoProductIds(in catalog: Catalog, query: String = "") -> [String] {
        let q = normalize(query)
        let matching = catalog.verticals.filter { !q.isEmpty && verticalMatches($0, q) }
        let rest = catalog.verticals.filter { v in !matching.contains(where: { $0.id == v.id }) }
        var ids: [String] = []
        for id in catalog.featuredProductIds + (matching + rest).flatMap(\.productIds) where !ids.contains(id) {
            if catalog.product(id: id) != nil { ids.append(id) }
        }
        return ids
    }

    static func search(_ query: String, in catalog: Catalog, placeholderCount: Int = placeholderCount) -> Result {
        let q = normalize(query)
        let demoIds = demoProductIds(in: catalog, query: query)
        guard !q.isEmpty else {
            return Result(demo: placeholder(catalog, demoIds, placeholderCount), demoIsPlaceholder: true, others: [])
        }
        let demo = demoIds.compactMap { catalog.product(id: $0) }.filter { matches($0, q, in: catalog) }
        let others = catalog.products.filter { !demoIds.contains($0.productId) && matches($0, q, in: catalog) }
        if demo.isEmpty {
            return Result(demo: placeholder(catalog, demoIds, placeholderCount), demoIsPlaceholder: true, others: others)
        }
        return Result(demo: demo, demoIsPlaceholder: false, others: others)
    }

    /// Keywords for the "Suggested keywords" list: vertical keywords in catalog order, unique.
    static func suggestedKeywords(in catalog: Catalog, limit: Int = 12) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for keyword in catalog.verticals.flatMap(\.keywords) {
            let key = normalize(keyword)
            if !key.isEmpty, seen.insert(key).inserted { result.append(keyword) }
            if result.count == limit { break }
        }
        return result
    }

    // MARK: - Private

    private static func placeholder(_ catalog: Catalog, _ demoIds: [String], _ count: Int) -> [Product] {
        let featured = catalog.featuredProducts
        let source = featured.isEmpty ? demoIds.compactMap { catalog.product(id: $0) } : featured
        return Array(source.prefix(count))
    }

    private static func verticalMatches(_ vertical: Catalog.Vertical, _ q: String) -> Bool {
        let fields = Array(vertical.title.values.values) + vertical.keywords
        return fields.contains { normalize($0).contains(q) }
    }

    /// Name, brand and keywords of the product — never ids, skus or urls.
    private static func matches(_ product: Product, _ q: String, in catalog: Catalog) -> Bool {
        let fields = [product.name, product.brand ?? ""] + product.keywords
        return fields.contains { normalize($0).contains(q) }
    }
}
