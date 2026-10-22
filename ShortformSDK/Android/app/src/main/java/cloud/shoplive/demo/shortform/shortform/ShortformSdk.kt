package cloud.shoplive.demo.shortform.shortform

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.lifecycle.LifecycleOwner
import cloud.shoplive.demo.shortform.DemoApp
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.data.DetailOptions
import cloud.shoplive.demo.shortform.data.PreviewCorner
import cloud.shoplive.demo.shortform.ui.detail.ProductDetailActivity
import cloud.shoplive.sdk.common.ShopLiveCommon
import cloud.shoplive.sdk.common.ShopLiveCommonError
import cloud.shoplive.sdk.common.ShopLivePreviewPositionConfig
import cloud.shoplive.sdk.network.request.ShopLiveShortformTagSearchOperator
import cloud.shoplive.sdk.network.response.ShopLiveShortformCollectionResponse
import cloud.shoplive.sdk.network.response.ShopLiveShortformData
import cloud.shoplive.sdk.network.response.ShopLiveShortformProductData
import cloud.shoplive.sdk.shorts.ShopLiveShortform
import cloud.shoplive.sdk.shorts.ShopLiveShortformBaseTypeView
import cloud.shoplive.sdk.shorts.ShopLiveShortformCardTypeView
import cloud.shoplive.sdk.shorts.ShopLiveShortformCollectionData
import cloud.shoplive.sdk.shorts.ShopLiveShortformCollectionListener
import cloud.shoplive.sdk.shorts.ShopLiveShortformHorizontalTypeView
import cloud.shoplive.sdk.shorts.ShopLiveShortformIdentifier
import cloud.shoplive.sdk.shorts.ShopLiveShortformListener
import cloud.shoplive.sdk.shorts.ShopLiveShortformMessageListener
import cloud.shoplive.sdk.shorts.ShopLiveShortformPreviewData
import cloud.shoplive.sdk.shorts.ShopLiveShortformShareData
import cloud.shoplive.sdk.shorts.ShopLiveShortformVerticalTypeView

/**
 * Every Shortform SDK call the demo makes lives in this file, so it reads as the integration
 * guide: access key, list views, full screen, floating preview, and the product-tap callback.
 */
object ShortformSdk {

    // ── Setup ──────────────────────────────────────────────────────────────────

    /** The only setup call Shortform needs. Called on start and when Settings changes the key. */
    fun applyAccessKey(accessKey: String) {
        if (accessKey.isNotBlank()) ShopLiveCommon.setAccessKey(accessKey.trim())
    }

    fun hasAccessKey(): Boolean = !ShopLiveCommon.getAccessKey().isNullOrBlank()

    // ── Conditions ─────────────────────────────────────────────────────────────

    private fun ShortformCondition.toCollectionData() = ShopLiveShortformCollectionData().also { data ->
        data.shortsCollectionId = collectionId
        data.tags = tags.ifEmpty { null }
        data.tagSearchOperator = if (tags.isEmpty()) null else ShopLiveShortformTagSearchOperator.OR
        data.skus = skus.ifEmpty { null }
        data.listener = DemoListener
    }

    /** Points a list view at a condition. Call [ShopLiveShortformBaseTypeView.submit] after. */
    private fun ShopLiveShortformBaseTypeView.applyCondition(condition: ShortformCondition) {
        listener = DemoListener
        setShortsCollectionId(condition.collectionId)
        setHashTags(condition.tags.ifEmpty { null }, ShopLiveShortformTagSearchOperator.OR)
        setSkus(condition.skus.ifEmpty { null })
        setBrands(null)
    }

    // ── Matching probe ─────────────────────────────────────────────────────────

