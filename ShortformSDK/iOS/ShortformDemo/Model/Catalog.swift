import Foundation

/// The demo catalog (see `ShortformSDK/demo-config/catalog.schema.json`).
///
/// Missing optional arrays decode as empty, so a minimal catalog with only `version` and `products` is valid.
struct Catalog: Codable, Equatable {
    struct Home: Codable, Equatable {
        var collectionId: String?
    }

    struct Vertical: Codable, Equatable {
        var id: String
        var title: LocalizedText
        var productIds: [String]
        var keywords: [String]
        var tags: [String]

        init(id: String, title: LocalizedText, productIds: [String] = [], keywords: [String] = [], tags: [String] = []) {
            self.id = id
            self.title = title
            self.productIds = productIds
            self.keywords = keywords
            self.tags = tags
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = try c.decode(LocalizedText.self, forKey: .title)
            productIds = try c.decodeIfPresent([String].self, forKey: .productIds) ?? []
            keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
            tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        }
    }

    struct Fallback: Codable, Equatable {
        var collectionId: String?
        var tags: [String]

        init(collectionId: String? = nil, tags: [String] = []) {
            self.collectionId = collectionId
            self.tags = tags
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            collectionId = try c.decodeIfPresent(String.self, forKey: .collectionId)
            tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        }
    }

    var version: Int
    var home: Home?
    var verticals: [Vertical]
    var featuredProductIds: [String]
    var fallback: Fallback?
    var products: [Product]

    init(version: Int = 1, home: Home? = nil, verticals: [Vertical] = [], featuredProductIds: [String] = [],
         fallback: Fallback? = nil, products: [Product]) {
        self.version = version
        self.home = home
        self.verticals = verticals
        self.featuredProductIds = featuredProductIds
        self.fallback = fallback
        self.products = products
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        home = try c.decodeIfPresent(Home.self, forKey: .home)
        verticals = try c.decodeIfPresent([Vertical].self, forKey: .verticals) ?? []
        featuredProductIds = try c.decodeIfPresent([String].self, forKey: .featuredProductIds) ?? []
        fallback = try c.decodeIfPresent(Fallback.self, forKey: .fallback)
        products = try c.decode([Product].self, forKey: .products)
    }

    // MARK: - Parsing

    enum ParseError: Error, Equatable {
        case unsupportedVersion(Int)
        case emptyProductId
        case duplicateProductId(String)
    }

    static let supportedVersion = 1

    /// Decodes and checks a catalog document. Unknown product ids in `featuredProductIds` or `verticals` are allowed
    /// (they are skipped when the catalog is used).
    static func parse(_ data: Data) throws -> Catalog {
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        guard catalog.version == supportedVersion else { throw ParseError.unsupportedVersion(catalog.version) }
        var seen = Set<String>()
        for product in catalog.products {
            if product.productId.isEmpty { throw ParseError.emptyProductId }
            if !seen.insert(product.productId).inserted { throw ParseError.duplicateProductId(product.productId) }
        }
        return catalog
    }

    // MARK: - Lookups

    func product(id: String) -> Product? {
        products.first { $0.productId == id }
    }

    /// Verticals that list the product in `productIds`.
    func verticals(containing productId: String) -> [Vertical] {
        verticals.filter { $0.productIds.contains(productId) }
    }

    /// Featured products in catalog order of `featuredProductIds`, unknown ids skipped.
    var featuredProducts: [Product] {
        featuredProductIds.compactMap { product(id: $0) }
    }

    /// Products of a vertical: its `productIds` first, then other products whose keywords match the vertical's keywords.
    func products(in vertical: Vertical) -> [Product] {
        var result = vertical.productIds.compactMap { product(id: $0) }
        let keywords = vertical.keywords.map(SearchEngine.normalize)
        for product in products where !result.contains(product) {
            let productKeywords = product.keywords.map(SearchEngine.normalize)
            if productKeywords.contains(where: { keywords.contains($0) }) {
                result.append(product)
            }
        }
        return result
    }

