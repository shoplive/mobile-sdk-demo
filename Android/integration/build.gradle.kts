plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

// ─────────────────────────────────────────────────────────────────────────────
// The copy-paste module.
//
// Every file in this module is meant to be copied into a customer app as-is.
// That is only true if it compiles with NOTHING but the Shoplive SDK on the
// classpath, so this module deliberately has no dependency on `:app`.
//
// Gradle enforces the boundary: dependencies flow `:app -> :integration` only.
// If someone reaches back into the demo harness (EventLog, DemoOptions,
// R.string, BuildConfig, ...) this module stops compiling — which is exactly
// what a customer would experience after copying the files out.
//
// Deliberately NOT enabled here:
//   - buildConfig  -> BuildConfig would exist and could be referenced
//   - compose      -> customer apps may be XML/View based
//   - res/         -> customer apps have their own resource IDs
// ─────────────────────────────────────────────────────────────────────────────

android {
    namespace = "cloud.shoplive.onboarding.integration"
    compileSdk = 35

    defaultConfig {
        // The documented SDK floor is player 19 / streamer 21, but that is not the
        // number a customer app can actually ship: shoplive-android-webrtc, pulled in
        // transitively, declares minSdk 23, and an app below that fails manifest
        // merging with "minSdkVersion 21 cannot be smaller than version 23 declared in
        // library [org.webrtc]". Measured 2026-07-30 against the local SDK sources by
        // compiling an empty app with only the SDK plus these files.
        minSdk = 23

        // Only relevant when the local SDK sources are wired in through the
        // composite build (see settings.gradle.kts). The SDK library modules
        // carry a "distribution" flavour dimension; this module has none, so
        // variant matching needs a target. Harmless when consuming the AAR.
        missingDimensionStrategy("distribution", "develop")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    buildFeatures {
        buildConfig = false
    }
}

dependencies {
    // The Shoplive SDK, and nothing that belongs to the demo.
    // `api` because the public surface of this module hands SDK types back to
    // the caller (configurations, delegates, player handles).
    api(libs.shoplive.player.sdk)
    api(libs.shoplive.streamer.sdk)

    // Shoplive, ShopliveUser, ShopliveConfiguration and ShopliveError live here, and
    // neither SDK module exposes it transitively — see the note in
    // gradle/libs.versions.toml. A customer app copying these files needs this line.
    api(libs.shoplive.core)

    // LifecycleOwner only, for ShoplivePlayerView.bindLifecycle(...) in
    // ShopliveEmbeddedPlayer.kt. Any app that hosts an Activity already has it.
    implementation(libs.androidx.lifecycle.runtime.ktx)
}

// ── Boundary scanner ────────────────────────────────────────────────────────
// The compiler catches hard dependencies (R, BuildConfig, demo classes). It does
// NOT catch things that compile fine yet still hurt a customer: android.util.Log,
// Timber, DI annotations, @Composable, non-English comments. The scanner does.
// Wired into `check` so it runs in CI with the rest of the build.
val checkIntegrationBoundary by tasks.registering(Exec::class) {
    group = "verification"
    description = "Fails if the copy-paste sources depend on the demo harness."
    workingDir = rootProject.projectDir
    commandLine("python3", "scripts/integration_boundary_scanner.py")
}

tasks.named("check") {
    dependsOn(checkIntegrationBoundary)
}
