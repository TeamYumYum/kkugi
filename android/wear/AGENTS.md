# android/wear AGENTS.md

루트 `AGENTS.md`를 전제로 `android/wear/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- [요구사항 Workout](../../docs/requirements/workout.md) — Workout Mode·세션 동기화 인수 조건, [공통](../../docs/requirements/common.md)
- [기술 설계 폴더](../../docs/design/README.md) — 워치 ↔ 폰 동기화 설계(예정)
- [ADR-0002](../../docs/adr/0002-watch-companion-offline-first.md) Companion·오프라인 우선, [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md) 오프라인 범위
- 모듈 표·스캐폴드·결정 필요 항목은 [android/README.md](../README.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: JDK 17 이상, Android SDK(compileSdk 36, `ANDROID_HOME` 또는 `android/local.properties`).

- 작업 중 빠른 확인: `android/gradlew -p android :wear:check` (이 모듈만)
- 작업 완료 전 필수(`harness.json verify`): `android/gradlew -p android :wear:check`. 워치 규칙(네트워크 import 금지)은 `android/gradlew -p android :konsist-test:test`가 검사하므로 함께 돌린다
- CI 전용: Android SDK가 없는 환경에서는 위 명령을 돌릴 수 없다. CI가 없으므로 MR 검증 절에 미검증으로 적고 SDK가 있는 팀원이 확인한다

형식은 `android/gradlew -p android ktlintFormat`으로 맞춘다(완료 검증 전에 실행).

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. 권한 추가·변경(AndroidManifest.xml의 uses-permission, 런타임 권한 요청)
2. 토큰·인증 정보의 저장·전달(SharedPreferences·DataStore·Keystore·Intent)
3. 백그라운드 작업(WorkManager·Service·알람·포그라운드 서비스)의 신설·변경
4. 폰↔워치 데이터 동기화(Wearable Data Layer API)와 메시지 형식
5. 계약(서버 API·DTO·직렬화 형식) 변경, 또는 계약과 다른 구현
6. 워치에 서버 호출·인증·토큰 코드 추가(ADR-02: Companion, 폰 경유)
7. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 생명주기·구성 변경에서 상태 보존(ViewModel·SavedStateHandle) · 메인 스레드 차단과 코루틴 범위 · Hilt 바인딩 위치(feature는 자기 Repository를 di/ 패키지의 @Binds로 제공) · 접근성(contentDescription·터치 영역·글자 크기). [사람]

## 5. 영역 규칙

- 워치는 서버·인증을 모른다. Retrofit·OkHttp·Ktor를 import하지 않는다(ADR-0002, Konsist `wear-no-network`). 루틴 내려받기·세션 올리기는 Wearable Data Layer로 폰이 맡는다.
- `:wear`는 `:core`만 의존한다. `:feature:workout`의 폰 UI에 의존하지 않는다(ADR-0005). minSdk 30.
- `applicationId`·서명은 `:app`과 같아야 한다(Data Layer 전제). `com.google.android.wearable.standalone`은 `false`다. 단독 설치 허용 여부는 결정 필요(README).
- 스캐폴드(`wear-screen`)가 출력하는 내비게이션 조각은 `WearNavHost.kt`의 `nyamnyam:destinations` 표식 위에 붙인다.
- 세션 소유권은 단일이다. 먼저 시작한 기기가 주인, 다른 쪽은 읽기 전용(기획서 5.2). 데이터 형식은 `DataLayerPaths` 확정 후 설계 문서로 옮긴다.
