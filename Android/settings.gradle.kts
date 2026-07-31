import java.util.Properties

pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

// local.properties is not committed (.gitignore) — put credentials and demo keys
// there. Precedence: local.properties -> gradle.properties -> environment.
val localProps = Properties().apply {
    val file = File(rootDir, "local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun secret(key: String, env: String): String? =
    localProps.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty(key).orNull?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }

// matrix-sdk-android dev mode: when `make` has created the root symlink, include
// the international line modules in this project. Otherwise use customer AARs.
val sdkLineRoot = file("matrix-sdk-android/lines/international")
val localSdkAttached = File(sdkLineRoot, "shoplive-player-sdk").isDirectory

dependencyResolutionManagement {
    // Local SDK modules declare their own repositories → PREFER_SETTINGS in
    // dev mode. Keep FAIL_ON_PROJECT_REPOS for the customer (AAR) path.
    repositoriesMode.set(
        if (localSdkAttached) RepositoriesMode.PREFER_SETTINGS
        else RepositoriesMode.FAIL_ON_PROJECT_REPOS
    )

    repositories {
        google()

        // ── Shoplive private Maven ───────────────────────────────────────────
        // Where the SDK AAR comes from (customer mode). Kept in local-SDK mode
        // for any remaining transitive coordinates.
        maven {
            name = "shoplive"
            url = uri(
                secret("shoplive.maven.url", "SHOPLIVE_MAVEN_URL")
                    ?: "https://repo.us1.shoplive.cloud/repository/shoplive/"
            )
            credentials {
                username = secret("shoplive.maven.username", "SHOPLIVE_MAVEN_USERNAME")
                password = secret("shoplive.maven.password", "SHOPLIVE_MAVEN_PASSWORD")
            }
        }

        mavenCentral()
    }
}

rootProject.name = "ShopliveOnboardingDemo"

// :integration is the copy-paste layer — SDK calls only, no demo dependencies.
// It is a separate module so the boundary is enforced by the build graph:
// :app depends on :integration, never the other way round. Building
// :integration alone reproduces the customer's situation (SDK only, no harness).
include(":app", ":integration")

if (localSdkAttached) {
    fun includeSdkModule(name: String) {
        include(":$name")
        project(":$name").projectDir = File(sdkLineRoot, name)
    }

    listOf(
        "shoplive-player-sdk",
        "shoplive-streamer-sdk",
        "shoplive-core-player",
        "shoplive-exoplayer",
        "shoplive-core",
        "shoplive-webrtc",
        "shoplive-android-webrtc",
    ).forEach(::includeSdkModule)

    logger.lifecycle("[shoplive] matrix-sdk-android dev mode: $sdkLineRoot")
}
