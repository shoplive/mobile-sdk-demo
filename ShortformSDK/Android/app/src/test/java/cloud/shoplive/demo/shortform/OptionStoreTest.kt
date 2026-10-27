package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.data.BrandColor
import cloud.shoplive.demo.shortform.data.DemoSettings
import cloud.shoplive.demo.shortform.data.DetailOptions
import cloud.shoplive.demo.shortform.data.OptionStore
import cloud.shoplive.demo.shortform.data.PreviewCorner
import cloud.shoplive.demo.shortform.data.PreviewSize
import cloud.shoplive.demo.shortform.data.ResultsViewMode
import cloud.shoplive.demo.shortform.data.SectionPosition
import cloud.shoplive.demo.shortform.data.ShortformLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OptionStoreTest {

    @Test
    fun `defaults on first launch`() {
        assertEquals(DetailOptions(), OptionStore(MemoryStore()).load())
    }

    @Test
    fun `last choice is persisted`() {
        val mem = MemoryStore()
        val chosen = DetailOptions(
            layout = ShortformLayout.PREVIEW,
            position = SectionPosition.INSIDE_DESCRIPTION,
            cardType = 2,
            showTitle = false,
            showViewCount = false,
            showProductCount = false,
            columns = 3,
            autoplay = false,
            previewCorner = PreviewCorner.TOP_LEFT,
            previewSize = PreviewSize.LARGE,
            previewMaxCount = 10,
            barCollapsed = true,
        )
        OptionStore(mem).save(chosen)
        // A new store over the same storage = the next app launch.
        assertEquals(chosen, OptionStore(mem).load())
    }

    @Test
    fun `invalid stored values fall back to defaults`() {
        val mem = MemoryStore()
        mem.map[OptionStore.K_LAYOUT] = "CAROUSEL"
        mem.map[OptionStore.K_CARD_TYPE] = "7"
        mem.map[OptionStore.K_COLUMNS] = "abc"
        mem.map[OptionStore.K_AUTOPLAY] = "maybe"
        assertEquals(DetailOptions(), OptionStore(mem).load())
    }

    @Test
    fun `layout names saved by earlier builds still map`() {
        val expected = mapOf(
            "HORIZONTAL" to ShortformLayout.STRIP,
            "CARD_GRID" to ShortformLayout.LARGE_CARDS,
            "VERTICAL_FEED" to ShortformLayout.GRID,
            "FLOATING_PREVIEW" to ShortformLayout.PREVIEW,
            "BUTTON_ONLY" to ShortformLayout.BUTTON,
        )
        expected.forEach { (old, layout) ->
            val mem = MemoryStore()
            mem.map[OptionStore.K_LAYOUT] = old
            assertEquals(old, layout, OptionStore(mem).load().layout)
        }
    }

    @Test
    fun `reset clears options and results view only`() {
        val mem = MemoryStore()
        val store = OptionStore(mem)
        store.save(DetailOptions(layout = ShortformLayout.LARGE_CARDS))
        store.saveResultsViewMode(ResultsViewMode.LIST)
        mem.map[DemoSettings.K_ACCESS_KEY] = "kept"
        store.reset()
        assertEquals(DetailOptions(), store.load())
        assertEquals(ResultsViewMode.GRID_2, store.loadResultsViewMode())
        assertEquals("kept", mem.map[DemoSettings.K_ACCESS_KEY])
    }

    @Test
    fun `settings override build values and fall back when cleared`() {
        val mem = MemoryStore()
        val s = DemoSettings(mem, buildAccessKey = "build-key", buildCatalogUrl = "")
        assertEquals("build-key", s.accessKey)
        assertFalse(s.accessKeyIsOverridden)
        assertEquals("", s.catalogUrl)

        s.setAccessKey("  device-key ")
        s.setCatalogUrl("https://example.com/catalog.json")
        assertEquals("device-key", s.accessKey)
        assertTrue(s.accessKeyIsOverridden)
        assertEquals("https://example.com/catalog.json", s.catalogUrl)

        s.setAccessKey("")
        assertEquals("build-key", s.accessKey)

        s.brandColor = BrandColor.GREEN
        assertEquals(BrandColor.GREEN, DemoSettings(mem, "", "").brandColor)
        s.clear()
        assertEquals(BrandColor.DEFAULT, s.brandColor)
    }
}