    /**
     * Asks the SDK whether a condition returns any shortform: true / false, or null when the
     * request failed. Uses [ShopLiveShortform.get], which takes the same condition as the views.
     */
    fun hasShortform(owner: Context, condition: ShortformCondition, result: (Boolean?) -> Unit) {
        if (owner !is LifecycleOwner || !hasAccessKey()) {
            result(null)
            return
        }
        ShopLiveShortform.get(owner, condition.toCollectionData(), object : ShopLiveShortformCollectionListener {
            override fun onData(data: ShopLiveShortformCollectionResponse) {
                result(!data.shortsList.isNullOrEmpty())
            }

            override fun onError(e: Exception) {
                EventLog.add("get.onError", e.message.orEmpty())
                result(null)
            }
        })
    }

    // ── List views ─────────────────────────────────────────────────────────────

    data class CardStyle(
        val cardType: Int = 0,
        val showTitle: Boolean = true,
        val showViewCount: Boolean = true,
        val showProductCount: Boolean = true,
        val columns: Int = 2,
        val autoplay: Boolean = true,
        val maxCount: Int? = null,
    ) {
        companion object {
            fun from(o: DetailOptions, maxCount: Int? = null) = CardStyle(
                o.cardType, o.showTitle, o.showViewCount, o.showProductCount, o.columns, o.autoplay, maxCount,
            )
        }
    }

    private fun cardViewType(cardType: Int) = when (cardType) {
        1 -> ShopLiveShortform.CardViewType.CARD_TYPE1
        2 -> ShopLiveShortform.CardViewType.CARD_TYPE2
        else -> ShopLiveShortform.CardViewType.CARD_TYPE0
    }

    private fun ShopLiveShortformBaseTypeView.applyStyle(style: CardStyle) {
        setVisibleTitle(style.showTitle)
        setVisibleViewCount(style.showViewCount)
        setVisibleProductCount(style.showProductCount)
        style.maxCount?.takeIf { it > 0 }?.let { setMaxCount(it) }
    }

    fun horizontal(context: Context, condition: ShortformCondition, style: CardStyle = CardStyle()) =
        ShopLiveShortformHorizontalTypeView(context).apply {
            applyCondition(condition)
            setViewType(cardViewType(style.cardType))
            applyStyle(style)
            submit()
            if (style.autoplay) enablePlayVideos() else disablePlayVideos()
        }

    fun cardGrid(context: Context, condition: ShortformCondition, style: CardStyle) =
        ShopLiveShortformCardTypeView(context).apply {
            applyCondition(condition)
            setViewType(cardViewType(style.cardType))
            setSpanCount(style.columns.coerceAtLeast(1))
            applyStyle(style)
            submit()
            if (style.autoplay) enablePlayVideos() else disablePlayVideos()
        }

    fun verticalFeed(context: Context, condition: ShortformCondition, style: CardStyle) =
        ShopLiveShortformVerticalTypeView(context).apply {
            applyCondition(condition)
            setViewType(cardViewType(style.cardType))
            setSpanCount(style.columns.coerceAtLeast(1))
            applyStyle(style)
            submit()
            if (style.autoplay) enablePlayVideos() else disablePlayVideos()
        }

    /** Pause / resume video in a list view with the screen's lifecycle. */
    fun setPlaying(view: ShopLiveShortformBaseTypeView, playing: Boolean) {
        if (playing) view.enablePlayVideos() else view.disablePlayVideos()
    }

    // ── Full screen ────────────────────────────────────────────────────────────

    fun play(context: Context, condition: ShortformCondition) {
        ShopLiveShortform.play(context, condition.toCollectionData())
    }

    // ── Floating preview ───────────────────────────────────────────────────────

    data class PreviewInsets(val top: Int, val bottom: Int, val left: Int, val right: Int)

