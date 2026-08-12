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

// local.properties is not committed (.gitignore) — put the demo keys and the local
// SDK path there. Precedence: local.properties -> gradle.properties -> environment.
// Nothing here is a credential: the SDK repository below is public.
val localProps = Properties().apply {
    val file = File(rootDir, "local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun setting(key: String, env: String): String? =
    localProps.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty(key).orNull?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }

// ── Building against local SDK sources (composite build) ────────────────────
// SDK developers only. Wires matrix-sdk-android in from a local path; the three
// coordinates below are substituted with local projects instead of the published
// AAR, so the dependency declarations in the module build files stay unchanged.
//   - turn it on:      shoplive.sdk.useLocal=true
//   - different path:  shoplive.sdk.localPath=/absolute/or/relative/path
// Off by default: the demo builds from the public distribution channel below, the
// same way a customer app does. A missing path falls back to the AAR anyway.
val useLocalSdk = (setting("shoplive.sdk.useLocal", "SHOPLIVE_SDK_USE_LOCAL") ?: "false").toBoolean()
val localSdkDir = File(
    setting("shoplive.sdk.localPath", "SHOPLIVE_SDK_LOCAL_PATH") ?: "../matrix-sdk-android"
).let { if (it.isAbsolute) it else File(rootDir, it.path) }.canonicalFile

if (useLocalSdk && File(localSdkDir, "settings.gradle").exists()) {
    includeBuild(localSdkDir) {
        dependencySubstitution {
            substitute(module("cloud.shoplive:shoplive-player-sdk"))
                .using(project(":shoplive-player-sdk"))
            substitute(module("cloud.shoplive:shoplive-streamer-sdk"))
                .using(project(":shoplive-streamer-sdk"))
            // The shared public surface. Declared by :integration, so it needs a
            // substitution too or the local build resolves it from Maven.
            substitute(module("cloud.shoplive:shoplive-core"))
                .using(project(":shoplive-core"))
        }
    }
    logger.lifecycle("[shoplive] using local SDK sources: $localSdkDir")
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()

        // ── Shoplive SDK distribution channel ────────────────────────────────
        // The `maven-repo` branch of https://github.com/shoplive/shoplive-sdk-android,
        // served as a static Maven repository over raw.githubusercontent.com. The repo
        // is public, so there is no `credentials { }` block here and nothing to
        // request — this is the whole setup.
        //
        // The older advice (`allprojects { repositories { ... } }` in the root
        // build.gradle) still works, but for a new project this block is the standard
        // place. Because of FAIL_ON_PROJECT_REPOS above, declaring a repository in a
        // module's build file fails the build.
        maven {
            name = "shoplive"
            url = uri("https://raw.githubusercontent.com/shoplive/shoplive-sdk-android/maven-repo")

            // Only cloud.shoplive lives here. Without this filter every artifact that
            // misses google()/mavenCentral() would also be looked up against GitHub.
            content { includeGroup("cloud.shoplive") }
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
