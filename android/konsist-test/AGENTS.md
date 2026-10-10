# android/konsist-test AGENTS.md

이 문서는 `android/konsist-test/`(아키텍처 테스트 전용 모듈)에만 해당하는 내용을 정합니다. android 공통 규칙은
[android/AGENTS.md](../AGENTS.md)에 있으며, 이 문서보다 먼저 읽습니다.

## 1. 기준 문서

- [ADR README의 가드레일 표](../../docs/adr/README.md): Konsist 규칙이 실패했을 때, 또는 규칙을 바꾸거나 끄기 전에 그 규칙의 출처 ADR을 확인하기 위해 읽습니다.
- `harness.json`의 `android/konsist-test` 영역: 검사 범위(`vars`), 계층(`layers`, `allow`), 끈 규칙(`disabled_rules`)을 바꿀 때 읽습니다.

## 2. 검증

- 작업 중 빠른 확인과 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :konsist-test:test`를 실행합니다.

## 3. 엄격 트리거

android 공통 트리거에 다음을 더합니다.

1. Konsist 규칙 범위(app_dir, core_dir, feature_dir, wear_dir)나 이 모듈의 Konsist·JUnit 의존성을 변경하는 경우입니다.
2. feature에 첫 domain 패키지(UseCase)가 생기는 경우입니다. 이 영역의 layers와 allow에 domain(`com.nyamnyam..domain..`)을 더하고
   ui → domain, domain → data를 허용한 뒤 `init --force`로 다시 생성합니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점에 다음을 덧붙입니다. 규칙의 검사 범위가 실제 모듈 디렉터리와 맞는지 확인합니다. 범위가 비어 있으면 규칙이
거짓으로 통과하기 때문입니다. 규칙을 끈 이유(disabled_rules)가 ADR과 맞는지도 확인합니다. [사람]

## 5. 영역 규칙

- 키트가 없는 동안 규칙 변경이 필요하면 사람이 결정하고 MR 본문에 이유를 적습니다.
