package cloud.shoplive.demo.shortform.ui.results

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.FrameLayout
import androidx.appcompat.widget.PopupMenu
import androidx.core.view.isVisible
import androidx.recyclerview.widget.GridLayoutManager
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.Product
import cloud.shoplive.demo.shortform.catalog.ProductSearch
import cloud.shoplive.demo.shortform.data.ResultsViewMode
import cloud.shoplive.demo.shortform.databinding.ActivityResultsBinding
import cloud.shoplive.demo.shortform.shortform.ShortformAvailability
import cloud.shoplive.demo.shortform.shortform.ShortformCondition
import cloud.shoplive.demo.shortform.shortform.ShortformMatcher
import cloud.shoplive.demo.shortform.shortform.ShortformSdk
import cloud.shoplive.demo.shortform.ui.BaseActivity
import cloud.shoplive.demo.shortform.ui.ProductAdapter
import cloud.shoplive.demo.shortform.ui.applyInsets
import cloud.shoplive.demo.shortform.ui.detail.ProductDetailActivity
import cloud.shoplive.sdk.shorts.ShopLiveShortformHorizontalTypeView

/**
 * Results for a query or a vertical: product grid (2 · 3 columns) or list, with a shortform
 * strip on top built from the results' skus (or the vertical's tags).
 */
class ResultsActivity : BaseActivity() {

    private lateinit var binding: ActivityResultsBinding
    private val adapter = ProductAdapter { startActivity(ProductDetailActivity.intent(this, it.productId)) }
    private var strip: ShopLiveShortformHorizontalTypeView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityResultsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        val query = intent.getStringExtra(EXTRA_QUERY)
        setUpTopBar(binding.appBar, binding.toolbar, query)
        binding.scroll.applyInsets(bottom = true)

        binding.grid.adapter = adapter
        applyViewMode(graph.options.loadResultsViewMode())
        binding.viewButton.setOnClickListener { showViewMenu() }

        withCatalog { loaded -> render(loaded.catalog, query) }
    }

    override fun onResume() {
        super.onResume()
        strip?.let { ShortformSdk.setPlaying(it, true) }
    }

    override fun onPause() {
        super.onPause()
        strip?.let { ShortformSdk.setPlaying(it, false) }
    }

    private fun render(catalog: Catalog, query: String?) {
        val vertical = catalog.vertical(intent.getStringExtra(EXTRA_VERTICAL))
        val products: List<Product> = when {
            vertical != null -> {
                binding.toolbar.title = vertical.title.resolve()
                ProductSearch(catalog).productsFor(vertical)
            }
            else -> ProductSearch(catalog).search(query.orEmpty()).matches
        }

        binding.resultCount.text = resources.getQuantityString(R.plurals.results_count, products.size, products.size)
        binding.emptyText.isVisible = products.isEmpty()
        adapter.submit(products)
        ShortformAvailability.check(this, products) { adapter.refreshBadges() }

        // The strip: the results' skus; for a vertical without skus, its tags.
        val condition = ShortformMatcher.forProducts(products)
            ?: vertical?.tags?.takeIf { it.isNotEmpty() }?.let { ShortformCondition(tags = it) }
        binding.stripSection.isVisible = condition != null && graph.settings.accessKey.isNotEmpty()
        if (condition != null && binding.stripSection.isVisible) {
            strip = ShortformSdk.horizontal(this, condition).also {
                binding.stripContainer.addView(it, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
            }
        }
    }

    private fun showViewMenu() {
        PopupMenu(this, binding.viewButton).apply {
            menuInflater.inflate(R.menu.menu_results_view, menu)
            val current = graph.options.loadResultsViewMode()
            menu.findItem(itemFor(current))?.isChecked = true
            setOnMenuItemClickListener { item ->
                val mode = when (item.itemId) {
                    R.id.view_grid_3 -> ResultsViewMode.GRID_3
                    R.id.view_list -> ResultsViewMode.LIST
                    else -> ResultsViewMode.GRID_2
                }
                graph.options.saveResultsViewMode(mode)
                applyViewMode(mode)
                true
            }
        }.show()
    }

    private fun itemFor(mode: ResultsViewMode) = when (mode) {
        ResultsViewMode.GRID_2 -> R.id.view_grid_2
        ResultsViewMode.GRID_3 -> R.id.view_grid_3
        ResultsViewMode.LIST -> R.id.view_list
    }

    private fun applyViewMode(mode: ResultsViewMode) {
        binding.grid.layoutManager = GridLayoutManager(this, mode.columns)
        adapter.list = mode == ResultsViewMode.LIST
        binding.viewButton.text = getString(
            R.string.results_view_current,
            getString(
                when (mode) {
                    ResultsViewMode.GRID_2 -> R.string.results_view_grid_2
                    ResultsViewMode.GRID_3 -> R.string.results_view_grid_3
                    ResultsViewMode.LIST -> R.string.results_view_list
                },
            ),
        )
    }

    companion object {
        private const val EXTRA_QUERY = "query"
        private const val EXTRA_VERTICAL = "vertical"

        fun forQuery(context: Context, query: String) =
            Intent(context, ResultsActivity::class.java).putExtra(EXTRA_QUERY, query)

        fun forVertical(context: Context, verticalId: String) =
            Intent(context, ResultsActivity::class.java).putExtra(EXTRA_VERTICAL, verticalId)
    }
}
