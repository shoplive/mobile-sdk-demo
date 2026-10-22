import Foundation

/// What a shortform request filters by. Maps 1:1 to SDK request fields.
struct ShortformQuery: Equatable {
    var productId: String?
    var url: String?
    var skus: [String]?
    var tags: [String]?
    var collectionId: String?

    static let all = ShortformQuery()
}

/// One step of the matching order (see `demo-config/README.md#matching`).
enum MatchStep: Equatable {
    /// The product's own shortform: `productId`, else `url`, else `skus`.
    case product(ShortformQuery)
    /// The verticals' tags, `tagSearchOperator` OR.
    case verticalTags([String])
    /// The catalog's fallback collection.
    case fallbackCollection(String)
    /// The catalog's fallback tags (used where a collection id cannot be sent).
    case fallbackTags([String])

    /// Steps after the product's own step are shown as "Related shortform".
    var isRelated: Bool {
        if case .product = self { return false }
        return true
    }

    var query: ShortformQuery {
        switch self {
        case .product(let q): return q
        case .verticalTags(let tags), .fallbackTags(let tags): return ShortformQuery(tags: tags)
        case .fallbackCollection(let id): return ShortformQuery(collectionId: id)
        }
    }

    /// A short, non-localized description for the "matched by" label and the event log.
    var matchedBy: String {
        switch self {
        case .product(let q):
            if q.productId != nil { return "productId" }
            if q.url != nil { return "url" }
            return "sku"
        case .verticalTags: return "tags"
        case .fallbackCollection: return "fallback collection"
        case .fallbackTags: return "fallback tags"
        }
    }
}

/// Which request fields an SDK entry point accepts.
enum ShortformSurface: Equatable {
    /// `ShopLiveShortformHorizontalTypeView` / `CardTypeView` / `VerticalTypeView`: skus, tags, collection id.
    case embedded
    /// `ShopLiveShortform.play` with `ShopLiveShortformRelatedData` (productId/url/skus/tags) or
    /// `ShopLiveShortformCollectionData` (collection id).
    case player
    /// `ShopLiveShortform.showPreview` with `ShopLiveShortformPreviewData`: productId/url/skus/tags, no collection id.
    case preview
}

enum ShortformMatcher {
    /// The ordered steps to try for a product. `name` is never used.
    static func steps(for product: Product, in catalog: Catalog, surface: ShortformSurface) -> [MatchStep] {
        var steps: [MatchStep] = []
        if let own = ownQuery(for: product, surface: surface) {
            steps.append(.product(own))
        }
        let tags = unique(catalog.verticals(containing: product.productId).flatMap(\.tags))
        if !tags.isEmpty {
            steps.append(.verticalTags(tags))
        }
        if let fallback = catalog.fallback {
            if let id = fallback.collectionId.nonEmpty, surface != .preview {
                steps.append(.fallbackCollection(id))
            } else if !fallback.tags.isEmpty {
                steps.append(.fallbackTags(unique(fallback.tags)))
            }
        }
        return steps
    }

    /// The product's own query on a surface: `productId`, else `url`, else `skus`.
    /// Embedded list views take skus only, so there the product step needs a `sku`.
    static func ownQuery(for product: Product, surface: ShortformSurface) -> ShortformQuery? {
        let sku = product.sku.nonEmpty
        switch surface {
        case .embedded:
            return sku.map { ShortformQuery(skus: [$0]) }
        case .player, .preview:
            if let id = product.productId.nonEmpty { return ShortformQuery(productId: id) }
            if let url = product.url.nonEmpty { return ShortformQuery(url: url) }
            return sku.map { ShortformQuery(skus: [$0]) }
        }
    }

    /// Translates a step found on one surface to another surface, so a layout switch keeps the same kind of match.
    /// Returns `nil` when the target surface cannot express that step.
    static func step(_ step: MatchStep, on surface: ShortformSurface, for product: Product, in catalog: Catalog) -> MatchStep? {
        let candidates = steps(for: product, in: catalog, surface: surface)
        switch step {
        case .product: return candidates.first { if case .product = $0 { return true }; return false }
        case .verticalTags: return candidates.first { if case .verticalTags = $0 { return true }; return false }
        case .fallbackCollection, .fallbackTags:
            return candidates.first {
                switch $0 {
                case .fallbackCollection, .fallbackTags: return true
                default: return false
                }
            }
        }
    }

    /// Query for the Results strip: the results' skus, else the tags of verticals matching the query.
    static func resultsQuery(for products: [Product], query: String, in catalog: Catalog, limit: Int = 30) -> ShortformQuery? {
        let skus = unique(products.compactMap { $0.sku.nonEmpty })
        if !skus.isEmpty { return ShortformQuery(skus: Array(skus.prefix(limit))) }
        let ids = Set(products.map(\.productId))
        let tags = unique(catalog.verticals.filter { v in v.productIds.contains(where: ids.contains) }.flatMap(\.tags))
        if !tags.isEmpty { return ShortformQuery(tags: tags) }
        return nil
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
