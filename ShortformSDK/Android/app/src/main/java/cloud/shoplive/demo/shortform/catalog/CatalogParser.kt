package cloud.shoplive.demo.shortform.catalog

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser

/**
 * Reads the catalog JSON. Strict where the app depends on a field (version, products with
 * productId / name / currency / originalPrice) and lenient elsewhere, so a catalog with an
 * extra or missing optional field still loads.
 */
object CatalogParser {

    class CatalogFormatException(message: String, cause: Throwable? = null) : Exception(message, cause)

    const val SUPPORTED_VERSION = 1

    fun parse(json: String): Catalog {
        val root = try {
            JsonParser.parseString(json)
        } catch (e: Exception) {
            throw CatalogFormatException("Not valid JSON", e)
        }
        if (root == null || !root.isJsonObject) throw CatalogFormatException("The catalog must be a JSON object")
        val obj = root.asJsonObject

        val version = obj.int("version") ?: throw CatalogFormatException("Missing \"version\"")
        if (version != SUPPORTED_VERSION) throw CatalogFormatException("Unsupported version $version")

        val productsJson = obj.array("products") ?: throw CatalogFormatException("Missing \"products\"")
        val products = productsJson.mapIndexed { index, element -> parseProduct(index, element) }
        val duplicate = products.groupBy { it.productId }.entries.firstOrNull { it.value.size > 1 }
        if (duplicate != null) throw CatalogFormatException("Duplicate productId \"${duplicate.key}\"")

        val verticals = obj.array("verticals").orEmpty().mapNotNull { element ->
            val v = element.objOrNull() ?: return@mapNotNull null
            val id = v.string("id") ?: return@mapNotNull null
            val title = v.get("title")?.objOrNull()?.let { t ->
                Localized(t.entrySet().mapNotNull { (k, value) -> value.stringOrNull()?.let { k to it } }.toMap())
            } ?: Localized(mapOf("en" to id))
            Vertical(
                id = id,
                title = title,
                productIds = v.strings("productIds"),
                keywords = v.strings("keywords"),
                tags = v.strings("tags"),
            )
        }

        val fallback = obj.get("fallback")?.objOrNull()?.let {
            Fallback(collectionId = it.string("collectionId"), tags = it.strings("tags"))
        }

        return Catalog(
            version = version,
            homeCollectionId = obj.get("home")?.objOrNull()?.string("collectionId"),
            verticals = verticals,
            featuredProductIds = obj.strings("featuredProductIds"),
            fallback = fallback,
            products = products,
        )
    }

    private fun parseProduct(index: Int, element: JsonElement): Product {
        val p = element.objOrNull() ?: throw CatalogFormatException("products[$index] is not an object")
        fun required(name: String) = p.string(name) ?: throw CatalogFormatException("products[$index] is missing \"$name\"")
        return Product(
            productId = required("productId"),
            customerProductId = p.string("customerProductId"),
            sku = p.string("sku"),
            url = p.string("url"),
            name = required("name"),
            brand = p.string("brand"),
            imageUrls = p.strings("imageUrls"),
            description = p.string("description"),
            currency = required("currency"),
            originalPrice = p.double("originalPrice")
                ?: throw CatalogFormatException("products[$index] is missing \"originalPrice\""),
            discountPrice = p.double("discountPrice"),
            discountRate = p.double("discountRate"),
            keywords = p.strings("keywords"),
        )
    }

    // ── small JSON helpers ──────────────────────────────────────────────────────

    private fun JsonElement.objOrNull(): JsonObject? = if (isJsonObject) asJsonObject else null

    private fun JsonElement.stringOrNull(): String? =
        if (isJsonPrimitive && asJsonPrimitive.isString) asString.trim().takeIf { it.isNotEmpty() } else null

    private fun JsonObject.string(name: String): String? = get(name)?.stringOrNull()

    private fun JsonObject.int(name: String): Int? =
        get(name)?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isNumber }?.asInt

    private fun JsonObject.double(name: String): Double? =
        get(name)?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isNumber }?.asDouble

    private fun JsonObject.array(name: String): JsonArray? =
        get(name)?.takeIf { it.isJsonArray }?.asJsonArray

    private fun JsonObject.strings(name: String): List<String> =
        array(name).orEmpty().mapNotNull { it.stringOrNull() }.distinct()

    private fun JsonArray?.orEmpty(): List<JsonElement> = this?.toList() ?: emptyList()
}
