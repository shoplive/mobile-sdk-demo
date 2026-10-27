package cloud.shoplive.demo.shortform.ui.settings

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.format.DateFormat
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.databinding.ActivityEventLogBinding
import cloud.shoplive.demo.shortform.shortform.EventLog
import cloud.shoplive.demo.shortform.ui.BaseActivity
import cloud.shoplive.demo.shortform.ui.applyInsets
import com.google.android.material.appbar.MaterialToolbar

/** Settings → SDK event log: the Shortform SDK callbacks received in this session, newest first. */
class EventLogActivity : BaseActivity() {

    private lateinit var binding: ActivityEventLogBinding
    private val adapter = EventAdapter()
    private val onChange: () -> Unit = { runOnUiThread { refresh() } }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityEventLogBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setUpTopBar(binding.appBar, binding.toolbar, getString(R.string.settings_event_log))
        binding.list.applyInsets(bottom = true)
        binding.list.layoutManager = LinearLayoutManager(this)
        binding.list.adapter = adapter
    }

    override fun onCreateTopBarMenu(toolbar: MaterialToolbar) {
        toolbar.inflateMenu(R.menu.menu_event_log)
    }

    override fun onTopBarItem(item: MenuItem): Boolean {
        if (item.itemId != R.id.action_clear_log) return false
        EventLog.clear()
        return true
    }

    override fun onStart() {
        super.onStart()
        EventLog.addListener(onChange)
        refresh()
    }

    override fun onStop() {
        super.onStop()
        EventLog.removeListener(onChange)
    }

    private fun refresh() {
        val entries = EventLog.all()
        adapter.submit(entries)
        binding.emptyText.isVisible = entries.isEmpty()
    }

    private class EventAdapter : RecyclerView.Adapter<EventAdapter.Holder>() {
        private var items: List<EventLog.Entry> = emptyList()

        @SuppressLint("NotifyDataSetChanged")
        fun submit(entries: List<EventLog.Entry>) {
            items = entries
            notifyDataSetChanged()
        }

        class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val name: TextView = view.findViewById(R.id.eventName)
            val detail: TextView = view.findViewById(R.id.eventDetail)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            Holder(LayoutInflater.from(parent.context).inflate(R.layout.item_event, parent, false))

        override fun getItemCount() = items.size

        override fun onBindViewHolder(holder: Holder, position: Int) {
            val e = items[position]
            val time = DateFormat.format("HH:mm:ss", e.timeMillis)
            holder.name.text = holder.itemView.context.getString(R.string.settings_event_log_entry, time, e.name)
            holder.detail.text = e.detail
            holder.detail.isVisible = e.detail.isNotEmpty()
        }
    }

    companion object {
        fun intent(context: Context) = Intent(context, EventLogActivity::class.java)
    }
}
