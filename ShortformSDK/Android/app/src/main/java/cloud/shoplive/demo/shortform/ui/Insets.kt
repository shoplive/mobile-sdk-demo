package cloud.shoplive.demo.shortform.ui

import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding

/**
 * Edge-to-edge: pads a view by the system bars and display cutout on the chosen edges, on top
 * of its own padding. With [ime], the bottom edge also clears the keyboard.
 * Insets are passed on unconsumed, so sibling views get them too.
 */
fun View.applyInsets(top: Boolean = false, bottom: Boolean = false, ime: Boolean = false, sides: Boolean = true) {
    val start = Padding(paddingLeft, paddingTop, paddingRight, paddingBottom)
    ViewCompat.setOnApplyWindowInsetsListener(this) { v, insets ->
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
        val keyboard = if (ime) insets.getInsets(WindowInsetsCompat.Type.ime()).bottom else 0
        v.updatePadding(
            left = start.left + if (sides) bars.left else 0,
            top = start.top + if (top) bars.top else 0,
            right = start.right + if (sides) bars.right else 0,
            bottom = start.bottom + maxOf(if (bottom) bars.bottom else 0, keyboard),
        )
        insets
    }
    if (isAttachedToWindow) {
        ViewCompat.requestApplyInsets(this)
    } else {
        addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                v.removeOnAttachStateChangeListener(this)
                ViewCompat.requestApplyInsets(v)
            }

            override fun onViewDetachedFromWindow(v: View) = Unit
        })
    }
}

private data class Padding(val left: Int, val top: Int, val right: Int, val bottom: Int)
