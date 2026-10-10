# android/app AGENTS.md

이 문서는 `android/app/`(폰 앱의 진입점)에만 해당하는 내용을 정합니다. android 공통 규칙은 [android/AGENTS.md](../AGENTS.md)에
있으며, 이 문서보다 먼저 읽습니다.

## 1. 기준 문서

android 공통 기준 문서 외에 추가로 읽을 문서는 없습니다.

## 2. 검증

- 작업 중 빠른 확인과 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :app:check`를 실행합니다.
  feature나 core를 함께 바꿨으면 해당 모듈의 검증도 실행합니다.

## 3. 엄격 트리거

android 공통 트리거에 다음을 더합니다.

1. app에 화면 조립, 내비게이션, DI 루트 밖의 로직을 추가하는 경우입니다(ADR-05).

## 4. 이 영역에서 특히 볼 관점

android 공통 관점 외에 추가 관점은 없습니다.

## 5. 영역 규칙

- `:app`에는 화면 조립, 내비게이션(`NyamNavHost`), DI 루트, 테마만 둡니다(ADR-0005).
- 릴리스 빌드(R8, 난독화)의 확인 방법과 서명 설정은 `TODO(확인 필요: proguard-rules.pro와 release 설정이 아직 없습니다. 홈 담당 A가 정합니다)`입니다.
