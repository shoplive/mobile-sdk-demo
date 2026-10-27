package cloud.shoplive.demo.shortform.catalog

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Loads the catalog: catalog URL → last good copy on the device → bundled sample.
 * A downloaded catalog is cached only after it parses, so a broken upload never replaces a
 * working copy.
 */
class CatalogRepository(
    context: Context,
    private val catalogUrl: () -> String,
) {
    enum class Source { REMOTE, CACHE, BUNDLED }

    data class Loaded(val catalog: Catalog, val source: Source, val remoteError: String? = null)

    private val appContext = context.applicationContext
    private val cacheDir = File(appContext.filesDir, "catalog")
    private val cacheFile = File(cacheDir, "last-good.json")
    private val cacheUrlFile = File(cacheDir, "last-good.url")
    private val mutex = Mutex()

    @Volatile
    var current: Loaded? = null
        private set

    suspend fun get(): Loaded = current ?: reload()

    suspend fun reload(): Loaded = mutex.withLock {
        withContext(Dispatchers.IO) {
            val url = catalogUrl().trim()
            var remoteError: String? = null
            if (url.isNotEmpty()) {
                try {
                    val text = download(url)
                    val catalog = CatalogParser.parse(text)
                    writeCache(url, text)
                    return@withContext Loaded(catalog, Source.REMOTE).also { current = it }
                } catch (e: Exception) {
                    remoteError = e.message ?: e.javaClass.simpleName
                }
                readCache(url)?.let { return@withContext Loaded(it, Source.CACHE, remoteError).also { l -> current = l } }
            }
            Loaded(readBundled(), Source.BUNDLED, remoteError).also { current = it }
        }
    }

    /** Settings → Demo reset. */
    fun clearCache() {
        cacheFile.delete()
        cacheUrlFile.delete()
        current = null
    }

    private fun download(url: String): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        connection.setRequestProperty("Accept", "application/json")
        try {
            val code = connection.responseCode
            if (code !in 200..299) throw IllegalStateException("HTTP $code")
            return connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun writeCache(url: String, text: String) {
        cacheDir.mkdirs()
        val tmp = File(cacheDir, "last-good.json.tmp")
        tmp.writeText(text, Charsets.UTF_8)
        tmp.renameTo(cacheFile)
        cacheUrlFile.writeText(url, Charsets.UTF_8)
    }

    /** The cached copy, only when it came from the same catalog URL. */
    private fun readCache(url: String): Catalog? = try {
        if (cacheFile.exists() && cacheUrlFile.exists() && cacheUrlFile.readText(Charsets.UTF_8) == url) {
            CatalogParser.parse(cacheFile.readText(Charsets.UTF_8))
        } else {
            null
        }
    } catch (e: Exception) {
        null
    }

    private fun readBundled(): Catalog =
        appContext.assets.open(BUNDLED_ASSET).bufferedReader(Charsets.UTF_8).use { CatalogParser.parse(it.readText()) }

    companion object {
        /** Copied from ShortformSDK/demo-config at build time (app/build.gradle.kts). */
        const val BUNDLED_ASSET = "catalog.sample.json"
        private const val TIMEOUT_MS = 8_000
    }
}
