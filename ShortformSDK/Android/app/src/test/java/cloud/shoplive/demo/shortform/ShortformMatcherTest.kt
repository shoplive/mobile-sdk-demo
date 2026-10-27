package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.catalog.CatalogParser
import cloud.shoplive.demo.shortform.catalog.Product
import cloud.shoplive.demo.shortform.shortform.MatchStep
import cloud.shoplive.demo.shortform.shortform.ShortformCondition
import cloud.shoplive.demo.shortform.shortform.ShortformMatcher
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ShortformMatcherTest {

    private val catalog = TestCatalogs.full()

    @Test
    fun `product, then vertical tags, then fallback collection`() {
        val steps = ShortformMatcher.steps(catalog.product("P-1")!!, catalog)
        assertEquals(
            listOf(MatchStep.Kind.PRODUCT, MatchStep.Kind.VERTICAL_TAGS, MatchStep.Kind.FALLBACK),
            steps.map { it.kind },
        )
        // Step 1 is productId only, even though the product also has a url and a sku.
        assertEquals(ShortformCondition.product(productId = "P-1"), steps[0].condition)
        assertTrue(steps[0].condition.isProduct)
        assertEquals(ShortformCondition(tags = listOf("fall-look", "knitwear")), steps[1].condition)
        assertFalse(steps[1].condition.isProduct)
        assertEquals(ShortformCondition(collectionId = "fallback-col"), steps[2].condition)
        assertFalse(steps[0].isRelated)
        assertTrue(steps[1].isRelated)
        assertTrue(steps[2].isRelated)
    }

    @Test
    fun `step 1 is productId, else url, else skus`() {
        val base = Product(productId = "", name = "Knit", currency = "KRW", originalPrice = 1.0)
        assertEquals(
            ShortformCondition.product(url = "https://example.com/p"),
            ShortformMatcher.productStep(base.copy(url = "https://example.com/p", sku = "S"))?.condition,
        )
        assertEquals(
            ShortformCondition.product(skus = listOf("S")),
            ShortformMatcher.productStep(base.copy(sku = "S"))?.condition,
        )
        // The name is never used: no id, url or sku means no product step.
        assertNull(ShortformMatcher.productStep(base))
    }

    @Test
    fun `a product without vertical tags goes from itself to the fallback`() {
        val steps = ShortformMatcher.steps(catalog.product("P-3")!!, catalog)
        assertEquals(listOf(MatchStep.Kind.PRODUCT, MatchStep.Kind.FALLBACK), steps.map { it.kind })
    }

    @Test
    fun `fallback tags are used when there is no fallback collection`() {
        val c = CatalogParser.parse(
            """{ "version": 1, "fallback": { "tags": ["picks"] },
                 "products": [ { "productId": "a", "name": "A", "currency": "KRW", "originalPrice": 1 } ] }""",
        )
        val steps = ShortformMatcher.steps(c.product("a")!!, c)
        assertEquals(
            listOf(ShortformCondition.product(productId = "a"), ShortformCondition(tags = listOf("picks"))),
            steps.map { it.condition },
        )
    }

    @Test
    fun `preview steps never carry a collection id`() {
        val steps = ShortformMatcher.steps(catalog.product("P-1")!!, catalog, forPreview = true)
        assertEquals(
            listOf(
                ShortformCondition.product(productId = "P-1"),
                ShortformCondition(tags = listOf("fall-look", "knitwear")),
                ShortformCondition(tags = listOf("picks")),
            ),
            steps.map { it.condition },
        )
        assertTrue(steps.none { it.condition.collectionId != null })
    }

    @Test
    fun `first step with shortform wins`() {
        val steps = ShortformMatcher.steps(catalog.product("P-1")!!, catalog)
        // The product has nothing, the tags have something.
        val picked = ShortformMatcher.firstWithShortform(steps) { it.kind != MatchStep.Kind.PRODUCT }
        assertEquals(MatchStep.Kind.VERTICAL_TAGS, picked?.kind)
        assertNull(ShortformMatcher.firstWithShortform(steps) { false })
    }

    @Test
    fun `strip conditions for results and home`() {
        assertEquals(
            ShortformCondition(skus = listOf("SKU-1", "SKU-4")),
            ShortformMatcher.forProducts(catalog.products),
        )
        assertNull(ShortformMatcher.forProducts(listOf(catalog.product("P-2")!!)))
        assertEquals(ShortformCondition(collectionId = "home-col"), ShortformMatcher.forHome(catalog))
        assertEquals(ShortformCondition.NONE, ShortformMatcher.forHome(TestCatalogs.sample().copy(homeCollectionId = null)))
    }

    @Test
    fun `sdk product maps back by productId, customerProductId, sku, url`() {
        assertEquals("P-1", catalog.findSdkProduct("P-1", null, null)?.productId)
        assertEquals("P-1", catalog.findSdkProduct("C-1", null, null)?.productId)
        assertEquals("P-4", catalog.findSdkProduct("unknown", "SKU-4", null)?.productId)
        assertEquals("P-1", catalog.findSdkProduct(null, null, "https://example.com/p/1/")?.productId)
        assertNull(catalog.findSdkProduct("unknown", "unknown", "https://example.com/other"))
    }
}
