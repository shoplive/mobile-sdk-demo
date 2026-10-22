package cloud.shoplive.demo.shortform.ui.settings

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.Toast
import androidx.lifecycle.lifecycleScope
import cloud.shoplive.demo.shortform.BuildConfig
import cloud.shoplive.demo.shortform.R
import cloud.shoplive.demo.shortform.catalog.CatalogRepository
import cloud.shoplive.demo.shortform.data.BrandColor
import cloud.shoplive.demo.shortform.databinding.ActivitySettingsBinding
import cloud.shoplive.demo.shortform.shortform.EventLog
import cloud.shoplive.demo.shortform.shortform.ShortformAvailability
import cloud.shoplive.demo.shortform.shortform.ShortformSdk
import cloud.shoplive.demo.shortform.ui.BaseActivity
import cloud.shoplive.demo.shortform.ui.applyInsets
import cloud.shoplive.demo.shortform.ui.home.HomeActivity
import com.google.android.material.chip.Chip
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kotlinx.coroutines.launch

/**
 * Settings: access key, catalog URL, brand color, layout defaults reset, SDK event log and a
 * full demo reset. Values saved here override local.properties.
 */
class SettingsActivity : BaseActivity() {

    private lateinit var binding: ActivitySettingsBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setUpTopBar(binding.appBar, binding.toolbar, getString(R.string.settings_title), showSettings = false)
        binding.scroll.applyInsets(bottom = true, ime = true)

        val settings = graph.settings
        binding.accessKeyInput.setText(settings.accessKey)
        binding.accessKeyLayout.helperText = getString(
            if (settings.accessKeyIsOverridden) R.string.settings_value_from_settings else R.string.settings_value_from_build,
        )
        binding.catalogUrlInput.setText(settings.catalogUrl)
        binding.catalogUrlLayout.helperText = getString(
            if (settings.catalogUrlIsOverridden) R.string.settings_value_from_settings else R.string.settings_catalog_url_help,
        )
        graph.catalogRepository.current?.let { showCatalogStatus(it) }

        binding.saveButton.setOnClickListener { saveAndReload() }
        setUpBrandColors()
        binding.resetLayoutButton.setOnClickListener {
            graph.options.reset()
            Toast.makeText(this, R.string.settings_reset_layout_done, Toast.LENGTH_SHORT).show()
        }
        binding.eventLogButton.setOnClickListener { startActivity(EventLogActivity.intent(this)) }
        binding.sdkVersion.text = getString(R.string.settings_sdk_version, BuildConfig.SHORTFORM_SDK_VERSION)
        binding.demoResetButton.setOnClickListener { confirmDemoReset() }
    }

    private fun saveAndReload() {
        val key = binding.accessKeyInput.text?.toString()?.trim().orEmpty()
        val url = binding.catalogUrlInput.text?.toString()?.trim().orEmpty()
        val settings = graph.settings
        // Saving the build-time value again is not an override.
        settings.setAccessKey(key.takeIf { it != BuildConfig.DEMO_ACCESS_KEY.trim() })
        settings.setCatalogUrl(url.takeIf { it != BuildConfig.DEMO_CATALOG_URL.trim() })
        ShortformSdk.applyAccessKey(settings.accessKey)
        ShortformAvailability.clear()

        binding.saveButton.isEnabled = false
        binding.catalogStatus.setText(R.string.settings_catalog_loading)
        lifecycleScope.launch {
            val loaded = graph.catalogRepository.reload()
            binding.saveButton.isEnabled = true
            showCatalogStatus(loaded)
            Toast.makeText(this@SettingsActivity, R.string.settings_saved, Toast.LENGTH_SHORT).show()
        }
    }

    private fun showCatalogStatus(loaded: CatalogRepository.Loaded) {
        val source = getString(
            when (loaded.source) {
                CatalogRepository.Source.REMOTE -> R.string.settings_catalog_source_remote
                CatalogRepository.Source.CACHE -> R.string.settings_catalog_source_cache
                CatalogRepository.Source.BUNDLED -> R.string.settings_catalog_source_bundled
            },
        )
        val base = getString(R.string.settings_catalog_status, source, loaded.catalog.products.size)
        binding.catalogStatus.text = loaded.remoteError?.let { base + "\n" + getString(R.string.settings_catalog_error, it) } ?: base
    }

    private fun setUpBrandColors() {
        val labels = mapOf(
            BrandColor.DEFAULT to R.string.settings_brand_default,
            BrandColor.BLUE to R.string.settings_brand_blue,
            BrandColor.GREEN to R.string.settings_brand_green,
            BrandColor.ORANGE to R.string.settings_brand_orange,
            BrandColor.PINK to R.string.settings_brand_pink,
        )
        val current = graph.settings.brandColor
        BrandColor.values().forEach { color ->
            val chip = LayoutInflater.from(this).inflate(R.layout.chip_choice, binding.brandColors, false) as Chip
            chip.id = View.generateViewId()
            chip.setText(labels.getValue(color))
            chip.isChecked = color == current
            chip.setOnClickListener {
                if (graph.settings.brandColor != color) {
                    graph.settings.brandColor = color
                    recreate()
                }
            }
            binding.brandColors.addView(chip)
        }
    }

    private fun confirmDemoReset() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.settings_demo_reset)
            .setMessage(R.string.settings_demo_reset_message)
            .setNegativeButton(R.string.common_cancel, null)
            .setPositiveButton(R.string.settings_demo_reset_confirm) { _, _ ->
                graph.settings.clear()
                graph.catalogRepository.clearCache()
                ShortformAvailability.clear()
                EventLog.clear()
                ShortformSdk.hidePreview()
                ShortformSdk.applyAccessKey(graph.settings.accessKey)
                startActivity(
                    Intent(this, HomeActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK),
                )
            }
            .show()
    }

    companion object {
        fun intent(context: Context) = Intent(context, SettingsActivity::class.java)
    }
}
