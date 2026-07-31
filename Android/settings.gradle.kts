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

// ── Building against local SDK sources (composite build) ────────────────────
// Wires matrix-sdk-android in from a local path. The two coordinates below are
// substituted with local projects instead of the private Maven AAR, so the
// dependency declarations in the module build files stay unchanged.
//   - different path:  shoplive.sdk.localPath=/absolute/or/relative/path
//   - turn it off:     shoplive.sdk.useLocal=false  -> back to the Maven AAR
// A missing path falls back to the Maven AAR automatically.
val useLocalSdk = (secret("shoplive.sdk.useLocal", "SHOPLIVE_SDK_USE_LOCAL") ?: "true").toBoolean()
val localSdkDir = File(
    secret("shoplive.sdk.localPath", "SHOPLIVE_SDK_LOCAL_PATH") ?: "../matrix-sdk-android"
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

        // ── Shoplive private Maven ───────────────────────────────────────────
        // Where the SDK AAR comes from.
        //
        // The older advice (`allprojects { repositories { ... } }` in the root
        // build.gradle) still works, but for a new project this block is the standard
        // place. Because of FAIL_ON_PROJECT_REPOS above, declaring a repository in a
        // module's build file fails the build.
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
