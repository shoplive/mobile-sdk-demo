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

// Shoplive SDK repository. It is public, so there is no `credentials { }` block
// and nothing to request.
dependencyResolutionManagement {
    repositories {
        google()
        // Before mavenCentral(): repositories are searched in order, and some
        // cloud.shoplive artifacts (e.g. shoplive-media3) also exist on Central.
        maven {
            url = uri("https://sdk.shoplive.cloud/maven-repo")
            // Only cloud.shoplive lives here. Without this, every dependency that
            // misses google() would be looked up against this server first.
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
