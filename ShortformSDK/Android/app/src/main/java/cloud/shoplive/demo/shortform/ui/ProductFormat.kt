package cloud.shoplive.demo.shortform.ui

import android.content.Context
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StrikethroughSpan
import android.text.style.StyleSpan
import android.widget.ImageView
import android.widget.TextView
import androidx.core.view.isVisible
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.Product
import com.bumptech.glide.Glide
import com.google.android.material.color.MaterialColors
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale
import kotlin.math.roundToInt

object ProductFormat {

    fun money(amount: Double, currencyCode: String, locale: Locale = Locale.getDefault()): String {
        val format = NumberFormat.getCurrencyInstance(locale)
        try {
            val currency = Currency.getInstance(currencyCode)
            format.currency = currency
            format.maximumFractionDigits = currency.defaultFractionDigits.coerceAtLeast(0)
            format.minimumFractionDigits = currency.defaultFractionDigits.coerceAtLeast(0)
        } catch (e: IllegalArgumentException) {
            return "${NumberFormat.getNumberInstance(locale).format(amount)} $currencyCode"
        }
        return format.format(amount)
    }

    /** The catalog's discountRate, else computed from the two prices. */
    fun discountPercent(product: Product): Int? {
        if (!product.hasDiscount) return null
        product.discountRate?.takeIf { it > 0 }?.let { return it.roundToInt() }
        val sale = product.discountPrice ?: return null
        if (product.originalPrice <= 0) return null
        return ((1 - sale / product.originalPrice) * 100).roundToInt().takeIf { it > 0 }
    }

    /** "11%  ₩79,000  ₩89,000" with the rate highlighted and the original price struck through. */
    fun price(context: Context, product: Product, large: Boolean = false): CharSequence {
        val out = SpannableStringBuilder()
        discountPercent(product)?.let { rate ->
            val start = out.length
            out.append(context.getString(R.string.detail_discount_rate, rate))
            val color = MaterialColors.getColor(context, com.google.android.material.R.attr.colorError, 0)
            out.setSpan(ForegroundColorSpan(color), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            out.setSpan(StyleSpan(Typeface.BOLD), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            out.append("  ")
        }
        val saleStart = out.length
        out.append(money(product.salePrice, product.currency))
        out.setSpan(StyleSpan(Typeface.BOLD), saleStart, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (product.hasDiscount) {
            out.append("  ")
            val start = out.length
            out.append(money(product.originalPrice, product.currency))
            out.setSpan(StrikethroughSpan(), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            out.setSpan(RelativeSizeSpan(if (large) 0.8f else 0.85f), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            val muted = MaterialColors.getColor(context, com.google.android.material.R.attr.colorOnSurfaceVariant, 0)
            out.setSpan(ForegroundColorSpan(muted), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        return out
    }

    /** Loads the first image, or shows the product's initial on a tinted tile. */
    fun bindImage(image: ImageView, placeholder: TextView, product: Product, index: Int = 0) {
        val url = product.imageUrls.getOrNull(index)
        placeholder.text = product.name.trim().take(1).uppercase(Locale.getDefault())
        placeholder.isVisible = url == null
        if (url == null) {
            Glide.with(image).clear(image)
            image.setImageDrawable(null)
        } else {
            Glide.with(image).load(url).centerCrop().into(image)
        }
    }

    /**
     * Splits a description in two near the middle, at a sentence or line break, for the
     * "Inside description" position. Short text stays in the first part.
     */
    fun splitDescription(text: String?): Pair<String, String> {
        val t = text?.trim().orEmpty()
        if (t.length < 2) return t to ""
        val middle = t.length / 2
        val breaks = Regex("(?<=[.!?。])\\s+|\\n+").findAll(t).map { it.range.first }.toList()
        val at = breaks.minByOrNull { kotlin.math.abs(it - middle) } ?: return t to ""
        val first = t.substring(0, at).trim()
        val second = t.substring(at).trim()
        return if (first.isEmpty() || second.isEmpty()) t to "" else first to second
    }
}
