# android/core AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `android/core/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [API 공통 규약](../../docs/api/conventions.md): 11장 클라이언트 규칙(생성 타입만 사용)과 6장 인증(가정)을 봅니다.
- [contracts/README.md](../../contracts/README.md): `:core` 생성 DTO의 원천입니다(ADR-0009).
- [기술 설계 폴더](../../docs/design/README.md): 워치와 폰의 동기화 설계가 들어올 예정입니다.
- [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md)은 Room의 범위를, [ADR-0005](../../docs/adr/0005-android-feature-modules.md)는 모듈 경계를, [ADR-0009](../../docs/adr/0009-openapi-contract-generation.md)는 계약 생성을 정합니다.
- 모듈 표와 결정이 필요한 항목은 [android/README.md](../README.md)에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 17 이상과 Android SDK(compileSdk 36)입니다. SDK 경로는 `ANDROID_HOME` 또는 `android/local.properties`로 지정합니다.

- 작업 중 빠른 확인: `android/gradlew -p android :core:check`를 이 모듈에만 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :core:check`를 실행합니다. `:core`는 모든 모듈이 쓰므로 `:app`, `:wear`, feature의 검증과 `:konsist-test:test`도 함께 실행합니다.
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 실행할 수 없습니다. CI가 아직 없으므로 MR 검증 절에 미검증으로 적고, SDK가 있는 팀원이 확인합니다.

형식은 완료 검증 전에 `android/gradlew -p android ktlintFormat`으로 맞춥니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. 권한을 추가하거나 변경하는 경우입니다(AndroidManifest.xml의 uses-permission, 런타임 권한 요청).
2. 토큰과 인증 정보를 저장하거나 전달하는 경우입니다(SharedPreferences, DataStore, Keystore, Intent).
3. 백그라운드 작업(WorkManager, Service, 알람, 포그라운드 서비스)을 신설하거나 변경하는 경우입니다.
4. 폰과 워치 사이의 데이터 동기화(Wearable Data Layer API)와 메시지 형식을 변경하는 경우입니다.
5. 계약(서버 API, DTO, 직렬화 형식)을 변경하거나, 계약과 다르게 구현하는 경우입니다.
6. Room 테이블을 추가하는 경우입니다(ADR-03). Room에는 Workout의 세션, 세트, 업로드 상태만 둡니다.
7. OpenAPI 생성 DTO(generated)를 손으로 수정하는 경우입니다(ADR-09).
8. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 생명주기와 구성 변경에서 상태가 보존되는지(ViewModel, SavedStateHandle), 메인 스레드를 차단하지 않는지와 코루틴 범위가 적절한지, Hilt 바인딩 위치가 맞는지(feature는 자기 Repository를 `di/` 패키지의 `@Binds`로 제공합니다), 접근성(contentDescription, 터치 영역, 글자 크기)을 지키는지 확인합니다. [사람]

## 5. 영역 규칙

- `:core`에는 `model/`(순수 모델), `network/`(Retrofit과 생성 DTO 자리), `database/`(Room, Workout 테이블만), `designsystem/`(색 토큰), `datalayer/`(폰과 워치 사이의 경로 상수), `di/`를 둡니다. 워치도 쓰는 모듈이므로 폰 UI 라이브러리(Material 3)는 두지 않습니다.
- `:core` 변경은 공통 변경이므로 홈 담당 A의 승인이 필요합니다(Git 컨벤션 4장).
- 생성 DTO(`network/generated/`, 예정)는 손으로 고치지 않습니다. `contracts/openapi.json`이 생기면 openapi-generator 설정을 넣습니다(README 1주차 할 일). 생성 범위는 결정이 필요합니다.
- `:core`가 Retrofit을 `api`로 노출하므로 `:wear`의 클래스패스에도 Retrofit이 들어갑니다. 워치에서의 import는 Konsist가 막습니다. 모듈 분리 여부는 필요해질 때 정합니다(README 결정 필요 항목).
- Room 스키마 내보내기와 마이그레이션 테스트 방식은 `TODO(확인 필요: 첫 Workout 테이블을 확정할 때 정합니다)`입니다.
