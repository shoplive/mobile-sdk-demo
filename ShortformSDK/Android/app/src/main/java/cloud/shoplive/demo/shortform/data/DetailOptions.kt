package cloud.shoplive.demo.shortform.data

/** Layout of "Shortform for this product" on Product detail (option bar → Layout). */
enum class ShortformLayout { HORIZONTAL, CARD_GRID, VERTICAL_FEED, FLOATING_PREVIEW, BUTTON_ONLY }

/** Where the section sits on Product detail (option bar → Position). */
enum class SectionPosition { ABOVE_IMAGES, BELOW_IMAGES, BELOW_PRICE, INSIDE_DESCRIPTION, BOTTOM }

enum class PreviewCorner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

/** Floating preview size: the longer side of the preview, in dp. */
enum class PreviewSize(val longSideDp: Int) { SMALL(120), MEDIUM(160), LARGE(220) }

/** Product grid on Results ([View ▾]). */
enum class ResultsViewMode(val columns: Int) { GRID_2(2), GRID_3(3), LIST(1) }

/** Everything the option bar controls. Defaults are what a first launch shows. */
data class DetailOptions(
    val layout: ShortformLayout = ShortformLayout.HORIZONTAL,
    val position: SectionPosition = SectionPosition.BELOW_PRICE,
    /** SDK card type 0, 1 or 2. */
    val cardType: Int = 0,
    val showTitle: Boolean = true,
    val showViewCount: Boolean = true,
    val showProductCount: Boolean = true,
    /** Columns for Card grid and Vertical feed. */
    val columns: Int = 2,
    val autoplay: Boolean = true,
    val previewCorner: PreviewCorner = PreviewCorner.BOTTOM_RIGHT,
    val previewSize: PreviewSize = PreviewSize.MEDIUM,
    /** 0 = no limit. */
    val previewMaxCount: Int = 5,
    /** "Presentation mode": the option bar is collapsed. */
    val barCollapsed: Boolean = false,
) {
    companion object {
        val CARD_TYPES = listOf(0, 1, 2)
        val COLUMN_CHOICES = listOf(1, 2, 3)
        val PREVIEW_MAX_COUNTS = listOf(0, 1, 3, 5, 10)
    }
}

/**
 * Persists [DetailOptions] (the last choice on the device) and the Results view mode.
 * Unknown or invalid stored values fall back to the defaults.
 */
class OptionStore(private val store: KeyValueStore) {

    fun load(): DetailOptions {
        val d = DetailOptions()
        return DetailOptions(
            layout = enumOr(K_LAYOUT, d.layout),
            position = enumOr(K_POSITION, d.position),
            cardType = intIn(K_CARD_TYPE, DetailOptions.CARD_TYPES, d.cardType),
            showTitle = bool(K_TITLE, d.showTitle),
            showViewCount = bool(K_VIEW_COUNT, d.showViewCount),
            showProductCount = bool(K_PRODUCT_COUNT, d.showProductCount),
            columns = intIn(K_COLUMNS, DetailOptions.COLUMN_CHOICES, d.columns),
            autoplay = bool(K_AUTOPLAY, d.autoplay),
            previewCorner = enumOr(K_PREVIEW_CORNER, d.previewCorner),
            previewSize = enumOr(K_PREVIEW_SIZE, d.previewSize),
            previewMaxCount = intIn(K_PREVIEW_MAX, DetailOptions.PREVIEW_MAX_COUNTS, d.previewMaxCount),
            barCollapsed = bool(K_BAR_COLLAPSED, d.barCollapsed),
        )
    }

    fun save(o: DetailOptions) {
        store.putString(K_LAYOUT, o.layout.name)
        store.putString(K_POSITION, o.position.name)
        store.putString(K_CARD_TYPE, o.cardType.toString())
        store.putString(K_TITLE, o.showTitle.toString())
        store.putString(K_VIEW_COUNT, o.showViewCount.toString())
        store.putString(K_PRODUCT_COUNT, o.showProductCount.toString())
        store.putString(K_COLUMNS, o.columns.toString())
        store.putString(K_AUTOPLAY, o.autoplay.toString())
        store.putString(K_PREVIEW_CORNER, o.previewCorner.name)
        store.putString(K_PREVIEW_SIZE, o.previewSize.name)
        store.putString(K_PREVIEW_MAX, o.previewMaxCount.toString())
        store.putString(K_BAR_COLLAPSED, o.barCollapsed.toString())
    }

    fun loadResultsViewMode(): ResultsViewMode = enumOr(K_RESULTS_VIEW, ResultsViewMode.GRID_2)

    fun saveResultsViewMode(mode: ResultsViewMode) = store.putString(K_RESULTS_VIEW, mode.name)

    /** Settings → Reset layout defaults. */
    fun reset() = store.remove(ALL_KEYS)

    private inline fun <reified E : Enum<E>> enumOr(key: String, default: E): E =
        store.getString(key)?.let { v -> enumValues<E>().firstOrNull { it.name == v } } ?: default

    private fun bool(key: String, default: Boolean): Boolean =
        when (store.getString(key)) { "true" -> true; "false" -> false; else -> default }

    private fun intIn(key: String, allowed: List<Int>, default: Int): Int =
        store.getString(key)?.toIntOrNull()?.takeIf { it in allowed } ?: default

    companion object {
        private const val P = "option."
        const val K_LAYOUT = P + "layout"
        const val K_POSITION = P + "position"
        const val K_CARD_TYPE = P + "cardType"
        const val K_TITLE = P + "showTitle"
        const val K_VIEW_COUNT = P + "showViewCount"
        const val K_PRODUCT_COUNT = P + "showProductCount"
        const val K_COLUMNS = P + "columns"
        const val K_AUTOPLAY = P + "autoplay"
        const val K_PREVIEW_CORNER = P + "previewCorner"
        const val K_PREVIEW_SIZE = P + "previewSize"
        const val K_PREVIEW_MAX = P + "previewMaxCount"
        const val K_BAR_COLLAPSED = P + "barCollapsed"
        const val K_RESULTS_VIEW = "results.viewMode"

        val ALL_KEYS = listOf(
            K_LAYOUT, K_POSITION, K_CARD_TYPE, K_TITLE, K_VIEW_COUNT, K_PRODUCT_COUNT, K_COLUMNS,
            K_AUTOPLAY, K_PREVIEW_CORNER, K_PREVIEW_SIZE, K_PREVIEW_MAX, K_BAR_COLLAPSED, K_RESULTS_VIEW,
        )
    }
}