    fun showPreview(activity: Activity, condition: ShortformCondition, options: DetailOptions, insetsPx: PreviewInsets) {
        val density = activity.resources.displayMetrics.density
        val longSide = (options.previewSize.longSideDp * density).toInt()
        val margin = (16 * density).toInt()
        ShopLiveShortform.hidePreview()
        ShopLiveShortform.showPreview(activity, ShopLiveShortformPreviewData().apply {
            productId = condition.productId
            url = condition.url
            skus = condition.skus.ifEmpty { null }
            tags = condition.tags.ifEmpty { null }
            tagSearchOperator = if (condition.tags.isEmpty()) null else ShopLiveShortformTagSearchOperator.OR
            // A collection condition has no preview field; it is never used for the preview.
            setPosition(
                when (options.previewCorner) {
                    PreviewCorner.TOP_LEFT -> ShopLivePreviewPositionConfig.TOP_LEFT
                    PreviewCorner.TOP_RIGHT -> ShopLivePreviewPositionConfig.TOP_RIGHT
                    PreviewCorner.BOTTOM_LEFT -> ShopLivePreviewPositionConfig.BOTTOM_LEFT
                    PreviewCorner.BOTTOM_RIGHT -> ShopLivePreviewPositionConfig.BOTTOM_RIGHT
                }
            )
            // Portrait 9:16 inside a square of the chosen size.
            setHeight(longSide)
            setWidth(longSide * 9 / 16)
            // Keep the preview clear of the system bars (edge-to-edge).
            setMarginTop(insetsPx.top + margin)
            setMarginBottom(insetsPx.bottom + margin)
            setMarginLeft(insetsPx.left + margin)
            setMarginRight(insetsPx.right + margin)
            if (options.previewMaxCount > 0) setMaxCount(options.previewMaxCount)
            isMuted = true
            listener = DemoListener
        })
    }

    fun hidePreview() = ShopLiveShortform.hidePreview()

    // ── Callbacks ──────────────────────────────────────────────────────────────

    /**
     * One listener for every view, preview and full-screen player. A product tapped inside a
     * video closes the SDK player and opens the app's own Product detail.
     */
    object DemoListener : ShopLiveShortformListener {
        override fun onProductClick(
            context: Context,
            identifier: ShopLiveShortformIdentifier?,
            product: ShopLiveShortformProductData,
        ) {
            EventLog.add("onProductClick", "productId=${product.productId} sku=${product.sku} shortsId=${identifier?.shortsId}")
            val catalog = DemoApp.graph(context).catalogRepository.current?.catalog
            val match = catalog?.findSdkProduct(product.productId, product.sku, product.url)
            if (match == null) {
                Toast.makeText(context, R.string.detail_product_not_in_catalog, Toast.LENGTH_SHORT).show()
                return
            }
            ShopLiveShortform.close()
            ShopLiveShortform.hidePreview()
            val intent = ProductDetailActivity.intent(context.applicationContext, match.productId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.applicationContext.startActivity(intent)
        }

        override fun onEvent(
            context: Context,
            messenger: ShopLiveShortformMessageListener?,
            command: String,
            payload: Map<String, Any?>,
        ) {
            EventLog.add(command, payload.toString())
        }

        override fun onError(context: Context, error: ShopLiveCommonError) {
            EventLog.add("onError", "${error.code} ${error.message.orEmpty()}")
        }

        override fun onShortsAttached(data: ShopLiveShortformData) {
            EventLog.add("onShortsAttached", "shortsId=${data.shortsId}")
        }

        override fun onShortsDetached(data: ShopLiveShortformData) {
            EventLog.add("onShortsDetached", "shortsId=${data.shortsId}")
        }

        override fun onDetailShown() = EventLog.add("onDetailShown")

        override fun onDetailHidden() = EventLog.add("onDetailHidden")

        override fun onShare(context: Context, data: ShopLiveShortformShareData) {
            EventLog.add("onShare", "shortsId=${data.shortsId}")
            val text = data.title?.takeIf { it.isNotBlank() } ?: return
            val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
            context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }

        override fun onBannerClick(context: Context, identifier: ShopLiveShortformIdentifier?, url: String) {
            EventLog.add("onBannerClick", "shortsId=${identifier?.shortsId}")
        }
    }
}
