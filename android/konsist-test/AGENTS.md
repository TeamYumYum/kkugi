# android/konsist-test AGENTS.md

루트 `AGENTS.md`를 전제로 `android/konsist-test/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- [ADR README "가드레일 규칙 파일로 옮긴 문장"](../../docs/adr/README.md) — 각 Konsist 규칙의 출처 ADR
- [ADR-0002](../../docs/adr/0002-watch-companion-offline-first.md) · [ADR-0003](../../docs/adr/0003-phone-offline-workout-only.md) · [ADR-0004](../../docs/adr/0004-android-two-layers.md) · [ADR-0005](../../docs/adr/0005-android-feature-modules.md)
- `harness.json` `android/konsist-test` 영역 — `vars`(검사 범위 디렉터리), `layers`·`allow`(ui → data), `disabled_rules`
- 컨벤션 요약은 [android/README.md](../README.md) "컨벤션" 절

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: JDK 17 이상, Android SDK(다른 모듈 소스를 읽는다).

- 작업 중 빠른 확인: `android/gradlew -p android :konsist-test:test` (항상 다시 실행된다, `outputs.upToDateWhen { false }`)
- 작업 완료 전 필수(`harness.json verify`): `android/gradlew -p android :konsist-test:test`
- CI 전용: Android SDK가 없는 환경에서는 돌릴 수 없다. CI가 없으므로 MR 검증 절에 미검증으로 적고 SDK가 있는 팀원이 확인한다

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. Konsist 규칙 범위(app_dir·core_dir·feature_dir·wear_dir)나 이 모듈의 Konsist·JUnit 의존성 변경
2. feature에 첫 domain 패키지(UseCase)가 생길 때: 이 영역 layers·allow에 domain(com.nyamnyam..domain..)을 더하고 ui→domain, domain→data를 허용한 뒤 init --force
3. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 규칙 범위가 실제 모듈 디렉터리와 맞는지(범위가 비면 규칙이 거짓 통과한다) · 규칙을 끈 이유(disabled_rules)가 ADR과 맞는지. [사람]

## 5. 영역 규칙

- 이 모듈은 생산 코드가 없는 JVM 테스트 모듈이다. `src/test/kotlin/com/nyamnyam/`의 `HarnessFixedRulesTest.kt`·`HarnessLayerArchitectureTest.kt`는 키트가 생성·관리한다. **손으로 고치지 않는다.** 규칙을 바꾸거나 끄려면 `harness.json`을 고치고 키트로 다시 생성한다(트리거 2·3). 키트가 없는 동안 변경이 필요하면 사람이 결정하고 MR 본문에 이유를 적는다.
- 고정 규칙(ADR README 표): `viewmodel-repository-only`, `usecase-shared-by-two-viewmodels`, `feature-no-room`, `wear-no-network`, `app-no-data-layer`. 계층 규칙은 feature의 `ui` → `data`.
- 규칙이 검사하는 파일 수가 0이면 통과해도 의미가 없다. feature마다 `ui/`·`data/` 파일을 하나 이상 둔다(`android/feature/AGENTS.md` 5장).
