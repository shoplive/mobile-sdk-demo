package cloud.shoplive.demo.shortform.shortform

import android.content.Context
import cloud.shoplive.demo.shortform.catalog.Product

/** Result of walking the matching steps against the SDK. */
sealed class Resolution {
    data class Found(val step: MatchStep) : Resolution()
    /** No step returned shortform (or the product has no step at all). */
    object NoneFound : Resolution()
    /** A request failed; nothing can be said about the remaining steps. */
    object Failed : Resolution()
}

/** Walks [steps] in order with [ShortformSdk.hasShortform] and reports the first that has shortform. */
fun resolveShortform(context: Context, steps: List<MatchStep>, done: (Resolution) -> Unit) {
    fun next(index: Int) {
        if (index >= steps.size) {
            done(Resolution.NoneFound)
            return
        }
        ShortformSdk.hasShortform(context, steps[index].condition) { has ->
            when (has) {
                true -> done(Resolution.Found(steps[index]))
                false -> next(index + 1)
                null -> done(Resolution.Failed)
            }
        }
    }
    next(0)
}

/**
 * Remembers which products have their own shortform (matching step 1), for the ▶ badge on
 * product cards. Only products with a sku can be checked this way (see [ShortformMatcher]).
 */
object ShortformAvailability {
    private val known = HashMap<String, Boolean>()
    private val pending = HashSet<String>()

    fun has(product: Product): Boolean = known[product.productId] == true

    fun check(context: Context, products: List<Product>, changed: () -> Unit) {
        products.forEach { product ->
            val sku = product.sku?.takeIf { it.isNotBlank() } ?: return@forEach
            if (product.productId in known || !pending.add(product.productId)) return@forEach
            ShortformSdk.hasShortform(context, ShortformCondition(skus = listOf(sku))) { has ->
                pending.remove(product.productId)
                if (has != null) {
                    known[product.productId] = has
                    if (has) changed()
                }
            }
        }
    }

    fun clear() {
        known.clear()
        pending.clear()
    }
}
