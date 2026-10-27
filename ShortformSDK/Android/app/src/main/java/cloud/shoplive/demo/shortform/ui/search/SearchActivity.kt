package cloud.shoplive.demo.shortform.ui.search

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.TextView
import androidx.core.widget.doAfterTextChanged
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.Catalog
import cloud.shoplive.demo.shortform.catalog.Product
import cloud.shoplive.demo.shortform.catalog.ProductSearch
import cloud.shoplive.demo.shortform.databinding.ActivitySearchBinding
import cloud.shoplive.demo.shortform.shortform.ShortformAvailability
import cloud.shoplive.demo.shortform.ui.BaseActivity
import cloud.shoplive.demo.shortform.ui.ProductAdapter
import cloud.shoplive.demo.shortform.ui.applyInsets
import cloud.shoplive.demo.shortform.ui.detail.ProductDetailActivity
import cloud.shoplive.demo.shortform.ui.results.ResultsActivity

/**
 * Search: suggested keywords; while typing, the demo-product section first (it never
 * disappears), then other matches. A demo product opens Product detail; a keyword opens Results.
 */
class SearchActivity : BaseActivity() {

    private lateinit var binding: ActivitySearchBinding
    private var catalog: Catalog? = null
    private val rows = RowAdapter()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySearchBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setUpTopBar(binding.appBar, binding.toolbar, null)
        binding.list.applyInsets(bottom = true, ime = true)
        binding.list.layoutManager = LinearLayoutManager(this)
        binding.list.adapter = rows

        binding.searchInput.doAfterTextChanged { render() }
        binding.searchInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                val q = binding.searchInput.text.toString().trim()
                if (q.isNotEmpty()) openResults(q)
                true
            } else {
                false
            }
        }
        binding.searchInput.requestFocus()
        binding.searchInput.post {
            getSystemService(InputMethodManager::class.java)?.showSoftInput(binding.searchInput, InputMethodManager.SHOW_IMPLICIT)
        }

        withCatalog { loaded ->
            catalog = loaded.catalog
            ShortformAvailability.check(this, loaded.catalog.products) { rows.notifyItemRangeChanged(0, rows.itemCount) }
            render()
        }
    }

    private fun render() {
        val catalog = catalog ?: return
        val search = ProductSearch(catalog)
        val query = binding.searchInput.text.toString().trim()
        val out = mutableListOf<Row>()
        if (query.isEmpty()) {
            val keywords = search.suggestedKeywords()
            if (keywords.isNotEmpty()) {
                out += Row.Header(getString(R.string.search_suggested))
                keywords.forEach { out += Row.Keyword(it) }
            }
            out += Row.Header(getString(R.string.search_demo_products))
            search.search("").demoProducts.forEach { out += Row.Item(it) }
        } else {
            val result = search.search(query)
            out += Row.Keyword(query, searchFor = true)
            out += Row.Header(getString(if (result.demoIsFallback) R.string.search_demo_products_none else R.string.search_demo_products))
            result.demoProducts.forEach { out += Row.Item(it) }
            out += Row.Header(getString(R.string.search_other_results))
            if (result.otherProducts.isEmpty()) out += Row.Empty(getString(R.string.search_no_other_results))
            result.otherProducts.forEach { out += Row.Item(it) }
        }
        rows.submit(out)
    }

    private fun openResults(query: String) = startActivity(ResultsActivity.forQuery(this, query))

    private sealed class Row {
        data class Header(val text: String) : Row()
        data class Keyword(val text: String, val searchFor: Boolean = false) : Row()
        data class Item(val product: Product) : Row()
        data class Empty(val text: String) : Row()
    }

    private inner class RowAdapter : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        private var items: List<Row> = emptyList()
        private val products = ProductAdapter { startActivity(ProductDetailActivity.intent(this@SearchActivity, it.productId)) }
            .apply { list = true }

        @SuppressLint("NotifyDataSetChanged")
        fun submit(rows: List<Row>) {
            items = rows
            notifyDataSetChanged()
        }

        override fun getItemCount() = items.size

        override fun getItemViewType(position: Int) = when (items[position]) {
            is Row.Header -> TYPE_HEADER
            is Row.Keyword -> TYPE_KEYWORD
            is Row.Item -> TYPE_PRODUCT
            is Row.Empty -> TYPE_EMPTY
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
            val inflater = LayoutInflater.from(parent.context)
            return when (viewType) {
                TYPE_PRODUCT -> products.onCreateViewHolder(parent, R.layout.item_product_list)
                TYPE_HEADER -> PlainHolder(inflater.inflate(R.layout.item_section_header, parent, false))
                TYPE_EMPTY -> PlainHolder(inflater.inflate(R.layout.item_empty, parent, false))
                else -> PlainHolder(inflater.inflate(R.layout.item_keyword, parent, false))
            }
        }

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            when (val row = items[position]) {
                is Row.Header -> (holder.itemView as TextView).text = row.text
                is Row.Empty -> (holder.itemView as TextView).text = row.text
                is Row.Keyword -> (holder.itemView as TextView).apply {
                    text = if (row.searchFor) getString(R.string.search_for, row.text) else row.text
                    setOnClickListener { openResults(row.text) }
                }
                is Row.Item -> (holder as ProductAdapter.Holder).bind(row.product)
            }
        }
    }

    private class PlainHolder(view: android.view.View) : RecyclerView.ViewHolder(view)

    companion object {
        private const val TYPE_HEADER = 0
        private const val TYPE_KEYWORD = 1
        private const val TYPE_PRODUCT = 2
        private const val TYPE_EMPTY = 3

        fun intent(context: Context) = Intent(context, SearchActivity::class.java)
    }
}
