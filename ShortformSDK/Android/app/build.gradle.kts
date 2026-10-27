import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Local demo values. Read from local.properties (git-ignored), then -P / environment.
// Empty is fine: the app falls back to the bundled sample catalog and asks for a key.
val localProps = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun demoValue(key: String, env: String): String =
    localProps.getProperty(key)?.trim()?.takeIf { it.isNotEmpty() }
        ?: providers.gradleProperty(key).orNull?.trim()?.takeIf { it.isNotEmpty() }
        ?: System.getenv(env)?.trim()?.takeIf { it.isNotEmpty() }
        ?: ""

fun String.asBuildConfigString(): String =
    "\"" + replace("\\", "\\\\").replace("\"", "\\\"") + "\""

// The sample catalog lives once, in ShortformSDK/demo-config. It is copied into the
// app's assets at build time instead of being duplicated in this module.
val sampleCatalog = rootProject.file("../demo-config/catalog.sample.json")

abstract class CopySampleCatalog : DefaultTask() {
    @get:InputFile
    abstract val source: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun copy() {
        val out = outputDir.get().asFile
        out.deleteRecursively()
        out.mkdirs()
        source.get().asFile.copyTo(out.resolve("catalog.sample.json"), overwrite = true)
    }
}

val copySampleCatalog = tasks.register<CopySampleCatalog>("copySampleCatalog") {
    source.set(sampleCatalog)
    outputDir.set(layout.buildDirectory.dir("generated/sampleCatalog"))
}

android {
    namespace = "cloud.shoplive.demo.shortform"
    compileSdk = 36

    defaultConfig {
        applicationId = "cloud.shoplive.demo.shortform"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "DEMO_ACCESS_KEY", demoValue("shortform.demo.accessKey", "SHORTFORM_DEMO_ACCESS_KEY").asBuildConfigString())
        buildConfigField("String", "DEMO_CATALOG_URL", demoValue("shortform.demo.catalogUrl", "SHORTFORM_DEMO_CATALOG_URL").asBuildConfigString())
        buildConfigField("String", "SHORTFORM_SDK_VERSION", libs.versions.shortform.get().asBuildConfigString())
    }

    buildTypes {
        release {
            // A demo: signed with the debug key. Use your own signing config.
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    lint {
        // Reported for a Glide class the app never uses (NotificationTarget); not app code.
        disable += "NotificationPermission"
    }

    testOptions {
        unitTests.all {
            // Unit tests parse the very same sample catalog that ships in the app.
            it.systemProperty("demo.sampleCatalog", sampleCatalog.absolutePath)
        }
    }
}

androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addGeneratedSourceDirectory(copySampleCatalog, CopySampleCatalog::outputDir)
    }
}

dependencies {
    // ── Shortform SDK 1.9.1 ───────────────────────────────────────────────────
    // The shortform artifact does not pull in the cloud.shoplive modules it needs,
    // so declare common, network and the player engine next to it.
    implementation(libs.shoplive.shortform)
    implementation(libs.shoplive.common)
    implementation(libs.shoplive.network)
    implementation(libs.shoplive.media3)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.recyclerview)
    implementation(libs.androidx.viewpager2)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.material)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.gson)
    implementation(libs.glide)

    testImplementation(libs.junit)
}
