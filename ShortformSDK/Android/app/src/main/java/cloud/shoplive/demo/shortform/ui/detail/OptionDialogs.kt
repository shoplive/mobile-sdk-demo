package cloud.shoplive.demo.shortform.ui.detail

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.annotation.StringRes
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.data.DetailOptions
import cloud.shoplive.demo.shortform.data.PreviewCorner
import cloud.shoplive.demo.shortform.data.PreviewSize
import cloud.shoplive.demo.shortform.data.SectionPosition
import cloud.shoplive.demo.shortform.data.ShortformLayout
import com.google.android.material.chip.Chip
import com.google.android.material.chip.ChipGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch

/** Labels shared by the option bar chips and the dialogs. */
object OptionLabels {
    @StringRes
    fun layout(l: ShortformLayout) = when (l) {
        ShortformLayout.STRIP -> R.string.option_layout_strip
        ShortformLayout.LARGE_CARDS -> R.string.option_layout_large_cards
        ShortformLayout.GRID -> R.string.option_layout_grid
        ShortformLayout.PREVIEW -> R.string.option_layout_preview
        ShortformLayout.BUTTON -> R.string.option_layout_button
    }

    @StringRes
    fun position(p: SectionPosition) = when (p) {
        SectionPosition.ABOVE_IMAGES -> R.string.option_position_above_images
        SectionPosition.BELOW_IMAGES -> R.string.option_position_below_images
        SectionPosition.BELOW_PRICE -> R.string.option_position_below_price
        SectionPosition.INSIDE_DESCRIPTION -> R.string.option_position_inside_description
        SectionPosition.BOTTOM -> R.string.option_position_bottom
    }

    @StringRes
    fun corner(c: PreviewCorner) = when (c) {
        PreviewCorner.TOP_LEFT -> R.string.option_preview_corner_top_left
        PreviewCorner.TOP_RIGHT -> R.string.option_preview_corner_top_right
        PreviewCorner.BOTTOM_LEFT -> R.string.option_preview_corner_bottom_left
        PreviewCorner.BOTTOM_RIGHT -> R.string.option_preview_corner_bottom_right
    }

    @StringRes
    fun size(s: PreviewSize) = when (s) {
        PreviewSize.SMALL -> R.string.option_preview_size_small
        PreviewSize.MEDIUM -> R.string.option_preview_size_medium
        PreviewSize.LARGE -> R.string.option_preview_size_large
    }

    fun maxCount(context: Context, n: Int): String =
        if (n == 0) context.getString(R.string.option_preview_max_unlimited) else n.toString()
}

/**
 * The option bar dialogs. Every change is applied right away through [onChange], so the page
 * re-renders behind the dialog.
 */
class OptionDialogs(
    private val context: Context,
    private val current: () -> DetailOptions,
    private val onChange: (DetailOptions) -> Unit,
) {

    fun showLayout() {
        val values = ShortformLayout.values()
        val labels = values.map { context.getString(OptionLabels.layout(it)) }.toTypedArray()
        MaterialAlertDialogBuilder(context)
            .setTitle(R.string.option_layout)
            .setSingleChoiceItems(labels, values.indexOf(current().layout)) { dialog, which ->
                onChange(current().copy(layout = values[which]))
                dialog.dismiss()
            }
            .show()
    }

    fun showPosition() {
        val values = SectionPosition.values()
        val labels = values.map { context.getString(OptionLabels.position(it)) }.toTypedArray()
        MaterialAlertDialogBuilder(context)
            .setTitle(R.string.option_position)
            .setSingleChoiceItems(labels, values.indexOf(current().position)) { dialog, which ->
                onChange(current().copy(position = values[which]))
                dialog.dismiss()
            }
            .show()
    }

    fun showCard() {
        val body = column()
        val o = current()
        body.addView(label(R.string.option_card_type))
        body.addView(choices(DetailOptions.CARD_TYPES, o.cardType, { context.getString(R.string.option_card_type_value, it) }) {
            onChange(current().copy(cardType = it))
        })
        body.addView(switch(R.string.option_card_show_title, o.showTitle) { onChange(current().copy(showTitle = it)) })
        body.addView(switch(R.string.option_card_show_view_count, o.showViewCount) { onChange(current().copy(showViewCount = it)) })
        body.addView(switch(R.string.option_card_show_product_count, o.showProductCount) { onChange(current().copy(showProductCount = it)) })
        body.addView(switch(R.string.option_card_autoplay, o.autoplay) { onChange(current().copy(autoplay = it)) })
        body.addView(label(R.string.option_card_columns))
        body.addView(choices(DetailOptions.COLUMN_CHOICES, o.columns, { it.toString() }) { onChange(current().copy(columns = it)) })
        show(R.string.option_card, body)
    }

    fun showPreview() {
        val body = column()
        val o = current()
        body.addView(label(R.string.option_preview_corner))
        body.addView(choices(PreviewCorner.values().toList(), o.previewCorner, { context.getString(OptionLabels.corner(it)) }) {
            onChange(current().copy(previewCorner = it))
        })
        body.addView(label(R.string.option_preview_size))
        body.addView(choices(PreviewSize.values().toList(), o.previewSize, { context.getString(OptionLabels.size(it)) }) {
            onChange(current().copy(previewSize = it))
        })
        body.addView(label(R.string.option_preview_max_count))
        body.addView(choices(DetailOptions.PREVIEW_MAX_COUNTS, o.previewMaxCount, { OptionLabels.maxCount(context, it) }) {
            onChange(current().copy(previewMaxCount = it))
        })
        show(R.string.option_preview, body)
    }

    // ── building blocks ─────────────────────────────────────────────────────────

    private fun dp(v: Int) = (v * context.resources.displayMetrics.density).toInt()

    private fun column() = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(24), dp(8), dp(24), dp(8))
    }

    private fun show(@StringRes title: Int, body: LinearLayout) {
        MaterialAlertDialogBuilder(context)
            .setTitle(title)
            .setView(ScrollView(context).apply { addView(body) })
            .setPositiveButton(R.string.common_done, null)
            .show()
    }

    private fun label(@StringRes text: Int) = TextView(context).apply {
        setText(text)
        setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_LabelLarge)
        setPadding(0, dp(12), 0, dp(4))
    }

    private fun switch(@StringRes text: Int, checked: Boolean, changed: (Boolean) -> Unit) = MaterialSwitch(context).apply {
        setText(text)
        isChecked = checked
        setOnCheckedChangeListener { _, isChecked -> changed(isChecked) }
    }

    private fun <T> choices(values: List<T>, selected: T, label: (T) -> String, picked: (T) -> Unit) =
        ChipGroup(context).apply {
            isSingleSelection = true
            isSelectionRequired = true
            values.forEach { value ->
                val chip = LayoutInflater.from(context).inflate(R.layout.chip_choice, this, false) as Chip
                addView(chip.apply {
                    id = View.generateViewId()
                    text = label(value)
                    isChecked = value == selected
                    setOnClickListener { if (isChecked) picked(value) }
                })
            }
        }
}
