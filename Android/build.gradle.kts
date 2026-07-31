// Plugin versions are resolved once here so the modules can apply them without a
// version. The local SDK composite build already puts AGP on the classpath, and a
// module asking for a specific version again fails resolution.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
