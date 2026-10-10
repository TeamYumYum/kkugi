# android AGENTS.md

이 문서는 `android/` 아래의 모든 모듈에 공통으로 적용되는 기준 문서, 검증, 엄격 트리거, 리뷰 관점을 정합니다.
모듈에 고유한 내용은 [app](app/AGENTS.md), [core](core/AGENTS.md), [wear](wear/AGENTS.md), [feature](feature/AGENTS.md),
[konsist-test](konsist-test/AGENTS.md)의 `AGENTS.md`에 있으며, 이 문서와 함께 적용합니다. 판정 단계와 플랜·리뷰 절차는
루트 `AGENTS.md` 5장에 있습니다. 이 파일은 키트(ai-dev-harness)가 생성한 영역 파일의 공통 부분을 팀이 모은 것입니다.
영역 파일을 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [API 공통 규약](../docs/api/conventions.md): 서버 API를 호출하거나 응답과 오류를 처리할 때 11장을, 토큰을 다룰 때 6장(가정)을 읽습니다.
- [요구사항 명세](../docs/requirements/README.md): 화면이나 기능을 구현할 때 해당 도메인 파일과 [공통](../docs/requirements/common.md)을 읽습니다.
- [ADR-0004](../docs/adr/0004-android-two-layers.md), [ADR-0005](../docs/adr/0005-android-feature-modules.md), [ADR-0006](../docs/adr/0006-di-hilt.md):
  계층, 모듈, DI 구조를 바꿔야 할 것 같을 때 읽습니다.
- [android/README.md](README.md): 개발 환경을 준비하거나, 스캐폴드로 화면과 Repository를 추가할 때 읽습니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 17 이상과 Android SDK(compileSdk 36)이며, SDK 경로는 `ANDROID_HOME` 또는
`android/local.properties`로 지정합니다. 모듈별 명령은 각 모듈 파일의 2장에 있습니다.

- 어느 모듈을 바꾸든 `android/gradlew -p android :konsist-test:test`를 함께 실행합니다. 모듈 간 계층 규칙을 이 테스트가 검사합니다.
- 형식은 완료 검증 전에 `android/gradlew -p android ktlintFormat`으로 맞춥니다.
- Android SDK가 없는 환경에서는 검증 명령을 실행할 수 없습니다. CI가 아직 없으므로 MR 검증 절에 미검증으로 적고,
  SDK가 있는 팀원이 확인합니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.
모듈 파일 3장에 모듈별 트리거가 더 있습니다.

1. 권한을 추가하거나 변경하는 경우입니다(AndroidManifest.xml의 uses-permission, 런타임 권한 요청).
2. 토큰과 인증 정보를 저장하거나 전달하는 경우입니다(SharedPreferences, DataStore, Keystore, Intent).
3. 백그라운드 작업(WorkManager, Service, 알람, 포그라운드 서비스)을 신설하거나 변경하는 경우입니다.
4. 폰과 워치 사이의 데이터 동기화(Wearable Data Layer API)와 메시지 형식을 변경하는 경우입니다.
5. 계약(서버 API, DTO, 직렬화 형식)을 변경하거나, 계약과 다르게 구현하는 경우입니다.
6. `harness.json`에서 android 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 5장)에 다음을 덧붙입니다. 생명주기와 구성 변경에서 상태가 보존되는지(ViewModel, SavedStateHandle),
메인 스레드를 차단하지 않는지와 코루틴 범위가 적절한지, 접근성(contentDescription, 터치 영역, 글자 크기)을 지키는지 확인합니다. [사람]

## 5. 영역 규칙

- 모듈 사이의 의존과 계층 규칙은 Konsist(`:konsist-test`)가 검사합니다. 규칙 목록과 출처 ADR은 [ADR README의 가드레일 표](../docs/adr/README.md)에 있습니다.
