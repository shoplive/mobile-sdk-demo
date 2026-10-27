package cloud.shoplive.demo.shortform

import android.app.Application
import android.content.Context
import cloud.shoplive.demo.shortform.catalog.CatalogRepository
import cloud.shoplive.demo.shortform.data.DemoSettings
import cloud.shoplive.demo.shortform.data.OptionStore
import cloud.shoplive.demo.shortform.data.SharedPreferencesStore
import cloud.shoplive.demo.shortform.shortform.ShortformSdk

class DemoApp : Application() {

    /** The app's few long-lived objects. */
    class Graph(context: Context) {
        private val store = SharedPreferencesStore(context.getSharedPreferences("shortform_demo", Context.MODE_PRIVATE))
        val settings = DemoSettings(store, BuildConfig.DEMO_ACCESS_KEY, BuildConfig.DEMO_CATALOG_URL)
        val options = OptionStore(store)
        val catalogRepository = CatalogRepository(context) { settings.catalogUrl }
    }

    lateinit var graph: Graph
        private set

    override fun onCreate() {
        super.onCreate()
        graph = Graph(this)
        ShortformSdk.applyAccessKey(graph.settings.accessKey)
    }

    companion object {
        fun graph(context: Context): Graph = (context.applicationContext as DemoApp).graph
    }
}
