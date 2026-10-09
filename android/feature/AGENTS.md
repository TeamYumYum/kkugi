# android/feature AGENTS.md

루트 `AGENTS.md`를 전제로 `android/feature/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- 요구사항 명세 — 도메인별: [member](../../docs/requirements/member.md) · [meal](../../docs/requirements/meal.md) · [workout](../../docs/requirements/workout.md) · [coaching](../../docs/requirements/coaching.md) · [growth](../../docs/requirements/growth.md) · [공통](../../docs/requirements/common.md)
- [API 공통 규약](../../docs/api/conventions.md) — 11장 클라이언트 규칙(생성 타입만, 오프라인은 운동 세션만)
- [ADR-0004](../../docs/adr/0004-android-two-layers.md) ui·data 2계층 + 조건부 UseCase, [ADR-0005](../../docs/adr/0005-android-feature-modules.md) feature는 `:core`만 의존
- 모듈 표·스캐폴드·컨벤션은 [android/README.md](../README.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: JDK 17 이상, Android SDK(compileSdk 36, `ANDROID_HOME` 또는 `android/local.properties`).

- 작업 중 빠른 확인: 바꾼 모듈만. 예 `android/gradlew -p android :feature:meal:check`
- 작업 완료 전 필수(`harness.json verify`): `android/gradlew -p android :feature:member:check :feature:meal:check :feature:workout:check :feature:coaching:check :feature:growth:check`. 계층·ViewModel 규칙은 `android/gradlew -p android :konsist-test:test`가 검사하므로 함께 돌린다
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 돌릴 수 없다. CI가 없으므로 MR 검증 절에 미검증으로 적고 SDK가 있는 팀원이 확인한다

형식은 `android/gradlew -p android ktlintFormat`으로 맞춘다(완료 검증 전에 실행).

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. 권한 추가·변경(AndroidManifest.xml의 uses-permission, 런타임 권한 요청)
2. 토큰·인증 정보의 저장·전달(SharedPreferences·DataStore·Keystore·Intent)
3. 백그라운드 작업(WorkManager·Service·알람·포그라운드 서비스)의 신설·변경
4. 폰↔워치 데이터 동기화(Wearable Data Layer API)와 메시지 형식
5. 계약(서버 API·DTO·직렬화 형식) 변경, 또는 계약과 다른 구현
6. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 생명주기·구성 변경에서 상태 보존(ViewModel·SavedStateHandle) · 메인 스레드 차단과 코루틴 범위 · Hilt 바인딩 위치(feature는 자기 Repository를 di/ 패키지의 @Binds로 제공) · 접근성(contentDescription·터치 영역·글자 크기). [사람]

## 5. 영역 규칙

Konsist(`:konsist-test`)가 강제하는 규칙이다. 위반하면 검증이 실패한다.

- 계층은 `ui/`(Screen·Route·ViewModel·UiState) → `data/`(Repository)만 허용. `data`는 `ui`에 의존하지 않는다.
- ViewModel은 Repository 인터페이스만 받는다. Retrofit·Room·DataSource·DAO를 import하지 않는다(ADR-0004).
- feature는 Room을 쓰지 않는다. Room은 `:core`의 Workout 테이블만(ADR-0003).
- feature 사이 의존은 없다. 화면 이동은 `:app`이 조립한다(ADR-0005).
- `*Screen` Composable은 ViewModel을 받지 않는다. `GlobalScope` 금지. UseCase는 ViewModel 2곳 이상이 공유할 때만 `domain/`에 둔다. 첫 `domain/` 패키지가 생기면 `android/konsist-test/AGENTS.md` 트리거 2를 따른다.
- Repository는 자기 feature의 `di/` 모듈에서 `@Binds`로 제공한다. feature마다 `ui/`·`data/` 파일을 하나 이상 남긴다(빈 범위 거짓 통과 방지).
