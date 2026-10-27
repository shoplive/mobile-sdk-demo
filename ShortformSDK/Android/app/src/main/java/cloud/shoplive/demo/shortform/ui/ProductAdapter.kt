package cloud.shoplive.demo.shortform.ui

import android.annotation.SuppressLint
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.RecyclerView
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.Product
import cloud.shoplive.demo.shortform.shortform.ShortformAvailability

/** Product cards for Home, Results (grid or list). The ▶ badge marks products with their own shortform. */
class ProductAdapter(
    private val onClick: (Product) -> Unit,
) : RecyclerView.Adapter<ProductAdapter.Holder>() {

    var list: Boolean = false
        @SuppressLint("NotifyDataSetChanged")
        set(value) {
            if (field != value) {
                field = value
                notifyDataSetChanged()
            }
        }

    private var items: List<Product> = emptyList()

    @SuppressLint("NotifyDataSetChanged")
    fun submit(products: List<Product>) {
        items = products
        notifyDataSetChanged()
    }

    /** Re-binds the badges after [ShortformAvailability] learned something. */
    fun refreshBadges() = notifyItemRangeChanged(0, items.size)

    override fun getItemViewType(position: Int): Int = if (list) R.layout.item_product_list else R.layout.item_product_grid

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder =
        Holder(LayoutInflater.from(parent.context).inflate(viewType, parent, false))

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: Holder, position: Int) = holder.bind(items[position])

    inner class Holder(view: View) : RecyclerView.ViewHolder(view) {
        private val image: ImageView = view.findViewById(R.id.productImage)
        private val initial: TextView = view.findViewById(R.id.productInitial)
        private val badge: View = view.findViewById(R.id.productBadge)
        private val brand: TextView = view.findViewById(R.id.productBrand)
        private val name: TextView = view.findViewById(R.id.productName)
        private val price: TextView = view.findViewById(R.id.productPrice)

        fun bind(product: Product) {
            ProductFormat.bindImage(image, initial, product)
            badge.isVisible = ShortformAvailability.has(product)
            brand.text = product.brand.orEmpty()
            brand.isVisible = !product.brand.isNullOrBlank()
            name.text = product.name
            price.text = ProductFormat.price(itemView.context, product)
            itemView.setOnClickListener { onClick(product) }
        }
    }
}
