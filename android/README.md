# android

냠냠코치 Android 폰 앱과 Wear OS 앱의 Gradle 프로젝트다(ADR-01). 1주차 셸: 모듈 뼈대, Hilt 배선, 내비게이션 자리, 컨벤션
테스트(Konsist)까지 둔다. 도메인 기능은 각 feature 담당이 채운다.

## 모듈 (ADR-05)

| 모듈 | 패키지 | 내용 |
| --- | --- | --- |
| `:app` | `com.nyamnyam` | 폰 진입점. `@HiltAndroidApp`(`NyamApplication`), `MainActivity`, 내비게이션 그래프(`NyamNavHost`), Material 3 테마 자리(`ui/theme`). 화면 조립·내비게이션·DI 루트만 둔다 |
| `:wear` | `com.nyamnyam.wear` | 워치 진입점(minSdk 30). `@HiltAndroidApp`(`NyamWearApplication`), Wear Compose `AppScaffold` + `SwipeDismissableNavHost`(`WearNavHost`). 서버·인증을 모른다(ADR-02) |
| `:core` | `com.nyamnyam.core` | `model/`(순수 모델), `network/`(Retrofit 자리, ADR-09 생성 DTO 자리), `database/`(Room — Workout 세션만, ADR-03), `designsystem/`(색 토큰), `datalayer/`(폰↔워치 Data Layer 경로 상수), `di/`(Hilt 모듈) |
| `:feature:{member,meal,workout,coaching,growth}` | `com.nyamnyam.feature.<이름>` | `ui/`(Screen·Route·ViewModel·UiState) + `data/`(Repository) + `di/`(`@Binds`). `:core`만 의존한다 |
| `:konsist-test` | `com.nyamnyam` | 아키텍처 테스트 전용 JVM 모듈. 테스트 파일은 ai-dev-harness가 관리한다(손으로 고치지 않는다) |

의존 방향: `:app` → 모든 feature + `:core`, `:feature:*` → `:core`, `:wear` → `:core`. feature 사이 의존은 없다.

폰과 워치는 **같은 applicationId(`com.nyamnyam`)** 를 쓴다. Wearable Data Layer(DataClient·MessageClient)는 두 앱의
applicationId와 서명 인증서가 같아야 서로를 찾는다. 두 모듈의 서명 설정(debug·release 키)도 같게 맞춘다.

## 검증 명령 (harness.json, 저장소 루트에서)

```bash
android/gradlew -p android :app:check
android/gradlew -p android :core:check
android/gradlew -p android :wear:check
android/gradlew -p android :feature:member:check :feature:meal:check :feature:workout:check :feature:coaching:check :feature:growth:check
android/gradlew -p android :konsist-test:test
```

`check`는 ktlint(`ktlintCheck`), Android Lint(`abortOnError`, 접근성 검사 오류), 단위 테스트를 함께 돈다. 형식은
`android/gradlew -p android ktlintFormat`으로 맞춘다(`ktlint_official`, `.editorconfig`).

JDK 17 이상(권장 21)과 Android SDK(compileSdk 36)가 필요하다. SDK 경로는 `ANDROID_HOME` 또는 `android/local.properties`의
`sdk.dir`로 준다(`local.properties`는 커밋하지 않는다).

## Android Studio에서 열기

저장소 루트가 아니라 **`android/` 디렉터리**를 연다(File → Open → `android`). Gradle 동기화 뒤 실행 구성에서 `app`(폰 에뮬레이터)
또는 `wear`(Wear OS 에뮬레이터)를 고른다. Gradle JDK는 Settings → Build Tools → Gradle에서 17 이상으로 둔다.

## 화면·Repository 추가 (ai-dev-harness 스캐폴드)

```bash
python <키트>/bin/harness.py scaffold android/feature screen MealSummary --var feature=meal --target .
python <키트>/bin/harness.py scaffold android/feature repository MealLog --var feature=meal --target .
python <키트>/bin/harness.py scaffold android/wear wear-screen HeartRate --target .
android/gradlew -p android ktlintFormat
```

