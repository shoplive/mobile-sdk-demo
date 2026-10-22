package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.catalog.CatalogParser
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
    fun `list views - sku, then vertical tags, then fallback collection`() {
        val steps = ShortformMatcher.forListViews(catalog.product("P-1")!!, catalog)
        assertEquals(
            listOf(MatchStep.Kind.PRODUCT, MatchStep.Kind.VERTICAL_TAGS, MatchStep.Kind.FALLBACK),
            steps.map { it.kind },
        )
        assertEquals(ShortformCondition(skus = listOf("SKU-1")), steps[0].condition)
        assertEquals(ShortformCondition(tags = listOf("fall-look", "knitwear")), steps[1].condition)
        assertEquals(ShortformCondition(collectionId = "fallback-col"), steps[2].condition)
        assertFalse(steps[0].isRelated)
        assertTrue(steps[1].isRelated)
        assertTrue(steps[2].isRelated)
    }

    @Test
    fun `list views - without sku or tags the fallback is the only step`() {
        val steps = ShortformMatcher.forListViews(catalog.product("P-3")!!, catalog)
        assertEquals(listOf(MatchStep.Kind.FALLBACK), steps.map { it.kind })
    }

    @Test
    fun `fallback tags are used when there is no fallback collection`() {
        val c = CatalogParser.parse(
            """{ "version": 1, "fallback": { "tags": ["picks"] },
                 "products": [ { "productId": "a", "name": "A", "currency": "KRW", "originalPrice": 1 } ] }""",
        )
        val steps = ShortformMatcher.forListViews(c.product("a")!!, c)
        assertEquals(listOf(ShortformCondition(tags = listOf("picks"))), steps.map { it.condition })
    }

    @Test
    fun `no matching data means no steps - the name is never used`() {
        val c = CatalogParser.parse(
            """{ "version": 1, "products": [ { "productId": "a", "name": "Knit", "currency": "KRW", "originalPrice": 1 } ] }""",
        )
        assertTrue(ShortformMatcher.forListViews(c.product("a")!!, c).isEmpty())
    }

    @Test
    fun `preview - productId first`() {
        val steps = ShortformMatcher.forPreview(catalog.product("P-1")!!, catalog)
        assertEquals(ShortformCondition(productId = "P-1"), steps.first().condition)
        assertEquals(MatchStep.Kind.PRODUCT, steps.first().kind)
    }

    @Test
    fun `first step with shortform wins`() {
        val steps = ShortformMatcher.forListViews(catalog.product("P-1")!!, catalog)
        // sku has nothing, tags have something.
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
