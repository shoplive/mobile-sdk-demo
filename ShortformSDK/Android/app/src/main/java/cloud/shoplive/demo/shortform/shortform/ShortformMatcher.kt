package cloud.shoplive.demo.shortform.shortform

import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.Product

/**
 * What the app asks the Shortform SDK for. Pure data, so matching can be unit-tested without the SDK.
 *
 * A product condition ([isProduct]: productId, url or skus of one product) goes through the related
 * API: `ShopLiveShortformRelatedData` with `setRelatedData` / `get(relatedData)` / `play(relatedData)`.
 * Everything else (tags, a collection id, the skus of several products) goes through
 * `ShopLiveShortformCollectionData` and the collection setters.
 */
data class ShortformCondition(
    val productId: String? = null,
    val url: String? = null,
    val skus: List<String> = emptyList(),
    val tags: List<String> = emptyList(),
    val collectionId: String? = null,
    val isProduct: Boolean = false,
) {
    companion object {
        /** No condition: the SDK returns the default shortform list of the account. */
        val NONE = ShortformCondition()

        fun product(productId: String? = null, url: String? = null, skus: List<String> = emptyList()) =
            ShortformCondition(productId = productId, url = url, skus = skus, isProduct = true)
    }
}

/** One step of the matching order (demo-config/README.md#matching). */
data class MatchStep(val kind: Kind, val condition: ShortformCondition) {
    enum class Kind { PRODUCT, VERTICAL_TAGS, FALLBACK }

    /** Steps 2 and 3 are labelled "Related shortform" on screen. */
    val isRelated: Boolean get() = kind != Kind.PRODUCT
}

/**
 * Builds the matching steps for a product (demo-config/README.md#matching). The name is never used.
 *
 * 1. The product: productId, else url, else skus — the same for every layout.
 * 2. The tags of the verticals that list the product (OR).
 * 3. The fallback collection, or without one the fallback tags.
 *
 * [forPreview] leaves out a collection id, which `ShopLiveShortformPreviewData` cannot take; the
 * fallback tags are used instead when the catalog has them.
 */
object ShortformMatcher {

    fun steps(product: Product, catalog: Catalog, forPreview: Boolean = false): List<MatchStep> =
        listOfNotNull(productStep(product)) + relatedSteps(product, catalog, forPreview)

    /** Step 1 alone: the product's own shortform. */
    fun productStep(product: Product): MatchStep? {
        val condition = when {
            product.productId.isNotBlank() -> ShortformCondition.product(productId = product.productId)
            !product.url.isNullOrBlank() -> ShortformCondition.product(url = product.url)
            !product.sku.isNullOrBlank() -> ShortformCondition.product(skus = listOf(product.sku))
            else -> return null
        }
        return MatchStep(MatchStep.Kind.PRODUCT, condition)
    }

    private fun relatedSteps(product: Product, catalog: Catalog, forPreview: Boolean): List<MatchStep> {
        val steps = mutableListOf<MatchStep>()
        val tags = catalog.verticalsOf(product).flatMap { it.tags }.filter { it.isNotBlank() }.distinct()
        if (tags.isNotEmpty()) steps += MatchStep(MatchStep.Kind.VERTICAL_TAGS, ShortformCondition(tags = tags))

        val collectionId = catalog.fallback?.collectionId?.takeIf { it.isNotBlank() && !forPreview }
        val fallbackTags = catalog.fallback?.tags.orEmpty().filter { it.isNotBlank() }
        when {
            collectionId != null ->
                steps += MatchStep(MatchStep.Kind.FALLBACK, ShortformCondition(collectionId = collectionId))
            fallbackTags.isNotEmpty() ->
                steps += MatchStep(MatchStep.Kind.FALLBACK, ShortformCondition(tags = fallbackTags))
        }
        return steps
    }

    /** Condition for a strip of several products (Results): their skus. Null when none has one. */
    fun forProducts(products: List<Product>): ShortformCondition? {
        val skus = products.mapNotNull { it.sku?.takeIf(String::isNotBlank) }.distinct()
        return if (skus.isEmpty()) null else ShortformCondition(skus = skus)
    }

    /** The "Today's shortform" strip on Home: the home collection, else no condition. */
    fun forHome(catalog: Catalog): ShortformCondition =
        catalog.homeCollectionId?.takeIf { it.isNotBlank() }
            ?.let { ShortformCondition(collectionId = it) }
            ?: ShortformCondition.NONE

    /**
     * Picks the step to show, given which steps returned shortform. [hasShortform] is asked in
     * order and the first step with shortform wins; null when none has any.
     */
    inline fun firstWithShortform(steps: List<MatchStep>, hasShortform: (MatchStep) -> Boolean): MatchStep? =
        steps.firstOrNull(hasShortform)
}
