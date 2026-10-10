# android/wear AGENTS.md

이 문서는 `android/wear/`(Wear OS 앱)에만 해당하는 내용을 정합니다. android 공통 규칙은 [android/AGENTS.md](../AGENTS.md)에
있으며, 이 문서보다 먼저 읽습니다.

## 1. 기준 문서

- [요구사항 Workout](../../docs/requirements/workout.md): Workout Mode나 세션 동기화를 구현할 때 읽습니다.
- [ADR-0002](../../docs/adr/0002-watch-companion-offline-first.md): 워치가 서버나 폰과 통신하는 방식을 바꿔야 할 것 같을 때 읽습니다.
- [기술 설계 폴더](../../docs/design/README.md): Data Layer 메시지 형식을 정하거나 바꿀 때 읽습니다. 동기화 설계가 들어올 예정입니다.

## 2. 검증

- 작업 중 빠른 확인과 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :wear:check`를 실행합니다.

## 3. 엄격 트리거

android 공통 트리거에 다음을 더합니다.

1. 워치에 서버 호출, 인증, 토큰 코드를 추가하는 경우입니다(ADR-02). 워치는 Companion이므로 폰을 경유합니다.

## 4. 이 영역에서 특히 볼 관점

android 공통 관점 외에 추가 관점은 없습니다.

## 5. 영역 규칙

- 루틴 내려받기와 세션 올리기는 Wearable Data Layer를 통해 폰이 맡습니다. 워치는 데이터를 로컬에 먼저 저장하고, 폰과 연결되면 넘깁니다(ADR-0002).
- 세션 소유권은 단일합니다. 먼저 시작한 기기가 주인이고 다른 쪽은 읽기 전용입니다(기획서 5.2).