`screen`·`wear-screen`이 출력하는 내비게이션 조각은 `NyamNavHost.kt`·`WearNavHost.kt`의 `nyamnyam:destinations` 표식 위에
붙인다. 1주차 셸의 화면(`<Feature>Home`)·Repository(`<Feature>`)·워치 `WorkoutHome`은 이 스캐폴드로 만들었다. 컨벤션
테스트가 빈 범위로 거짓 통과하지 않게 하는 자리이기도 하므로 feature마다 `ui/`·`data/` 파일을 하나 이상 남겨 둔다.

생성 뒤 `ktlintFormat`을 돌린다. 이름이 `D`보다 앞서는 Repository(예: `Coaching`)는 `di/` 모듈의 import 순서가 어긋나게
생성된다.

## 컨벤션 (ai-dev-harness android-konsist 고정 규칙)

- ViewModel은 Repository만 받는다. Retrofit·Room·DataSource·DAO를 import하지 않는다(ADR-04)
- feature는 Room을 쓰지 않는다. Room은 `:core`의 Workout 테이블만(ADR-03)
- 워치는 Retrofit·OkHttp·Ktor를 import하지 않는다(ADR-02)
- `:app`에 `*Repository`·`*DataSource`·`*Dao`·`*UseCase`를 두지 않는다(ADR-05)
- `*Screen` Composable은 ViewModel을 받지 않는다. `GlobalScope` 금지. UseCase는 ViewModel 2곳 이상이 공유할 때만 `domain/`에
- feature 계층: `ui` → `data`만 허용, `data`는 `ui`에 의존하지 않는다

## 1주차 할 일

- [ ] **의존성 잠금(A-11, 필수)**: Android SDK가 있는 환경에서 모든 모듈(`app`·`core`·`wear`·feature 5개·`konsist-test`)의
  `build.gradle.kts`에 `dependencyLocking { lockAllConfigurations() }`를 켜고 아래 명령으로 `gradle.lockfile`을 만들어
  커밋한다(의존성 감사 `trivy fs`의 전제). 의존성을 바꿀 때마다 같은 명령으로 갱신하고, `gradle.lockfile` 변경은 엄격 판정이다

  ```bash
  android/gradlew -p android :app:dependencies :core:dependencies :wear:dependencies \
    :feature:member:dependencies :feature:meal:dependencies :feature:workout:dependencies \
    :feature:coaching:dependencies :feature:growth:dependencies :konsist-test:dependencies --write-locks
  ```

- [ ] OpenAPI 생성 DTO(ADR-09): `contracts/openapi.json`이 생기면 `:core`의 `network/generated/`에 openapi-generator(kotlin)로
  DTO를 생성하는 설정, 직렬화 변환기(kotlinx-serialization), 서버 주소(`NetworkConfig.BASE_URL` 자리표시)
- [ ] 앱 아이콘, 서명 설정(폰·워치 같은 키), 실제 Material 3 테마·Wear 테마 토큰
- [ ] Data Layer 경로·형식 확정(`DataLayerPaths`), 2주차 말 실기기 스파이크(ADR-02)

## 결정 필요

- 워치 `com.google.android.wearable.standalone`: Companion(ADR-02)이라 `false`로 두었다. 워치 단독 설치를 허용할지 배포 정책과 함께 정한다
- `:core`가 Retrofit을 `api`로 노출하므로 `:wear` 클래스패스에도 Retrofit·OkHttp가 들어간다. import는 컨벤션 테스트가 막지만 모듈 분리(`:core` 쪼개기) 여부는 필요해질 때 정한다
- Room 스키마 내보내기(`exportSchema`)와 마이그레이션 테스트 방식: 첫 Workout 테이블 확정 때 정한다
