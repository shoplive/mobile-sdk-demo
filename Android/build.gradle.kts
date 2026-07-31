// Plugin versions are resolved once here so the modules can apply them without a
// version. Local SDK modules (Groovy) also resolve AGP/Kotlin from this classpath.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.kapt) apply false
    alias(libs.plugins.kotlin.parcelize) apply false
}

// Ext values matrix-sdk-android library build.gradle files read from rootProject
// (originally set in that repo's root build.gradle buildscript { ext { ... } }).
extra.apply {
    set("kotlin_version", libs.versions.kotlin.get())
    set("core_ktx_version", "1.12.0")
    set("activity_ktx_version", "1.7.2")
    set("android_appcompat_version", "1.6.1")
    set("android_material_version", "1.9.0")
    set("lifecycle_extensions_version", "2.2.0")
    set("lifecycle_runtime_ktx_version", "2.5.1")
    set("glide_version", "4.14.2")
    set("gson_version", "2.8.9")
    set("coroutines_version", "1.7.3")
    set("play_services_ads_identifier", "17.0.1")
    set("okhttp3_version", "4.9.3")
    set("stetho_version", "1.6.0")
    set("leak_canary", "2.14")
    set("okhttp_profiler_version", "1.0.8")
    set("shoplive_sdk_version", "3.0.0")
    set("shoplive_exoplayer_version", "10")

    // publish tasks reference these — empty for local source builds.
    set("artifactoryUsername", "")
    set("artifactoryPassword", "")
    set("privateMavenUrl", "https://repo.us1.shoplive.cloud/repository/shoplive/")
}
