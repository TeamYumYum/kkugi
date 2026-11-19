plugins {
    kotlin("multiplatform") version "2.2.21"
    kotlin("plugin.compose") version "2.2.21"
    id("org.jetbrains.compose") version "1.9.1"
    id("com.android.library") version "8.13.2"
}

kotlin {
    androidTarget()
    listOf(iosArm64(), iosSimulatorArm64(), iosX64()).forEach { target ->
        target.binaries.framework {
            baseName = "KkugiRenderer"
            isStatic = false
        }
    }
    sourceSets.commonMain.dependencies {
        implementation(compose.runtime)
        implementation(compose.foundation)
        implementation(compose.material3)
        implementation(compose.components.resources)
    }
}

android {
    namespace = "com.kkugi.render"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
}

val prepareArt = tasks.register<Sync>("prepareArt") {
    from("../ios/Kkugi/Resources/Fonts") { include("noto_sans_kr_variable.ttf"); into("font") }
    from("../ios/Kkugi/Resources/Images") { include("kkugi_g_character_f_idle.webp"); into("drawable") }
    into(layout.buildDirectory.dir("sharedArt"))
}

compose.resources {
    packageOfResClass = "com.kkugi.render.resources"
    customDirectory("commonMain", layout.dir(prepareArt.map { it.destinationDir }))
}
dependencies {
    add("testImplementation", "junit:junit:4.13.2")
    add("testImplementation", "org.robolectric:robolectric:4.16.1")
    add("testImplementation", "androidx.compose.ui:ui-test-junit4:1.9.4")
    add("testImplementation", "androidx.compose.ui:ui-test-manifest:1.9.4")
}
android.testOptions.unitTests.isIncludeAndroidResources = true
