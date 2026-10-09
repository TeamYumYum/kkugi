# android/core AGENTS.md

루트 `AGENTS.md`를 전제로 `android/core/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- [API 공통 규약](../../docs/api/conventions.md) — 11장 클라이언트 규칙(생성 타입만), 6장 인증(가정)
- [contracts/README.md](../../contracts/README.md) — `:core` 생성 DTO의 원천(ADR-0009)
- [기술 설계 폴더](../../docs/design/README.md) — 워치 ↔ 폰 동기화 설계(예정)
- [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md) Room 범위, [ADR-0005](../../docs/adr/0005-android-feature-modules.md) 모듈 경계, [ADR-0009](../../docs/adr/0009-openapi-contract-generation.md) 계약 생성
- 모듈 표·결정 필요 항목은 [android/README.md](../README.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: JDK 17 이상, Android SDK(compileSdk 36, `ANDROID_HOME` 또는 `android/local.properties`).

- 작업 중 빠른 확인: `android/gradlew -p android :core:check` (이 모듈만)
- 작업 완료 전 필수(`harness.json verify`): `android/gradlew -p android :core:check`. `:core`는 모든 모듈이 쓰므로 `:app`·`:wear`·feature 검증과 `:konsist-test:test`도 함께 돌린다
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 돌릴 수 없다. CI가 없으므로 MR 검증 절에 미검증으로 적고 SDK가 있는 팀원이 확인한다

형식은 `android/gradlew -p android ktlintFormat`으로 맞춘다(완료 검증 전에 실행).

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. 권한 추가·변경(AndroidManifest.xml의 uses-permission, 런타임 권한 요청)
2. 토큰·인증 정보의 저장·전달(SharedPreferences·DataStore·Keystore·Intent)
3. 백그라운드 작업(WorkManager·Service·알람·포그라운드 서비스)의 신설·변경
4. 폰↔워치 데이터 동기화(Wearable Data Layer API)와 메시지 형식
5. 계약(서버 API·DTO·직렬화 형식) 변경, 또는 계약과 다른 구현
6. Room 테이블 추가(ADR-03: Workout 세션·세트·업로드 상태만)
7. OpenAPI 생성 DTO(generated) 손 수정(ADR-09)
8. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 생명주기·구성 변경에서 상태 보존(ViewModel·SavedStateHandle) · 메인 스레드 차단과 코루틴 범위 · Hilt 바인딩 위치(feature는 자기 Repository를 di/ 패키지의 @Binds로 제공) · 접근성(contentDescription·터치 영역·글자 크기). [사람]

## 5. 영역 규칙

- `:core`는 `model/`(순수 모델), `network/`(Retrofit, 생성 DTO 자리), `database/`(Room — Workout 테이블만), `designsystem/`(색 토큰), `datalayer/`(폰↔워치 경로 상수), `di/`를 둔다. 폰 UI 라이브러리(Material 3)는 두지 않는다(워치도 쓴다).
- `:core` 변경은 공통 변경이다. 홈 담당 A의 승인이 필요하다(Git 컨벤션 4장).
- 생성 DTO(`network/generated/`, 예정)는 손으로 고치지 않는다. `contracts/openapi.json`이 생기면 openapi-generator 설정을 넣는다(README 1주차 할 일, 생성 범위는 결정 필요).
- `:core`가 Retrofit을 `api`로 노출해 `:wear` 클래스패스에도 들어간다. 워치의 import는 Konsist가 막는다. 모듈 분리는 필요해질 때 정한다(README 결정 필요).
- Room 스키마 내보내기·마이그레이션 테스트 방식: `TODO(확인 필요: 첫 Workout 테이블 확정 때 정한다)`
