package cloud.shoplive.demo.shortform.catalog

import java.util.Locale

/**
 * Search order (demo-config/README.md#search-order):
 * 1. Demo products — featuredProductIds, then the verticals' productIds — that match.
 *    A vertical whose title or keywords match brings all of its products.
 * 2. Every other matching product.
 * The demo section never disappears: with no demo match it shows featured products instead.
 */
class ProductSearch(private val catalog: Catalog) {

    data class Result(
        val query: String,
        val demoProducts: List<Product>,
        /** True when nothing matched and [demoProducts] holds featured products instead. */
        val demoIsFallback: Boolean,
        val otherProducts: List<Product>,
    ) {
        /** Everything that matched, demo products first. Empty when only the fallback is shown. */
        val matches: List<Product>
            get() = if (demoIsFallback) otherProducts else demoProducts + otherProducts
    }

    fun search(rawQuery: String): Result {
        val query = normalize(rawQuery)
        if (query.isEmpty()) return Result(rawQuery, fallbackDemo(), demoIsFallback = true, otherProducts = emptyList())

        val demoIds = LinkedHashSet<String>()
        catalog.featuredProductIds.forEach { id ->
            catalog.product(id)?.takeIf { matches(it, query) }?.let { demoIds += it.productId }
        }
        for (vertical in catalog.verticals) {
            val verticalMatches = matches(vertical, query)
            for (id in vertical.productIds) {
                val product = catalog.product(id) ?: continue
                if (verticalMatches || matches(product, query)) demoIds += product.productId
            }
        }
        val demo = demoIds.mapNotNull { catalog.product(it) }
        val others = catalog.products.filter { it.productId !in demoIds && matches(it, query) }

        return if (demo.isEmpty()) {
            Result(rawQuery, fallbackDemo(), demoIsFallback = true, otherProducts = others)
        } else {
            Result(rawQuery, demo, demoIsFallback = false, otherProducts = others)
        }
    }

    /** Products for a vertical chip: its productIds, then products matching its keywords. */
    fun productsFor(vertical: Vertical): List<Product> {
        val ids = LinkedHashSet<String>()
        vertical.productIds.forEach { id -> catalog.product(id)?.let { ids += it.productId } }
        val keywords = vertical.keywords.map(::normalize).filter { it.isNotEmpty() }
        catalog.products.forEach { p -> if (keywords.any { k -> matches(p, k) }) ids += p.productId }
        return ids.mapNotNull { catalog.product(it) }
    }

    /** Keywords offered before the user types: vertical keywords first, then product keywords. */
    fun suggestedKeywords(limit: Int = 12): List<String> {
        val seen = LinkedHashMap<String, String>()
        (catalog.verticals.flatMap { it.keywords } + catalog.products.flatMap { it.keywords }).forEach {
            val key = normalize(it)
            if (key.isNotEmpty() && key !in seen) seen[key] = it.trim()
        }
        return seen.values.take(limit)
    }

    private fun fallbackDemo(): List<Product> {
        val featured = catalog.featuredProducts()
        return (featured.ifEmpty { catalog.products }).take(FALLBACK_COUNT)
    }

    companion object {
        const val FALLBACK_COUNT = 4

        fun normalize(text: String): String = text.trim().lowercase(Locale.ROOT)

        fun matches(product: Product, query: String): Boolean =
            normalize(product.name).contains(query) ||
                product.brand?.let { normalize(it).contains(query) } == true ||
                product.keywords.any { normalize(it).contains(query) }

        fun matches(vertical: Vertical, query: String): Boolean =
            vertical.title.all.any { normalize(it).contains(query) } ||
                vertical.keywords.any { normalize(it).contains(query) }
    }
}
