# android/konsist-test AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `android/konsist-test/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [ADR README의 "가드레일 규칙 파일로 옮긴 문장"](../../docs/adr/README.md): 각 Konsist 규칙의 출처 ADR입니다.
- [ADR-0002](../../docs/adr/0002-watch-companion-offline-first.md), [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md), [ADR-0004](../../docs/adr/0004-android-two-layers.md), [ADR-0005](../../docs/adr/0005-android-feature-modules.md)
- `harness.json`의 `android/konsist-test` 영역: `vars`(검사 범위 디렉터리), `layers`와 `allow`(ui에서 data로), `disabled_rules`입니다.
- 컨벤션 요약은 [android/README.md](../README.md)의 "컨벤션" 절에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 17 이상과 Android SDK입니다. 이 모듈은 다른 모듈의 소스를 읽기 때문입니다.

- 작업 중 빠른 확인: `android/gradlew -p android :konsist-test:test`를 실행합니다. `outputs.upToDateWhen { false }` 설정 때문에 항상 다시 실행됩니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `android/gradlew -p android :konsist-test:test`를 실행합니다.
- CI 전용: Android SDK가 없는 환경에서는 실행할 수 없습니다. CI가 아직 없으므로 MR 검증 절에 미검증으로 적고, SDK가 있는 팀원이 확인합니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. Konsist 규칙 범위(app_dir, core_dir, feature_dir, wear_dir)나 이 모듈의 Konsist·JUnit 의존성을 변경하는 경우입니다.
2. feature에 첫 domain 패키지(UseCase)가 생기는 경우입니다. 이 영역의 layers와 allow에 domain(`com.nyamnyam..domain..`)을 더하고 ui → domain, domain → data를 허용한 뒤 `init --force`로 다시 생성합니다.
3. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 규칙의 검사 범위가 실제 모듈 디렉터리와 맞는지 확인합니다. 범위가 비어 있으면 규칙이 거짓으로 통과하기 때문입니다. 규칙을 끈 이유(disabled_rules)가 ADR과 맞는지도 확인합니다. [사람]

## 5. 영역 규칙

- 이 모듈은 생산 코드가 없는 JVM 테스트 모듈입니다. `src/test/kotlin/com/nyamnyam/`의 `HarnessFixedRulesTest.kt`와 `HarnessLayerArchitectureTest.kt`는 키트가 생성하고 관리하므로 **손으로 고치지 않습니다.** 규칙을 바꾸거나 끄려면 `harness.json`을 고치고 키트로 다시 생성합니다(트리거 2와 3). 키트가 없는 동안 변경이 필요하면 사람이 결정하고 MR 본문에 이유를 적습니다.
- 고정 규칙은 ADR README 표에 있는 `viewmodel-repository-only`, `usecase-shared-by-two-viewmodels`, `feature-no-room`, `wear-no-network`, `app-no-data-layer`입니다. 계층 규칙은 feature의 `ui`에서 `data`로 향하는 방향입니다.
- 규칙이 검사하는 파일 수가 0이면 통과하더라도 의미가 없습니다. feature마다 `ui/`와 `data/` 파일을 하나 이상 둡니다(`android/feature/AGENTS.md` 5장).
