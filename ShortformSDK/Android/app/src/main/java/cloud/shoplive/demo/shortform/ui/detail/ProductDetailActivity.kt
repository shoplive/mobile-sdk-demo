package cloud.shoplive.demo.shortform.ui.detail

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.recyclerview.widget.RecyclerView
import androidx.viewpager2.widget.ViewPager2
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.Product
import cloud.shoplive.demo.shortform.data.DetailOptions
import cloud.shoplive.demo.shortform.data.SectionPosition
import cloud.shoplive.demo.shortform.data.ShortformLayout
import cloud.shoplive.demo.shortform.databinding.ActivityProductDetailBinding
import cloud.shoplive.demo.shortform.databinding.ViewSectionMessageBinding
import cloud.shoplive.demo.shortform.databinding.ViewShortformSectionBinding
import cloud.shoplive.demo.shortform.shortform.MatchStep
import cloud.shoplive.demo.shortform.shortform.Resolution
import cloud.shoplive.demo.shortform.shortform.ShortformMatcher
import cloud.shoplive.demo.shortform.shortform.ShortformSdk
import cloud.shoplive.demo.shortform.shortform.resolveShortform
import cloud.shoplive.demo.shortform.ui.BaseActivity
import cloud.shoplive.demo.shortform.ui.ProductFormat
import cloud.shoplive.demo.shortform.ui.applyInsets
import cloud.shoplive.demo.shortform.ui.settings.SettingsActivity
import cloud.shoplive.sdk.shorts.ShopLiveShortformBaseTypeView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton

/**
 * Product detail ★ — images, price, description, and "Shortform for this product" rendered as
 * the option bar says. Every option change re-renders the section in place.
 */
class ProductDetailActivity : BaseActivity() {

    private lateinit var binding: ActivityProductDetailBinding
    private lateinit var section: ViewShortformSectionBinding
    private lateinit var options: DetailOptions
    private lateinit var dialogs: OptionDialogs

    private var catalog: Catalog? = null
    private var product: Product? = null

