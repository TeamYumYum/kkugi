# android/app AGENTS.md

루트 `AGENTS.md`를 전제로 `android/app/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- [요구사항 명세](../../docs/requirements/README.md) — 화면 흐름의 기준. [공통](../../docs/requirements/common.md)과 도메인별 파일
- [API 공통 규약](../../docs/api/conventions.md) — 6장 인증(가정), 11장 클라이언트 규칙
- [ADR-0004](../../docs/adr/0004-android-two-layers.md) ui·data 2계층, [ADR-0005](../../docs/adr/0005-android-feature-modules.md) 모듈 경계, [ADR-0006](../../docs/adr/0006-di-hilt.md) Hilt
- 모듈 표·컨벤션·스캐폴드·1주차 할 일은 [android/README.md](../README.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: JDK 17 이상, Android SDK(compileSdk 36, `ANDROID_HOME` 또는 `android/local.properties`).

- 작업 중 빠른 확인: `android/gradlew -p android :app:check` (이 모듈만)
- 작업 완료 전 필수(`harness.json verify`): `android/gradlew -p android :app:check` — ktlint·Android Lint(접근성 검사 오류)·단위 테스트. feature나 core를 함께 바꿨으면 해당 영역 검증도 돌린다
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 돌릴 수 없다. CI가 없으므로 MR 검증 절에 미검증으로 적고 SDK가 있는 팀원이 확인한다

형식은 `android/gradlew -p android ktlintFormat`으로 맞춘다(완료 검증 전에 실행).

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. 권한 추가·변경(AndroidManifest.xml의 uses-permission, 런타임 권한 요청)
2. 토큰·인증 정보의 저장·전달(SharedPreferences·DataStore·Keystore·Intent)
3. 백그라운드 작업(WorkManager·Service·알람·포그라운드 서비스)의 신설·변경
4. 폰↔워치 데이터 동기화(Wearable Data Layer API)와 메시지 형식
5. 계약(서버 API·DTO·직렬화 형식) 변경, 또는 계약과 다른 구현
6. app에 화면 조립·네비게이션·DI 루트 밖의 로직 추가(ADR-05)
7. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 생명주기·구성 변경에서 상태 보존(ViewModel·SavedStateHandle) · 메인 스레드 차단과 코루틴 범위 · Hilt 바인딩 위치(feature는 자기 Repository를 di/ 패키지의 @Binds로 제공) · 접근성(contentDescription·터치 영역·글자 크기). [사람]

## 5. 영역 규칙

- `:app`은 화면 조립·내비게이션(`NyamNavHost`)·DI 루트·테마만 둔다. `*Repository`·`*DataSource`·`*Dao`·`*UseCase`를 두지 않는다(ADR-0005, Konsist `app-no-data-layer`).
- 스캐폴드가 출력하는 내비게이션 조각은 `NyamNavHost.kt`의 `nyamnyam:destinations` 표식 위에 붙인다(README).
- 폰과 워치는 같은 `applicationId`(`com.nyamnyam`)와 서명 인증서를 쓴다. 바꾸면 Data Layer가 서로를 찾지 못한다.
- 릴리스 빌드(R8·난독화) 확인 방법과 서명 설정: `TODO(확인 필요: proguard-rules.pro·release 설정이 아직 없다. README 1주차 할 일, 홈 담당 A)`
- 구버전 앱과의 API 하위 호환 정책: `TODO(확인 필요: 데모 태그 단위 배포에서 필요한지 팀이 정한다. 필요하면 API 규약 8장을 따른다)`
- 직렬화(kotlinx-serialization)·리플렉션 주의사항: `TODO(확인 필요: 생성 DTO와 변환기 도입 후 작성)`
