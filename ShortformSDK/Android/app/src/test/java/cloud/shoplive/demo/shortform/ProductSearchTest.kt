package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.catalog.ProductSearch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductSearchTest {

    private val search = ProductSearch(TestCatalogs.full())

    private fun ids(list: List<cloud.shoplive.demo.shortform.catalog.Product>) = list.map { it.productId }

    @Test
    fun `demo products come first, featured before vertical products`() {
        // "knit" matches P-1 by name, the fashion vertical by keyword (brings P-2), and P-4 by name.
        val r = search.search("knit")
        assertFalse(r.demoIsFallback)
        assertEquals(listOf("P-1", "P-2"), ids(r.demoProducts))
        assertEquals(listOf("P-4"), ids(r.otherProducts))
        assertEquals(listOf("P-1", "P-2", "P-4"), ids(r.matches))
    }

    @Test
    fun `featured order wins inside the demo section`() {
        // "n" is in every name: featured P-3, P-1 first, then the fashion vertical's P-2.
        val r = search.search("n")
        assertEquals(listOf("P-3", "P-1", "P-2"), ids(r.demoProducts))
        assertEquals(listOf("P-4"), ids(r.otherProducts))
    }

    @Test
    fun `matching is case-insensitive and uses brand and keywords`() {
        assertEquals(listOf("P-3"), ids(search.search("SERUM").demoProducts))
        assertEquals(listOf("P-1", "P-2"), ids(search.search("acme").demoProducts))
    }

    @Test
    fun `demo section never disappears`() {
        val r = search.search("beanie")
        // P-4 is not a demo product, so the demo section shows featured products instead.
        assertTrue(r.demoIsFallback)
        assertEquals(listOf("P-3", "P-1"), ids(r.demoProducts))
        assertEquals(listOf("P-4"), ids(r.otherProducts))
        assertEquals(listOf("P-4"), ids(r.matches))

        val none = search.search("zzz")
        assertTrue(none.demoIsFallback)
        assertEquals(listOf("P-3", "P-1"), ids(none.demoProducts))
        assertTrue(none.matches.isEmpty())
    }

    @Test
    fun `vertical title matches in any language`() {
        assertEquals(listOf("P-1", "P-2"), ids(search.search("패션").demoProducts))
    }

    @Test
    fun `sample catalog - korean keyword`() {
        val r = ProductSearch(TestCatalogs.sample()).search("니트")
        assertFalse(r.demoIsFallback)
        assertTrue(r.demoProducts.isNotEmpty())
    }

    @Test
    fun `vertical products and suggested keywords`() {
        val c = TestCatalogs.full()
        assertEquals(listOf("P-1", "P-2", "P-4"), ids(search.productsFor(c.vertical("fashion")!!)))
        assertEquals(listOf("knit", "serum"), search.suggestedKeywords())
    }
}
