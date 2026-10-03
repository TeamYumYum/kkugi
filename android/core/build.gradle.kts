import org.gradle.api.tasks.testing.logging.TestExceptionFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// ADR-05: 단일 :core — 모델·네트워크(Retrofit, ADR-09 생성 DTO)·Room(ADR-03: Workout 테이블만)·디자인 토큰·Data Layer 계약.
// 폰(:app·feature)과 워치(:wear)가 함께 쓰므로 폰 UI 라이브러리(Material 3)는 두지 않는다
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ktlint)
}

android {
    namespace = "com.nyamnyam.core"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        abortOnError = true
    }

    testOptions {
        unitTests.all {
            it.testLogging {
                events("failed")
                exceptionFormat = TestExceptionFormat.FULL
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

ktlint {
    version.set(
        libs.versions.ktlint.cli
            .get(),
    )
}

dependencies {
    // feature가 Retrofit·Room을 직접 쓰는 것은 컨벤션 테스트(viewmodel-repository-only·feature-no-room)가 막는다
    api(libs.retrofit)
    api(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    testImplementation(libs.junit)
}
