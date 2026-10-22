package cloud.shoplive.demo.shortform.shortform

import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.Product

/**
 * What the app asks the Shortform SDK for. Exactly one kind of condition is set.
 * Pure data, so matching can be unit-tested without the SDK.
 */
data class ShortformCondition(
    val productId: String? = null,
    val url: String? = null,
    val skus: List<String> = emptyList(),
    val tags: List<String> = emptyList(),
    val collectionId: String? = null,
) {
    companion object {
        /** No condition: the SDK returns the default shortform list of the account. */
        val NONE = ShortformCondition()
    }
}

/** One step of the matching order (demo-config/README.md#matching). */
data class MatchStep(val kind: Kind, val condition: ShortformCondition) {
    enum class Kind { PRODUCT, VERTICAL_TAGS, FALLBACK }

    /** Steps 2 and 3 are labelled "Related shortform" on screen. */
    val isRelated: Boolean get() = kind != Kind.PRODUCT
}

/**
 * Builds the matching steps for a product. The product name is never used.
 *
 * Step 1 depends on what the SDK call accepts:
 * - [forPreview] — `ShopLiveShortformPreviewData` takes productId, url and skus, so step 1 is
 *   productId, else url, else skus.
 * - [forListViews] — the list views (`HorizontalTypeView` / `CardTypeView` / `VerticalTypeView`),
 *   `ShopLiveShortform.get` and `ShopLiveShortform.play` take skus (plus tags, brands and a
 *   collection id) in SDK 1.9.1, so step 1 is the product's sku; without a sku it is skipped.
 *
 * Step 2 is the tags of the verticals that list the product (OR). Step 3 is the fallback
 * collection (or, without one, the fallback tags).
 */
object ShortformMatcher {

    fun forListViews(product: Product, catalog: Catalog): List<MatchStep> =
        listOfNotNull(skuStep(product)) + relatedSteps(product, catalog)

    fun forPreview(product: Product, catalog: Catalog): List<MatchStep> =
        listOfNotNull(previewProductStep(product)) + relatedSteps(product, catalog)

    private fun skuStep(product: Product): MatchStep? =
        product.sku?.takeIf { it.isNotBlank() }?.let {
            MatchStep(MatchStep.Kind.PRODUCT, ShortformCondition(skus = listOf(it)))
        }

    private fun previewProductStep(product: Product): MatchStep? {
        val condition = when {
            product.productId.isNotBlank() -> ShortformCondition(productId = product.productId)
            !product.url.isNullOrBlank() -> ShortformCondition(url = product.url)
            !product.sku.isNullOrBlank() -> ShortformCondition(skus = listOf(product.sku))
            else -> return null
        }
        return MatchStep(MatchStep.Kind.PRODUCT, condition)
    }

    private fun relatedSteps(product: Product, catalog: Catalog): List<MatchStep> {
        val steps = mutableListOf<MatchStep>()
        val tags = catalog.verticalsOf(product).flatMap { it.tags }.filter { it.isNotBlank() }.distinct()
        if (tags.isNotEmpty()) steps += MatchStep(MatchStep.Kind.VERTICAL_TAGS, ShortformCondition(tags = tags))

        val fallback = catalog.fallback
        when {
            !fallback?.collectionId.isNullOrBlank() ->
                steps += MatchStep(MatchStep.Kind.FALLBACK, ShortformCondition(collectionId = fallback!!.collectionId))
            !fallback?.tags.isNullOrEmpty() ->
                steps += MatchStep(MatchStep.Kind.FALLBACK, ShortformCondition(tags = fallback!!.tags))
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
