package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.catalog.CatalogParser
import cloud.shoplive.demo.shortform.catalog.Localized
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.Locale

class CatalogParserTest {

    @Test
    fun `bundled sample catalog parses`() {
        val c = TestCatalogs.sample()
        assertEquals(1, c.version)
        assertTrue(c.products.isNotEmpty())
        assertTrue(c.verticals.isNotEmpty())
        // Every featured and vertical id points at a real product.
        (c.featuredProductIds + c.verticals.flatMap { it.productIds }).forEach { id ->
            assertTrue("unknown product $id", c.product(id) != null)
        }
    }

    @Test
    fun `all fields are read`() {
        val c = TestCatalogs.full()
        assertEquals("home-col", c.homeCollectionId)
        assertEquals("fallback-col", c.fallback?.collectionId)
        assertEquals(listOf("picks"), c.fallback?.tags)
        assertEquals(listOf("P-3", "P-1"), c.featuredProductIds)
        val p = c.product("P-1")!!
        assertEquals("C-1", p.customerProductId)
        assertEquals("SKU-1", p.sku)
        assertEquals(40000.0, p.salePrice, 0.0)
        assertTrue(p.hasDiscount)
        assertEquals(listOf("fall-look", "knitwear"), c.vertical("fashion")?.tags)
    }

    @Test
    fun `missing required product field is rejected`() {
        expectFormatError("""{ "version": 1, "products": [ { "productId": "x", "currency": "KRW", "originalPrice": 1 } ] }""")
    }

    @Test
    fun `wrong version, bad JSON and duplicate ids are rejected`() {
        expectFormatError("""{ "version": 2, "products": [] }""")
        expectFormatError("""not json""")
        expectFormatError("""[]""")
        expectFormatError(
            """{ "version": 1, "products": [
                 { "productId": "a", "name": "A", "currency": "KRW", "originalPrice": 1 },
                 { "productId": "a", "name": "B", "currency": "KRW", "originalPrice": 1 } ] }""",
        )
    }

    @Test
    fun `optional sections may be missing`() {
        val c = CatalogParser.parse("""{ "version": 1, "products": [] }""")
        assertNull(c.homeCollectionId)
        assertNull(c.fallback)
        assertTrue(c.verticals.isEmpty())
        assertTrue(c.featuredProductIds.isEmpty())
    }

    @Test
    fun `localized title falls back to English`() {
        val t = Localized(mapOf("en" to "Fashion", "ko" to "패션"))
        assertEquals("패션", t.resolve(Locale.KOREA))
        assertEquals("Fashion", t.resolve(Locale.JAPAN))
        assertEquals("Fashion", t.resolve(Locale.US))
    }

    private fun expectFormatError(json: String) {
        try {
            CatalogParser.parse(json)
            fail("expected a format error for: $json")
        } catch (e: CatalogParser.CatalogFormatException) {
            // expected
        }
    }
}
