pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "nyamnyam"

// ADR-05: :app :wear :core :feature:{member,meal,workout,coaching,growth}, 아키텍처 테스트 전용 :konsist-test
include(
    ":app",
    ":wear",
    ":core",
    ":feature:member",
    ":feature:meal",
    ":feature:workout",
    ":feature:coaching",
    ":feature:growth",
    ":konsist-test",
)
