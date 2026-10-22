package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.catalog.Product
import cloud.shoplive.demo.shortform.ui.ProductFormat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Locale

class ProductFormatTest {

    @Test
    fun `money uses the currency's own digits`() {
        assertEquals("₩79,000", ProductFormat.money(79000.0, "KRW", Locale.KOREA))
        assertEquals("$25.50", ProductFormat.money(25.5, "USD", Locale.US))
    }

    @Test
    fun `discount rate from catalog, else computed`() {
        val base = Product(productId = "a", name = "A", currency = "KRW", originalPrice = 100.0)
        assertNull(ProductFormat.discountPercent(base))
        assertEquals(20, ProductFormat.discountPercent(base.copy(discountPrice = 80.0)))
        assertEquals(11, ProductFormat.discountPercent(base.copy(discountPrice = 80.0, discountRate = 11.0)))
        assertNull(ProductFormat.discountPercent(base.copy(discountPrice = 100.0)))
    }

    @Test
    fun `description splits at a sentence near the middle`() {
        assertEquals("One. Two." to "Three. Four.", ProductFormat.splitDescription("One. Two. Three. Four."))
        assertEquals("Short" to "", ProductFormat.splitDescription("Short"))
        assertEquals("" to "", ProductFormat.splitDescription(null))
    }
}
