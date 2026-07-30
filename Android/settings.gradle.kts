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

// local.properties 는 커밋되지 않는다(.gitignore) — 자격증명·데모 키를 여기에 둔다.
// 우선순위: local.properties → gradle.properties → 환경변수.
val localProps = Properties().apply {
    val file = File(rootDir, "local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun secret(key: String, env: String): String? =
    localProps.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty(key).orNull?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()

        // ── Shoplive 사설 Maven ──────────────────────────────────────────────
        // SDK AAR 이 여기에서 내려온다.
        //
        // 예전 안내(프로젝트 루트 build.gradle 의 `allprojects { repositories { ... } }`)도
        // 동작하지만, 신규 프로젝트는 이 블록이 표준 위치다. 위 FAIL_ON_PROJECT_REPOS
        // 때문에 모듈 build.gradle 에서 저장소를 따로 선언하면 빌드가 실패한다.
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
include(":app")
