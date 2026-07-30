import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// 둘러보기 모드에 쓰는 데모 키. 커밋되지 않는 local.properties 에서 읽고,
// 없으면 환경변수, 그것도 없으면 빈 값(앱에서 "둘러보기" 잠금)으로 둔다.
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
        // SDK 데모앱(cloud.shoplive.demo)과 한 기기에 함께 설치할 수 있도록 별도 id 를 쓴다.
        applicationId = "cloud.shoplive.onboarding"

        // SDK 요구 최소 버전은 player 19 / streamer 21 이다. 이 데모앱은 Compose·
        // EncryptedSharedPreferences 를 쓰므로 24 로 올려 둔다 — 고객사 앱은 21 까지 내려도 된다.
        minSdk = 24
        targetSdk = 35

        versionCode = 1
        versionName = "3.0.0"

        buildConfigField("String", "DEMO_ACCESS_KEY", "\"${demoKey("shoplive.demo.accessKey", "SHOPLIVE_DEMO_ACCESS_KEY")}\"")
        buildConfigField("String", "DEMO_CAMPAIGN_KEY", "\"${demoKey("shoplive.demo.campaignKey", "SHOPLIVE_DEMO_CAMPAIGN_KEY")}\"")
        buildConfigField("String", "DEMO_STREAM_TOKEN", "\"${demoKey("shoplive.demo.streamToken", "SHOPLIVE_DEMO_STREAM_TOKEN")}\"")

        // Mission 2 — 딥링크 스킴. AndroidManifest 의 intent-filter 와 한 값을 공유한다.
        val scheme = "shoplivedemo"
        manifestPlaceholders["deepLinkScheme"] = scheme
        buildConfigField("String", "DEEP_LINK_SCHEME", "\"$scheme\"")
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            // 데모앱이라 서명은 debug 키로 둔다. 고객사 앱은 자체 서명 설정을 쓰세요.
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
    // ── Shoplive 통합 SDK v3 ────────────────────────────────────────────────
    // 시청(Player)만 쓸 거면 첫 줄만, 송출(Streamer)만 쓸 거면 둘째 줄만 남기면 된다.
    // core / exoplayer / webrtc / android-webrtc 는 내부 의존이라 선언하지 않아도 되고,
    // 둘을 함께 쓸 때 겹치는 의존성도 SDK 쪽에서 정리된다.
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
