package cloud.shoplive.demo.shortform.ui

import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.MenuItem
import android.view.View
import android.view.WindowManager
import androidx.annotation.StyleRes
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import cloud.shoplive.demo.shortform.DemoApp
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.CatalogRepository
import cloud.shoplive.demo.shortform.data.BrandColor
import cloud.shoplive.demo.shortform.ui.settings.SettingsActivity
import com.google.android.material.appbar.MaterialToolbar
import kotlinx.coroutines.launch

/**
 * Common screen setup: brand color, edge-to-edge window, and the top bar with ⚙︎ Settings,
 * which every screen shows.
 */
abstract class BaseActivity : AppCompatActivity() {

    protected val graph: DemoApp.Graph get() = DemoApp.graph(this)

    private var appliedBrand: BrandColor? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        appliedBrand = graph.settings.brandColor
        theme.applyStyle(brandOverlay(appliedBrand!!), true)
        super.onCreate(savedInstanceState)
        setUpEdgeToEdge()
    }

    override fun onResume() {
        super.onResume()
        // Settings → Branding changed while this screen was in the back stack.
        if (appliedBrand != graph.settings.brandColor) recreate()
    }

    @Suppress("DEPRECATION")
    private fun setUpEdgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        val night = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        WindowInsetsControllerCompat(window, window.decorView).apply {
            isAppearanceLightStatusBars = !night
            isAppearanceLightNavigationBars = !night
        }
    }

    /**
     * Sets up the top bar. [appBar] takes the status bar / cutout inset. The ⚙︎ item opens
     * Settings on every screen except Settings itself.
     */
    protected fun setUpTopBar(
        appBar: View,
        toolbar: MaterialToolbar,
        title: CharSequence?,
        showBack: Boolean = true,
        showSettings: Boolean = true,
    ) {
        appBar.applyInsets(top = true)
        toolbar.title = title
        if (showBack) {
            toolbar.setNavigationIcon(R.drawable.ic_arrow_back)
            toolbar.setNavigationContentDescription(R.string.common_back)
            toolbar.setNavigationOnClickListener { onBackPressedDispatcher.onBackPressed() }
        }
        toolbar.menu.clear()
        onCreateTopBarMenu(toolbar)
        if (showSettings) toolbar.inflateMenu(R.menu.menu_settings)
        toolbar.setOnMenuItemClickListener { item ->
            if (item.itemId == R.id.action_settings) {
                startActivity(SettingsActivity.intent(this))
                true
            } else {
                onTopBarItem(item)
            }
        }
    }

    /** Screens add their own top-bar items here; they appear before ⚙︎. */
    protected open fun onCreateTopBarMenu(toolbar: MaterialToolbar) = Unit

    protected open fun onTopBarItem(item: MenuItem): Boolean = false

    /** Runs [block] with the catalog, loading it first when needed. */
    protected fun withCatalog(block: (CatalogRepository.Loaded) -> Unit) {
        lifecycleScope.launch { block(graph.catalogRepository.get()) }
    }

    companion object {
        @StyleRes
        fun brandOverlay(brand: BrandColor): Int = when (brand) {
            BrandColor.DEFAULT -> R.style.ThemeOverlay_Demo_Brand_Default
            BrandColor.BLUE -> R.style.ThemeOverlay_Demo_Brand_Blue
            BrandColor.GREEN -> R.style.ThemeOverlay_Demo_Brand_Green
            BrandColor.ORANGE -> R.style.ThemeOverlay_Demo_Brand_Orange
            BrandColor.PINK -> R.style.ThemeOverlay_Demo_Brand_Pink
        }
    }
}
