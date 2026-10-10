# android/app AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `android/app/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [요구사항 명세](../../docs/requirements/README.md): 화면 흐름의 기준입니다. [공통](../../docs/requirements/common.md)과 도메인별 파일을 봅니다.
- [API 공통 규약](../../docs/api/conventions.md): 6장 인증(가정)과 11장 클라이언트 규칙을 봅니다.
- [ADR-0004](../../docs/adr/0004-android-two-layers.md)는 ui와 data 2계층을, [ADR-0005](../../docs/adr/0005-android-feature-modules.md)는 모듈 경계를, [ADR-0006](../../docs/adr/0006-di-hilt.md)은 Hilt를 정합니다.
- 모듈 표, 컨벤션, 스캐폴드, 1주차 할 일은 [android/README.md](../README.md)에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 17 이상과 Android SDK(compileSdk 36)입니다. SDK 경로는 `ANDROID_HOME` 또는 `android/local.properties`로 지정합니다.

- 작업 중 빠른 확인: `android/gradlew -p android :app:check`를 이 모듈에만 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :app:check`를 실행합니다. ktlint, Android Lint(접근성 검사는 오류), 단위 테스트가 포함됩니다. feature나 core를 함께 바꿨으면 해당 영역의 검증도 실행합니다.
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 실행할 수 없습니다. CI가 아직 없으므로 MR 검증 절에 미검증으로 적고, SDK가 있는 팀원이 확인합니다.

형식은 완료 검증 전에 `android/gradlew -p android ktlintFormat`으로 맞춥니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. 권한을 추가하거나 변경하는 경우입니다(AndroidManifest.xml의 uses-permission, 런타임 권한 요청).
2. 토큰과 인증 정보를 저장하거나 전달하는 경우입니다(SharedPreferences, DataStore, Keystore, Intent).
3. 백그라운드 작업(WorkManager, Service, 알람, 포그라운드 서비스)을 신설하거나 변경하는 경우입니다.
4. 폰과 워치 사이의 데이터 동기화(Wearable Data Layer API)와 메시지 형식을 변경하는 경우입니다.
5. 계약(서버 API, DTO, 직렬화 형식)을 변경하거나, 계약과 다르게 구현하는 경우입니다.
6. app에 화면 조립, 네비게이션, DI 루트 밖의 로직을 추가하는 경우입니다(ADR-05).
7. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 생명주기와 구성 변경에서 상태가 보존되는지(ViewModel, SavedStateHandle), 메인 스레드를 차단하지 않는지와 코루틴 범위가 적절한지, Hilt 바인딩 위치가 맞는지(feature는 자기 Repository를 `di/` 패키지의 `@Binds`로 제공합니다), 접근성(contentDescription, 터치 영역, 글자 크기)을 지키는지 확인합니다. [사람]

## 5. 영역 규칙

- `:app`에는 화면 조립, 내비게이션(`NyamNavHost`), DI 루트, 테마만 둡니다. `*Repository`, `*DataSource`, `*Dao`, `*UseCase`를 두지 않습니다(ADR-0005, Konsist 규칙 `app-no-data-layer`).
- 스캐폴드가 출력하는 내비게이션 조각은 `NyamNavHost.kt`의 `nyamnyam:destinations` 표식 위에 붙입니다(README).
- 폰과 워치는 같은 `applicationId`(`com.nyamnyam`)와 서명 인증서를 씁니다. 이 값을 바꾸면 Data Layer가 서로를 찾지 못합니다.
- 릴리스 빌드(R8, 난독화)의 확인 방법과 서명 설정은 `TODO(확인 필요: proguard-rules.pro와 release 설정이 아직 없습니다. README 1주차 할 일이며 홈 담당 A가 정합니다)`입니다.
- 구버전 앱과의 API 하위 호환 정책은 `TODO(확인 필요: 데모 태그 단위 배포에서 필요한지 팀이 정합니다. 필요하면 API 규약 8장을 따릅니다)`입니다.
- 직렬화(kotlinx-serialization)와 리플렉션 관련 주의사항은 `TODO(확인 필요: 생성 DTO와 변환기를 도입한 뒤 작성합니다)`입니다.
