# android/core AGENTS.md

이 문서는 `android/core/`(폰과 워치가 함께 쓰는 공통 모듈)에만 해당하는 내용을 정합니다. android 공통 규칙은
[android/AGENTS.md](../AGENTS.md)에 있으며, 이 문서보다 먼저 읽습니다.

## 1. 기준 문서

- [contracts/README.md](../../contracts/README.md)와 [ADR-0009](../../docs/adr/0009-openapi-contract-generation.md): 생성 DTO를 설정하거나 재생성할 때 읽습니다.
- [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md): Room에 테이블이나 컬럼을 추가하기 전에 읽습니다.
- [기술 설계 폴더](../../docs/design/README.md): `datalayer/`의 경로나 형식을 바꿀 때 읽습니다. 워치와 폰의 동기화 설계가 들어올 예정입니다.

## 2. 검증

- 작업 중 빠른 확인: `android/gradlew -p android :core:check`를 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :core:check`를 실행합니다. `:core`는 모든 모듈이
  쓰므로 `:app`, `:wear`, feature의 검증도 함께 실행합니다.

## 3. 엄격 트리거

android 공통 트리거에 다음을 더합니다.

1. Room 테이블을 추가하는 경우입니다(ADR-03). Room에는 Workout의 세션, 세트, 업로드 상태만 둡니다.
2. OpenAPI 생성 DTO(generated)를 손으로 수정하는 경우입니다(ADR-09).

## 4. 이 영역에서 특히 볼 관점

android 공통 관점 외에 추가 관점은 없습니다.

## 5. 영역 규칙

- `:core` 변경은 공통 변경이므로 홈 담당 A의 승인이 필요합니다(Git 컨벤션 4장).
- Room 스키마 내보내기와 마이그레이션 테스트 방식은 `TODO(확인 필요: 첫 Workout 테이블을 확정할 때 정합니다)`입니다.
- 직렬화(kotlinx-serialization)와 리플렉션 관련 주의사항은 `TODO(확인 필요: 생성 DTO와 변환기를 도입한 뒤 작성합니다)`입니다.