    /**
     * Result of the matching steps, per step list (the preview cannot take a collection id, so it
     * has its own list). Missing while unknown.
     */
    private val resolutions = HashMap<Boolean, Resolution>()
    private val resolving = HashSet<Boolean>()
    private var typeView: ShopLiveShortformBaseTypeView? = null
    private var started = false
    private var renderedKey: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityProductDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)
        section = ViewShortformSectionBinding.inflate(layoutInflater)
        options = graph.options.load()
        dialogs = OptionDialogs(this, { options }) { update(it) }

        setUpTopBar(binding.appBar, binding.toolbar, null)
        binding.scroll.applyInsets(bottom = true)

        binding.optionLayout.setOnClickListener { dialogs.showLayout() }
        binding.optionPosition.setOnClickListener { dialogs.showPosition() }
        binding.optionCard.setOnClickListener { dialogs.showCard() }
        binding.optionPreview.setOnClickListener { dialogs.showPreview() }

        withCatalog { loaded ->
            val p = loaded.catalog.product(intent.getStringExtra(EXTRA_PRODUCT_ID))
            if (p == null) {
                Toast.makeText(this, R.string.detail_product_not_in_catalog, Toast.LENGTH_SHORT).show()
                finish()
                return@withCatalog
            }
            catalog = loaded.catalog
            product = p
            bindProduct(p)
            render()
        }
    }

    override fun onCreateTopBarMenu(toolbar: MaterialToolbar) {
        toolbar.inflateMenu(R.menu.menu_detail)
    }

    override fun onTopBarItem(item: MenuItem): Boolean {
        if (item.itemId != R.id.action_toggle_options) return false
        update(options.copy(barCollapsed = !options.barCollapsed))
        return true
    }

    override fun onStart() {
        super.onStart()
        started = true
        if (options.layout == ShortformLayout.PREVIEW && product != null) showPreview()
    }

    override fun onStop() {
        super.onStop()
        started = false
        if (options.layout == ShortformLayout.PREVIEW) ShortformSdk.hidePreview()
    }

    override fun onResume() {
        super.onResume()
        if (product != null && renderedKey != null && renderedKey != graph.settings.accessKey) {
            // The access key changed in Settings: match again with the new account.
            resolutions.clear()
            render()
        }
        typeView?.let { ShortformSdk.setPlaying(it, options.autoplay) }
    }

    override fun onPause() {
        super.onPause()
        typeView?.let { ShortformSdk.setPlaying(it, false) }
    }

    private fun update(newOptions: DetailOptions) {
        val leftPreview = options.layout == ShortformLayout.PREVIEW && newOptions.layout != ShortformLayout.PREVIEW
        options = newOptions
        graph.options.save(newOptions)
        if (leftPreview) ShortformSdk.hidePreview()
        render()
    }

    // ── Product ─────────────────────────────────────────────────────────────────

    private fun bindProduct(p: Product) {
        binding.toolbar.title = p.brand ?: p.name
        binding.brand.text = p.brand.orEmpty()
        binding.brand.isVisible = !p.brand.isNullOrBlank()
        binding.name.text = p.name
        binding.price.text = ProductFormat.price(this, p, large = true)

        val pages = p.imageUrls.size.coerceAtLeast(1)
        binding.imagePager.adapter = ImagePagerAdapter(p, pages)
        binding.imageIndicator.isVisible = pages > 1
        binding.imageIndicator.text = getString(R.string.detail_image_position, 1, pages)
        binding.imagePager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                binding.imageIndicator.text = getString(R.string.detail_image_position, position + 1, pages)
            }
        })
    }

    private fun bindDescription(p: Product) {
        val text = p.description?.trim().orEmpty()
        if (options.position == SectionPosition.INSIDE_DESCRIPTION) {
            val (first, second) = ProductFormat.splitDescription(text)
            binding.descriptionFirst.text = first.ifEmpty { getString(R.string.detail_no_description) }
            binding.descriptionSecond.text = second
            binding.descriptionSecond.isVisible = second.isNotEmpty()
        } else {
            binding.descriptionFirst.text = text.ifEmpty { getString(R.string.detail_no_description) }
            binding.descriptionSecond.isVisible = false
        }
    }

    // ── Option bar + section ────────────────────────────────────────────────────

    private fun render() {
        val p = product ?: return
        val c = catalog ?: return
        renderedKey = graph.settings.accessKey
        renderOptionBar()
        bindDescription(p)
        placeSection()
        renderSection(p, c)
    }

    private fun renderOptionBar() {
        binding.optionBar.isVisible = !options.barCollapsed
        binding.toolbar.menu.findItem(R.id.action_toggle_options)?.title =
            getString(if (options.barCollapsed) R.string.detail_show_options else R.string.detail_hide_options)

        binding.optionLayout.text = chip(R.string.option_layout, getString(OptionLabels.layout(options.layout)))
        binding.optionPosition.text = chip(R.string.option_position, getString(OptionLabels.position(options.position)))
        binding.optionCard.text = chip(R.string.option_card, getString(R.string.option_card_type_value, options.cardType))
        binding.optionPreview.text = chip(R.string.option_preview, getString(OptionLabels.corner(options.previewCorner)))

        // Options that do not apply to the current layout stay tappable but dimmed.
        val inPage = options.layout in setOf(ShortformLayout.STRIP, ShortformLayout.LARGE_CARDS, ShortformLayout.GRID)
        binding.optionCard.alpha = if (inPage) 1f else DIMMED
        binding.optionPreview.alpha = if (options.layout == ShortformLayout.PREVIEW) 1f else DIMMED
    }

    private fun chip(label: Int, value: String) = getString(R.string.option_chip, getString(label), value)

    private fun placeSection() {
        val slot: ViewGroup = when (options.position) {
            SectionPosition.ABOVE_IMAGES -> binding.slotAboveImages
            SectionPosition.BELOW_IMAGES -> binding.slotBelowImages
            SectionPosition.BELOW_PRICE -> binding.slotBelowPrice
            SectionPosition.INSIDE_DESCRIPTION -> binding.slotInsideDescription
            SectionPosition.BOTTOM -> binding.slotBottom
        }
        if (section.root.parent === slot) return
        (section.root.parent as? ViewGroup)?.removeView(section.root)
        slot.addView(section.root)
    }

    private fun renderSection(p: Product, c: Catalog) {
        section.sectionBody.removeAllViews()
        typeView = null
        section.sectionTitle.setText(R.string.detail_shortform_title)
        section.sectionSubtitle.isVisible = false

        if (graph.settings.accessKey.isEmpty()) {
            message(getString(R.string.detail_needs_key), getString(R.string.detail_open_settings)) {
                startActivity(SettingsActivity.intent(this))
            }
            return
        }

        val forPreview = options.layout == ShortformLayout.PREVIEW
        when (val r = resolutions[forPreview]) {
            null -> {
                message(getString(R.string.detail_loading), progress = true)
                startResolving(p, c, forPreview)
            }
            Resolution.Failed -> message(getString(R.string.detail_load_failed), getString(R.string.common_retry)) {
                resolutions.remove(forPreview)
                render()
            }
            Resolution.NoneFound -> message(getString(R.string.detail_no_shortform))
            is Resolution.Found -> showStep(r.step)
        }
    }

    private fun startResolving(p: Product, c: Catalog, forPreview: Boolean) {
        if (!resolving.add(forPreview)) return
        resolveShortform(this, ShortformMatcher.steps(p, c, forPreview)) { result ->
            resolving.remove(forPreview)
            resolutions[forPreview] = result
            if (!isDestroyed) render()
        }
    }

    private fun showStep(step: MatchStep) {
        section.sectionTitle.setText(if (step.isRelated) R.string.detail_related_shortform else R.string.detail_shortform_title)
        subtitle(
            when (step.kind) {
                MatchStep.Kind.PRODUCT -> getString(
                    when {
                        step.condition.productId != null -> R.string.detail_match_product_id
                        step.condition.url != null -> R.string.detail_match_url
                        else -> R.string.detail_match_sku
                    },
                )
                MatchStep.Kind.VERTICAL_TAGS -> getString(R.string.detail_match_tags, step.condition.tags.joinToString(", "))
                MatchStep.Kind.FALLBACK -> getString(R.string.detail_match_fallback)
            },
        )
        val style = ShortformSdk.CardStyle.from(options)
        val density = resources.displayMetrics.density
        when (options.layout) {
            ShortformLayout.STRIP -> addTypeView(
                ShortformSdk.horizontal(this, step.condition, style),
                resources.getDimensionPixelSize(R.dimen.shortform_strip_height),
            )
            // Large cards scroll inside a fixed-height area: one card is about a screen tall.
            ShortformLayout.LARGE_CARDS -> addTypeView(
                ShortformSdk.largeCards(this, step.condition, style),
                resources.getDimensionPixelSize(R.dimen.shortform_feed_height),
            )
            // The grid shows two rows in the page.
            ShortformLayout.GRID -> {
                val rows = 2
                val cellWidth = (resources.displayMetrics.widthPixels - 16 * density) / options.columns
                val height = (rows * (cellWidth * 16 / 9 + 72 * density)).toInt()
                addTypeView(ShortformSdk.grid(this, step.condition, style.copy(maxCount = rows * options.columns)), height)
            }
            ShortformLayout.BUTTON -> {
                val button = LayoutInflater.from(this).inflate(R.layout.view_play_button, section.sectionBody, false) as MaterialButton
                button.setOnClickListener { ShortformSdk.play(this, step.condition) }
                section.sectionBody.addView(button)
            }
            ShortformLayout.PREVIEW -> {
                message(
                    getString(R.string.detail_preview_showing, getString(OptionLabels.corner(options.previewCorner))),
                    getString(R.string.detail_preview_show_again),
                ) { showPreview() }
                showPreview()
            }
        }
    }

    private fun addTypeView(view: ShopLiveShortformBaseTypeView, height: Int) {
        typeView = view
        section.sectionBody.addView(view, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, height))
        ShortformSdk.setPlaying(view, options.autoplay)
    }

    /** Posted, so the top bar has its final height when the preview margins are computed. */
    private fun showPreview() {
        binding.root.post { if (started) showPreviewNow() }
    }

    private fun showPreviewNow() {
        val step = (resolutions[true] as? Resolution.Found)?.step ?: return
        val bars = ViewCompat.getRootWindowInsets(binding.root)
            ?.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
        ShortformSdk.showPreview(
            this,
            step.condition,
            options,
            ShortformSdk.PreviewInsets(
                // Top corners also clear the top bar and option bar.
                top = binding.appBar.height.coerceAtLeast(bars?.top ?: 0),
                bottom = bars?.bottom ?: 0,
                left = bars?.left ?: 0,
                right = bars?.right ?: 0,
            ),
        )
    }

    private fun subtitle(text: String) {
        section.sectionSubtitle.text = text
        section.sectionSubtitle.isVisible = true
    }

    private fun message(text: String, action: String? = null, progress: Boolean = false, onAction: (() -> Unit)? = null) {
        val m = ViewSectionMessageBinding.inflate(layoutInflater, section.sectionBody, true)
        m.messageText.text = text
        m.messageProgress.isVisible = progress
        m.messageButton.isVisible = action != null
        m.messageButton.text = action
        m.messageButton.setOnClickListener { onAction?.invoke() }
    }

    private class ImagePagerAdapter(private val product: Product, private val pages: Int) :
        RecyclerView.Adapter<ImagePagerAdapter.Holder>() {
        class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val image: ImageView = view.findViewById(R.id.productImage)
            val initial: TextView = view.findViewById(R.id.productInitial)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            Holder(LayoutInflater.from(parent.context).inflate(R.layout.item_detail_image, parent, false))

        override fun getItemCount() = pages

        override fun onBindViewHolder(holder: Holder, position: Int) =
            ProductFormat.bindImage(holder.image, holder.initial, product, position)
    }

    companion object {
        private const val EXTRA_PRODUCT_ID = "productId"
        private const val DIMMED = 0.5f

        fun intent(context: Context, productId: String) =
            Intent(context, ProductDetailActivity::class.java).putExtra(EXTRA_PRODUCT_ID, productId)
    }
}