    /// Maps a product reported by the SDK (for example in `onProductClick`) back to a catalog entry.
    /// Order: `productId`, `customerProductId`, `sku`, `url`. Names are never used.
    func product(matching ref: ProductRef) -> Product? {
        if let id = ref.productId.nonEmpty, let p = products.first(where: { $0.productId == id }) { return p }
        if let id = ref.customerProductId.nonEmpty,
           let p = products.first(where: { $0.customerProductId == id || $0.productId == id }) { return p }
        if let sku = ref.sku.nonEmpty, let p = products.first(where: { $0.sku == sku }) { return p }
        if let url = ref.url.nonEmpty, let p = products.first(where: { $0.url == url }) { return p }
        return nil
    }
}

/// A product as identified by the SDK: only the fields used to find it in the catalog.
struct ProductRef: Equatable {
    var productId: String?
    var customerProductId: String?
    var sku: String?
    var url: String?
}

struct Product: Codable, Equatable, Hashable {
    var productId: String
    var customerProductId: String?
    var sku: String?
    var url: String?
    var name: String
    var brand: String?
    var imageUrls: [String]
    var description: String?
    var currency: String
    var originalPrice: Double
    var discountPrice: Double?
    var discountRate: Double?
    var keywords: [String]

    init(productId: String, customerProductId: String? = nil, sku: String? = nil, url: String? = nil, name: String,
         brand: String? = nil, imageUrls: [String] = [], description: String? = nil, currency: String = "KRW",
         originalPrice: Double = 0, discountPrice: Double? = nil, discountRate: Double? = nil, keywords: [String] = []) {
        self.productId = productId
        self.customerProductId = customerProductId
        self.sku = sku
        self.url = url
        self.name = name
        self.brand = brand
        self.imageUrls = imageUrls
        self.description = description
        self.currency = currency
        self.originalPrice = originalPrice
        self.discountPrice = discountPrice
        self.discountRate = discountRate
        self.keywords = keywords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productId = try c.decode(String.self, forKey: .productId)
        customerProductId = try c.decodeIfPresent(String.self, forKey: .customerProductId)
        sku = try c.decodeIfPresent(String.self, forKey: .sku)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        imageUrls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        description = try c.decodeIfPresent(String.self, forKey: .description)
        currency = try c.decode(String.self, forKey: .currency)
        originalPrice = try c.decode(Double.self, forKey: .originalPrice)
        discountPrice = try c.decodeIfPresent(Double.self, forKey: .discountPrice)
        discountRate = try c.decodeIfPresent(Double.self, forKey: .discountRate)
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }

    /// The price the customer pays: the discount price when it is lower than the original price.
    var salePrice: Double {
        if let discountPrice, discountPrice < originalPrice { return discountPrice }
        return originalPrice
    }

    var hasDiscount: Bool { salePrice < originalPrice }
}

/// `{ "en": "Fashion", "ko": "패션" }` — `en` is required and used when no better match exists.
struct LocalizedText: Codable, Equatable {
    var values: [String: String]

    init(_ values: [String: String]) { self.values = values }

    init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: String].self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(values)
    }

    /// Picks the value for a language code such as `ko` or `ko-KR`, falling back to `en`, then any value.
    func resolved(for languageCode: String?) -> String {
        if let code = languageCode?.lowercased() {
            if let exact = values[code] { return exact }
            let base = String(code.prefix { $0 != "-" && $0 != "_" })
            if let v = values[base] { return v }
        }
        return values["en"] ?? values.values.sorted().first ?? ""
    }

    var current: String { resolved(for: Locale.preferredLanguages.first) }
}

extension String {
    /// The trimmed string when it has non-whitespace content.
    var nonEmpty: String? {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}

extension Optional where Wrapped == String {
    /// The string when it has non-whitespace content.
    var nonEmpty: String? {
        guard let s = self?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}
