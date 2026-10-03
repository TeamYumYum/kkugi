# ADR-05: Android 모듈은 :app · :wear · :core · :feature:{도메인}×5

**Date:** 2026-10-03

## Context

도메인 4개를 4명이 개인 수직으로 소유한다(A Meal, B Workout, C Member+Growth, D Coaching).
패키지 분리만으로는 "Meal이 Workout 내부를 import하는" 일을 막을 수 없다 — 규칙과 리뷰에만 의존하게 된다.
워치(:wear)는 Workout 도메인 모델과 Data Layer 계약을 폰과 공유해야 한다.

## Decision

```
android/
├── app/                      폰 진입점. 네비게이션 그래프, Hilt 루트, feature 조립
├── wear/                     워치 진입점. Workout Mode, Tile, Health Services
├── core/                     단일 모듈: 모델, 네트워크(Retrofit·OpenAPI 생성 DTO), Room, 디자인 시스템, Data Layer 계약, 공통 유틸
└── feature/
    ├── member/               로그인·온보딩·프로필
    ├── meal/                 카메라·인식 결과·수정·식사 목록
    ├── workout/              루틴·세션·완료 화면 (폰 측)
    ├── coaching/             홈 코멘트·마지막 끼니·리포트·RAG 채팅
    └── growth/               Nyam·XP·Streak·뱃지·미션
```

의존 규칙:
- `:feature:*` → `:core`만. **feature 간 의존 금지.** 화면 간 이동은 `:app`의 네비게이션 그래프가 담당.
- `:wear` → `:core`만. `:feature:workout`(폰 UI)에는 의존하지 않는다.
- `:app` → 모든 `:feature` + `:core`.
- 여러 feature가 한 화면에 섞이는 홈은 `:app`(또는 `:feature:home`)에서 각 feature의 **공개 Composable**을 조립한다.

## Rationale

- **도메인 경계가 컴파일 에러가 된다.** Meal 소유자가 Workout 내부 클래스를 쓰면 빌드가 깨진다. 규칙 파일·리뷰에 기대지 않는다.
- **Git 충돌이 모듈 경계를 따라 줄어든다.** 개인 수직 소유와 정확히 일치.
- `:core`를 단일 모듈로 두는 이유: Now-in-Android식 `core:{model,network,database,designsystem,…}` 세분화는 모듈 12개+와 convention plugin을 요구한다. 8주엔 과하다. 필요하면 나중에 쪼갠다(쪼개는 건 쉽고, 합치는 건 어렵다 — 그러나 지금은 수요가 없다).
- 워치가 `:core`만 의존하면 폰 UI 라이브러리(Material3)가 워치 APK에 들어가지 않는다.

## Alternatives Considered

- **:app · :wear · :shared 3모듈, 도메인은 패키지로만**: 가장 단순. 경계는 규칙·리뷰로만 지킴. 개인 수직에서 경계 침범이 조용히 일어남. 기각.
- **Now-in-Android식 전체 세분화**: 가장 엄격. 초기 빌드 설정 2~3일 + convention plugin 학습. 기각.
- **feature를 도메인이 아니라 화면 단위로**(`:feature:home`, `:feature:camera`): 소유 단위(도메인)와 어긋남. 기각.

## Consequences

- 1주차에 A(폰 홈)가 모듈 뼈대 + Hilt 배선 + 샘플 feature 1개를 세운다. 나머지는 복사해서 시작.
- feature 간 데이터가 필요하면(예: 홈이 Meal 요약 + Growth XP) 각 feature가 `:core` 모델을 반환하는 **공개 Repository/Composable**을 노출하고 `:app`이 조립한다.
- 빌드 시간: 모듈 8개는 증분 빌드에 유리. 전체 클린 빌드는 느려질 수 있어 CI 캐시 설정 필요(C 담당).
