package cloud.shoplive.demo.shortform

import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.CatalogParser
import cloud.shoplive.demo.shortform.data.KeyValueStore
import java.io.File

object TestCatalogs {
    /** The sample catalog that ships in the app (path set in app/build.gradle.kts). */
    fun sample(): Catalog = CatalogParser.parse(File(System.getProperty("demo.sampleCatalog")!!).readText())

    /** A catalog that exercises every matching step. */
    fun full(): Catalog = CatalogParser.parse(
        """
        {
          "version": 1,
          "home": { "collectionId": "home-col" },
          "verticals": [
            { "id": "fashion", "title": { "en": "Fashion", "ko": "패션" },
              "productIds": ["P-1", "P-2"], "keywords": ["knit"], "tags": ["fall-look", "knitwear"] },
            { "id": "beauty", "title": { "en": "Beauty" }, "productIds": ["P-3"], "tags": [] }
          ],
          "featuredProductIds": ["P-3", "P-1"],
          "fallback": { "collectionId": "fallback-col", "tags": ["picks"] },
          "products": [
            { "productId": "P-1", "customerProductId": "C-1", "sku": "SKU-1", "url": "https://example.com/p/1",
              "name": "Wool Knit", "brand": "Acme", "currency": "KRW", "originalPrice": 50000, "discountPrice": 40000 },
            { "productId": "P-2", "name": "Linen Shirt", "brand": "Acme", "currency": "KRW", "originalPrice": 30000 },
            { "productId": "P-3", "name": "Night Serum", "brand": "Glow", "currency": "USD", "originalPrice": 25.5,
              "keywords": ["serum"] },
            { "productId": "P-4", "sku": "SKU-4", "name": "Knit Beanie", "brand": "Other", "currency": "KRW", "originalPrice": 15000 }
          ]
        }
        """.trimIndent(),
    )
}

class MemoryStore : KeyValueStore {
    val map = HashMap<String, String>()
    override fun getString(key: String) = map[key]
    override fun putString(key: String, value: String?) {
        if (value == null) map.remove(key) else map[key] = value
    }
    override fun remove(keys: Collection<String>) = keys.forEach { map.remove(it) }
    override fun clear() = map.clear()
}
