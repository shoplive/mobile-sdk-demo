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

// Build against a Shortform SDK installed in ~/.m2 instead of the public repository:
//   ./gradlew :app:assembleDebug -PuseMavenLocal=true
// Off by default, so a fresh clone and CI always resolve the SDK from sdk.shoplive.cloud.
val useMavenLocal = providers.gradleProperty("useMavenLocal").orNull == "true"

// The modules that make up Shortform SDK 1.9.1 in an app. The shortform POM does not
// list the cloud.shoplive modules it needs, so the app declares all four.
val shortformModule = "shoplive-short-form"
val sharedShopliveModules = listOf("shoplive-common", "shoplive-network", "shoplive-media3")

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        if (useMavenLocal) {
            exclusiveContent {
                forRepository { mavenLocal() }
                filter { includeModule("cloud.shoplive", shortformModule) }
            }
        }
        // The Shoplive SDK repository is public: no credentials block.
        // exclusiveContent pins cloud.shoplive to this server, so a same-named
        // artifact on another repository can never be picked up instead.
        exclusiveContent {
            forRepository {
                maven {
                    name = "shopliveSdkRepo"
                    url = uri("https://sdk.shoplive.cloud/maven-repo")
                }
            }
            filter {
                sharedShopliveModules.forEach { includeModule("cloud.shoplive", it) }
                if (!useMavenLocal) includeModule("cloud.shoplive", shortformModule)
            }
        }
        google()
        mavenCentral()
    }
}

rootProject.name = "ShortformCommerceDemo"
include(":app")
