# android/feature AGENTS.md

이 문서는 `android/feature/`(도메인별 기능 모듈 5개)에만 해당하는 내용을 정합니다. android 공통 규칙은
[android/AGENTS.md](../AGENTS.md)에 있으며, 이 문서보다 먼저 읽습니다.

## 1. 기준 문서

- 요구사항 명세: 기능을 구현할 때 해당 도메인 파일을 읽습니다. [member](../../docs/requirements/member.md),
  [meal](../../docs/requirements/meal.md), [workout](../../docs/requirements/workout.md), [coaching](../../docs/requirements/coaching.md),
  [growth](../../docs/requirements/growth.md)가 있습니다.

## 2. 검증

- 작업 중 빠른 확인: 바꾼 모듈에만 실행합니다. 예를 들어 `android/gradlew -p android :feature:meal:check`입니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :feature:member:check :feature:meal:check :feature:workout:check :feature:coaching:check :feature:growth:check`를 실행합니다.

## 3. 엄격 트리거

android 공통 트리거 외에 추가 트리거는 없습니다.

## 4. 이 영역에서 특히 볼 관점

android 공통 관점에 더하여, 각 feature가 자기 Repository를 `di/` 패키지의 `@Binds`로 제공하는지 확인합니다. [사람]

## 5. 영역 규칙

- UseCase는 ViewModel 2곳 이상이 공유할 때만 `domain/`에 둡니다(ADR-0004). feature에 첫 `domain/` 패키지가 생기면
  [konsist-test의 트리거 2](../konsist-test/AGENTS.md)를 따릅니다.
- feature마다 `ui/`와 `data/` 파일을 하나 이상 남깁니다. 파일이 없으면 Konsist 규칙이 검사할 대상이 없어 거짓으로 통과하기 때문입니다.
- 오프라인 처리는 운동 세션에만 합니다(ADR-0003). 다른 기능은 네트워크 오류 시 안내 메시지를 보여 줍니다.
