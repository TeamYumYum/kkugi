# android/feature AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `android/feature/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- 요구사항 명세는 도메인별로 봅니다: [member](../../docs/requirements/member.md), [meal](../../docs/requirements/meal.md), [workout](../../docs/requirements/workout.md), [coaching](../../docs/requirements/coaching.md), [growth](../../docs/requirements/growth.md), [공통](../../docs/requirements/common.md)
- [API 공통 규약](../../docs/api/conventions.md): 11장 클라이언트 규칙입니다. 생성 타입만 쓰고, 오프라인 처리는 운동 세션에만 합니다.
- [ADR-0004](../../docs/adr/0004-android-two-layers.md)는 ui와 data 2계층과 조건부 UseCase를, [ADR-0005](../../docs/adr/0005-android-feature-modules.md)는 feature가 `:core`에만 의존한다는 원칙을 정합니다.
- 모듈 표, 스캐폴드, 컨벤션은 [android/README.md](../README.md)에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 17 이상과 Android SDK(compileSdk 36)입니다. SDK 경로는 `ANDROID_HOME` 또는 `android/local.properties`로 지정합니다.

- 작업 중 빠른 확인: 바꾼 모듈에만 실행합니다. 예를 들어 `android/gradlew -p android :feature:meal:check`입니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :feature:member:check :feature:meal:check :feature:workout:check :feature:coaching:check :feature:growth:check`를 실행합니다. 계층 규칙과 ViewModel 규칙은 `android/gradlew -p android :konsist-test:test`가 검사하므로 함께 실행합니다.
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 실행할 수 없습니다. CI가 아직 없으므로 MR 검증 절에 미검증으로 적고, SDK가 있는 팀원이 확인합니다.

형식은 완료 검증 전에 `android/gradlew -p android ktlintFormat`으로 맞춥니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. 권한을 추가하거나 변경하는 경우입니다(AndroidManifest.xml의 uses-permission, 런타임 권한 요청).
2. 토큰과 인증 정보를 저장하거나 전달하는 경우입니다(SharedPreferences, DataStore, Keystore, Intent).
3. 백그라운드 작업(WorkManager, Service, 알람, 포그라운드 서비스)을 신설하거나 변경하는 경우입니다.
4. 폰과 워치 사이의 데이터 동기화(Wearable Data Layer API)와 메시지 형식을 변경하는 경우입니다.
5. 계약(서버 API, DTO, 직렬화 형식)을 변경하거나, 계약과 다르게 구현하는 경우입니다.
6. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 생명주기와 구성 변경에서 상태가 보존되는지(ViewModel, SavedStateHandle), 메인 스레드를 차단하지 않는지와 코루틴 범위가 적절한지, Hilt 바인딩 위치가 맞는지(feature는 자기 Repository를 `di/` 패키지의 `@Binds`로 제공합니다), 접근성(contentDescription, 터치 영역, 글자 크기)을 지키는지 확인합니다. [사람]

## 5. 영역 규칙

다음 규칙은 Konsist(`:konsist-test`)가 강제합니다. 위반하면 검증이 실패합니다.

- 계층은 `ui/`(Screen, Route, ViewModel, UiState)에서 `data/`(Repository)로 향하는 방향만 허용합니다. `data`는 `ui`에 의존하지 않습니다.
- ViewModel은 Repository 인터페이스만 받습니다. Retrofit, Room, DataSource, DAO를 import하지 않습니다(ADR-0004).
- feature는 Room을 쓰지 않습니다. Room은 `:core`의 Workout 테이블에만 씁니다(ADR-0003).
- feature 사이에는 의존이 없습니다. 화면 이동은 `:app`이 조립합니다(ADR-0005).
- `*Screen` Composable은 ViewModel을 받지 않습니다. `GlobalScope`는 금지합니다. UseCase는 ViewModel 2곳 이상이 공유할 때만 `domain/`에 둡니다. 첫 `domain/` 패키지가 생기면 `android/konsist-test/AGENTS.md`의 트리거 2를 따릅니다.
- Repository는 자기 feature의 `di/` 모듈에서 `@Binds`로 제공합니다. 규칙이 빈 범위에서 거짓으로 통과하지 않도록 feature마다 `ui/`와 `data/` 파일을 하나 이상 남깁니다.
