package cloud.shoplive.demo.shortform.ui.home

import android.os.Bundle
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.GridLayoutManager
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.CatalogRepository
import cloud.shoplive.demo.shortform.databinding.ActivityHomeBinding
import cloud.shoplive.demo.shortform.shortform.ShortformAvailability
import cloud.shoplive.demo.shortform.shortform.ShortformMatcher
import cloud.shoplive.demo.shortform.shortform.ShortformSdk
import cloud.shoplive.demo.shortform.ui.BaseActivity
import cloud.shoplive.demo.shortform.ui.ProductAdapter
import cloud.shoplive.demo.shortform.ui.applyInsets
import cloud.shoplive.demo.shortform.ui.detail.ProductDetailActivity
import cloud.shoplive.demo.shortform.ui.results.ResultsActivity
import cloud.shoplive.demo.shortform.ui.search.SearchActivity
import cloud.shoplive.demo.shortform.ui.settings.SettingsActivity
import cloud.shoplive.sdk.shorts.ShopLiveShortformHorizontalTypeView
import com.google.android.material.chip.Chip

/** Home: search bar, vertical chips, "Today's shortform" strip, featured products. */
class HomeActivity : BaseActivity() {

    private lateinit var binding: ActivityHomeBinding
    private val adapter = ProductAdapter { startActivity(ProductDetailActivity.intent(this, it.productId)) }
    private var strip: ShopLiveShortformHorizontalTypeView? = null
    private var shownKey: String? = null
    private var shownCatalog: Catalog? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityHomeBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setUpTopBar(binding.appBar, binding.toolbar, getString(R.string.app_name), showBack = false)
        binding.scroll.applyInsets(bottom = true)

        binding.searchBar.setOnClickListener { startActivity(SearchActivity.intent(this)) }
        binding.accessKeyButton.setOnClickListener { startActivity(SettingsActivity.intent(this)) }
        binding.featuredGrid.layoutManager = GridLayoutManager(this, 2)
        binding.featuredGrid.adapter = adapter
    }

    override fun onResume() {
        super.onResume()
        // Settings may have changed the key or the catalog: rebuild what depends on them.
        withCatalog { loaded -> render(loaded) }
        strip?.let { ShortformSdk.setPlaying(it, true) }
    }

    override fun onPause() {
        super.onPause()
        strip?.let { ShortformSdk.setPlaying(it, false) }
    }

    private fun render(loaded: CatalogRepository.Loaded) {
        val catalog = loaded.catalog
        val hasKey = graph.settings.accessKey.isNotEmpty()
        binding.accessKeyBanner.isVisible = !hasKey

        binding.catalogStatus.text = getString(
            when (loaded.source) {
                CatalogRepository.Source.REMOTE -> R.string.home_catalog_remote
                CatalogRepository.Source.CACHE -> R.string.home_catalog_cache
                CatalogRepository.Source.BUNDLED -> R.string.home_catalog_bundled
            },
            catalog.products.size,
        )

        val keyChanged = shownKey != graph.settings.accessKey
        if (catalog === shownCatalog && !keyChanged) return
        shownCatalog = catalog
        shownKey = graph.settings.accessKey

        binding.verticalChips.removeAllViews()
        catalog.verticals.forEach { vertical ->
            binding.verticalChips.addView(Chip(this).apply {
                text = vertical.title.resolve()
                setOnClickListener { startActivity(ResultsActivity.forVertical(this@HomeActivity, vertical.id)) }
            })
        }
        binding.verticalChips.isVisible = catalog.verticals.isNotEmpty()

        // "Today's shortform": the home collection, else no condition.
        binding.homeShortform.removeAllViews()
        strip = null
        if (hasKey) {
            strip = ShortformSdk.horizontal(this, ShortformMatcher.forHome(catalog)).also {
                binding.homeShortform.addView(it, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
            }
        } else {
            binding.homeShortform.addView(TextView(this).apply {
                setText(R.string.home_shortform_needs_key)
                gravity = Gravity.CENTER
                setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_BodyMedium)
            })
        }

        val featured = catalog.featuredProducts().ifEmpty { catalog.products }
        adapter.submit(featured)
        if (hasKey) ShortformAvailability.check(this, featured) { adapter.refreshBadges() }
    }
}
