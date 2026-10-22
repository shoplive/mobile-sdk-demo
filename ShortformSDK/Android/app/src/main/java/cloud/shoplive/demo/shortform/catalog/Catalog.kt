package cloud.shoplive.demo.shortform.catalog

import java.util.Locale

/**
 * The demo catalog: products plus the demo setup around them.
 * Format: ShortformSDK/demo-config/README.md and catalog.schema.json.
 */
data class Catalog(
    val version: Int,
    val homeCollectionId: String?,
    val verticals: List<Vertical>,
    val featuredProductIds: List<String>,
    val fallback: Fallback?,
    val products: List<Product>,
) {
    private val byId: Map<String, Product> = products.associateBy { it.productId }

    fun product(productId: String?): Product? = productId?.let { byId[it] }

    fun featuredProducts(): List<Product> = featuredProductIds.mapNotNull { byId[it] }

    fun vertical(id: String?): Vertical? = verticals.firstOrNull { it.id == id }

    /** Verticals that list this product, in catalog order. */
    fun verticalsOf(product: Product): List<Vertical> =
        verticals.filter { product.productId in it.productIds }

    /**
     * Maps a product the Shortform SDK reports (for example a product tapped inside a video)
     * back to a catalog entry: productId, then customerProductId, then sku, then url.
     * The product name is never used.
     */
    fun findSdkProduct(productId: String?, sku: String?, url: String?): Product? {
        val id = productId?.trim().orEmpty()
        if (id.isNotEmpty()) {
            byId[id]?.let { return it }
            products.firstOrNull { it.customerProductId == id }?.let { return it }
        }
        val s = sku?.trim().orEmpty()
        if (s.isNotEmpty()) products.firstOrNull { it.sku == s }?.let { return it }
        val u = url?.let(::normalizeUrl).orEmpty()
        if (u.isNotEmpty()) products.firstOrNull { it.url?.let(::normalizeUrl) == u }?.let { return it }
        return null
    }

    companion object {
        internal fun normalizeUrl(url: String): String = url.trim().trimEnd('/')
    }
}

data class Vertical(
    val id: String,
    val title: Localized,
    val productIds: List<String>,
    val keywords: List<String>,
    val tags: List<String>,
)

data class Fallback(
    val collectionId: String?,
    val tags: List<String>,
)

data class Product(
    val productId: String,
    val customerProductId: String? = null,
    val sku: String? = null,
    val url: String? = null,
    val name: String,
    val brand: String? = null,
    val imageUrls: List<String> = emptyList(),
    val description: String? = null,
    val currency: String,
    val originalPrice: Double,
    val discountPrice: Double? = null,
    val discountRate: Double? = null,
    val keywords: List<String> = emptyList(),
) {
    /** The price a customer pays: the discount price when there is a real discount. */
    val salePrice: Double
        get() = discountPrice?.takeIf { it < originalPrice } ?: originalPrice

    val hasDiscount: Boolean
        get() = discountPrice != null && discountPrice < originalPrice
}

/** A localized string, e.g. { "en": "Fashion", "ko": "패션" }. "en" is required. */
data class Localized(val values: Map<String, String>) {
    fun resolve(locale: Locale = Locale.getDefault()): String =
        values[locale.toLanguageTag()]
            ?: values[locale.language]
            ?: values["en"]
            ?: values.values.firstOrNull()
            .orEmpty()

    val all: Collection<String> get() = values.values
}
