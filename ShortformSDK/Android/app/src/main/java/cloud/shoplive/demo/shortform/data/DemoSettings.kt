package cloud.shoplive.demo.shortform.data

/** Brand color choices in Settings → Branding. */
enum class BrandColor { DEFAULT, BLUE, GREEN, ORANGE, PINK }

/**
 * Values that can be overridden in Settings. Each falls back to the build-time value from
 * local.properties (BuildConfig), which may be empty.
 */
class DemoSettings(
    private val store: KeyValueStore,
    private val buildAccessKey: String,
    private val buildCatalogUrl: String,
) {
    /** The access key in use; empty means the app must ask for one. */
    val accessKey: String
        get() = store.getString(K_ACCESS_KEY)?.trim()?.takeIf { it.isNotEmpty() } ?: buildAccessKey.trim()

    val accessKeyIsOverridden: Boolean get() = !store.getString(K_ACCESS_KEY).isNullOrBlank()

    fun setAccessKey(value: String?) = store.putString(K_ACCESS_KEY, value?.trim()?.takeIf { it.isNotEmpty() })

    /** Catalog URL in use; empty means the bundled sample catalog. */
    val catalogUrl: String
        get() = store.getString(K_CATALOG_URL)?.trim()?.takeIf { it.isNotEmpty() } ?: buildCatalogUrl.trim()

    val catalogUrlIsOverridden: Boolean get() = !store.getString(K_CATALOG_URL).isNullOrBlank()

    fun setCatalogUrl(value: String?) = store.putString(K_CATALOG_URL, value?.trim()?.takeIf { it.isNotEmpty() })

    var brandColor: BrandColor
        get() = store.getString(K_BRAND_COLOR)?.let { v -> BrandColor.values().firstOrNull { it.name == v } }
            ?: BrandColor.DEFAULT
        set(value) = store.putString(K_BRAND_COLOR, value.name)

    /** Settings → Demo reset. */
    fun clear() = store.clear()

    companion object {
        const val K_ACCESS_KEY = "settings.accessKey"
        const val K_CATALOG_URL = "settings.catalogUrl"
        const val K_BRAND_COLOR = "settings.brandColor"
    }
}
