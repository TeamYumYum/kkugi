# android/wear AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `android/wear/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [요구사항 Workout](../../docs/requirements/workout.md): Workout Mode와 세션 동기화의 인수 조건입니다. [공통](../../docs/requirements/common.md)도 함께 봅니다.
- [기술 설계 폴더](../../docs/design/README.md): 워치와 폰의 동기화 설계가 들어올 예정입니다.
- [ADR-0002](../../docs/adr/0002-watch-companion-offline-first.md)는 Companion과 오프라인 우선 원칙을, [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md)은 오프라인 범위를 정합니다.
- 모듈 표, 스캐폴드, 결정이 필요한 항목은 [android/README.md](../README.md)에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 17 이상과 Android SDK(compileSdk 36)입니다. SDK 경로는 `ANDROID_HOME` 또는 `android/local.properties`로 지정합니다.

- 작업 중 빠른 확인: `android/gradlew -p android :wear:check`를 이 모듈에만 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :wear:check`를 실행합니다. 워치의 네트워크 import 금지 규칙은 `android/gradlew -p android :konsist-test:test`가 검사하므로 함께 실행합니다.
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 실행할 수 없습니다. CI가 아직 없으므로 MR 검증 절에 미검증으로 적고, SDK가 있는 팀원이 확인합니다.

형식은 완료 검증 전에 `android/gradlew -p android ktlintFormat`으로 맞춥니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. 권한을 추가하거나 변경하는 경우입니다(AndroidManifest.xml의 uses-permission, 런타임 권한 요청).
2. 토큰과 인증 정보를 저장하거나 전달하는 경우입니다(SharedPreferences, DataStore, Keystore, Intent).
3. 백그라운드 작업(WorkManager, Service, 알람, 포그라운드 서비스)을 신설하거나 변경하는 경우입니다.
4. 폰과 워치 사이의 데이터 동기화(Wearable Data Layer API)와 메시지 형식을 변경하는 경우입니다.
5. 계약(서버 API, DTO, 직렬화 형식)을 변경하거나, 계약과 다르게 구현하는 경우입니다.
6. 워치에 서버 호출, 인증, 토큰 코드를 추가하는 경우입니다(ADR-02). 워치는 Companion이므로 폰을 경유합니다.
7. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 생명주기와 구성 변경에서 상태가 보존되는지(ViewModel, SavedStateHandle), 메인 스레드를 차단하지 않는지와 코루틴 범위가 적절한지, Hilt 바인딩 위치가 맞는지(feature는 자기 Repository를 `di/` 패키지의 `@Binds`로 제공합니다), 접근성(contentDescription, 터치 영역, 글자 크기)을 지키는지 확인합니다. [사람]

## 5. 영역 규칙

- 워치는 서버와 인증을 모릅니다. Retrofit, OkHttp, Ktor를 import하지 않습니다(ADR-0002, Konsist 규칙 `wear-no-network`). 루틴 내려받기와 세션 올리기는 Wearable Data Layer를 통해 폰이 맡습니다.
- `:wear`는 `:core`에만 의존하며, `:feature:workout`의 폰 UI에 의존하지 않습니다(ADR-0005). minSdk는 30입니다.
- `applicationId`와 서명은 `:app`과 같아야 합니다. Data Layer가 서로를 찾는 전제 조건이기 때문입니다. `com.google.android.wearable.standalone`은 `false`이며, 단독 설치 허용 여부는 결정이 필요합니다(README).
- 스캐폴드(`wear-screen`)가 출력하는 내비게이션 조각은 `WearNavHost.kt`의 `nyamnyam:destinations` 표식 위에 붙입니다.
- 세션 소유권은 단일합니다. 먼저 시작한 기기가 주인이고 다른 쪽은 읽기 전용입니다(기획서 5.2). 데이터 형식은 `DataLayerPaths`를 확정한 뒤 설계 문서로 옮깁니다.
