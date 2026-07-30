import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// Demo keys for tour mode. Read from local.properties (never committed), then the
// environment, and finally left blank — which locks "look around" in the app.
val localProps = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun demoKey(key: String, env: String): String =
    localProps.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty(key).orNull?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }
        ?: ""

android {
    namespace = "cloud.shoplive.onboarding"
    compileSdk = 35

    defaultConfig {
        // A separate id so this can sit alongside the SDK demo app (cloud.shoplive.demo)
        // on one device.
        applicationId = "cloud.shoplive.onboarding"

        // The SDK requires player 19 / streamer 21. This demo uses Compose and
        // EncryptedSharedPreferences, hence 24 — a customer app can go down to 21, and
        // :integration does (see integration/build.gradle.kts).
        minSdk = 24
        targetSdk = 35

        versionCode = 1
        versionName = "3.0.0"

        // Only relevant when the local SDK sources are wired in (composite build). The
        // SDK library modules have a "distribution" flavour dimension
        // (develop/qa/qaUs/ebay) and this app has none, so variant matching needs a
        // target. Harmless when consuming the AAR.
        missingDimensionStrategy("distribution", "develop")

        buildConfigField("String", "DEMO_ACCESS_KEY", "\"${demoKey("shoplive.demo.accessKey", "SHOPLIVE_DEMO_ACCESS_KEY")}\"")
        buildConfigField("String", "DEMO_CAMPAIGN_KEY", "\"${demoKey("shoplive.demo.campaignKey", "SHOPLIVE_DEMO_CAMPAIGN_KEY")}\"")
        buildConfigField("String", "DEMO_STREAM_TOKEN", "\"${demoKey("shoplive.demo.streamToken", "SHOPLIVE_DEMO_STREAM_TOKEN")}\"")

        // Mission 2 — the deep-link scheme. One value shared with the manifest's
        // intent-filter, and passed into ShopliveDeepLinkRouter as a parameter.
        val scheme = "shoplivedemo"
        manifestPlaceholders["deepLinkScheme"] = scheme
        buildConfigField("String", "DEEP_LINK_SCHEME", "\"$scheme\"")
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            // A demo, so it is signed with the debug key. Use your own signing config.
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += setOf(
            "/META-INF/{AL2.0,LGPL2.1}",
            "/META-INF/DEPENDENCIES",
        )
    }
}

dependencies {
    // ── The copy-paste layer ────────────────────────────────────────────────
    // Every Shoplive call the demo makes goes through here. The dependency points
    // one way only: :integration knows nothing about this module, which is what
    // keeps it copyable. It exposes the SDK with `api`, so the two `implementation`
    // lines below are only for the app's own direct use of SDK types.
    implementation(project(":integration"))

    // ── Shoplive unified SDK v3 ─────────────────────────────────────────────
    // Watching only: keep the first line. Broadcasting only: the second. Both: both.
    // core / exoplayer / webrtc / android-webrtc are internal dependencies you do not
    // declare, and the overlap between the two artifacts is resolved by the SDK.
    implementation(libs.shoplive.player.sdk)
    implementation(libs.shoplive.streamer.sdk)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.security.crypto)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

    debugImplementation(libs.androidx.compose.ui.tooling)
}
