# ADR-04: Android 계층은 ui · data 2계층 + 조건부 UseCase

**Date:** 2026-10-03

## Context

Android 앱의 계층 수를 정해야 한다. 가드레일 규칙 파일이 "어디에 무엇을 두는가"를 강제하려면 계층이 명확해야 한다.
팀은 Hilt + MVVM 경험이 있고, Claude Code로 코드 대부분을 생산한다. 도메인 4개를 4명이 개인 수직으로 소유한다.

## Decision

**ui · data 2계층**(Google 권장 기본형)을 쓴다.
- `ui/`: Compose 화면 + ViewModel(UiState 노출). ViewModel은 Repository를 **직접** 호출한다.
- `data/`: Repository(인터페이스 + 구현), 원격(Retrofit) · 로컬(Room) 데이터 소스, DTO ↔ 모델 매퍼.
- `domain/` 패키지와 UseCase는 **조건부**: 같은 로직을 **2개 이상의 ViewModel이 쓸 때만** UseCase로 추출한다. 1회성 로직은 ViewModel 또는 Repository에 둔다.
- 순수 Kotlin 모델(`Meal`, `WorkoutSession` 등)은 `:core`에 둔다(폰·워치 공유).

## Rationale

- **파일 수가 적어 리뷰 부담이 낮다.** 3계층은 액션마다 UseCase 파일이 생겨 같은 기능에 파일이 1.5배. Claude가 보일러플레이트를 만들어 줘도 **사람이 리뷰할 양**은 그대로 늘어난다.
- Google 공식 가이드가 domain 계층을 "선택"으로 둔다. 2계층은 표준이라 규칙 설명 비용이 적다.
- "2개 이상 ViewModel이 공유할 때만 UseCase"는 **기계적으로 판정 가능한 규칙**이다. 가드레일 규칙으로 쓰기 좋다.
- 공유 로직의 실제 후보는 Workout(폰 완료 화면과 워치가 같은 볼륨·PR 계산)뿐이고, 그건 `:core`의 순수 함수로 충분하다.

## Alternatives Considered

- **ui · domain · data 3계층(항상 UseCase)**: 모든 기능이 같은 모양 → 규칙 강제·리뷰가 쉬움. 파일 수 1.5배, 단순 CRUD에서 pass-through UseCase 양산. 기각.
- **단일 계층(ViewModel이 Retrofit 직접 호출)**: 오프라인(Room)·Data Layer를 ViewModel에 섞게 됨. 기각.

## Consequences

- 규칙 파일: "ViewModel은 Repository 인터페이스만 의존. DataSource·Retrofit·Room DAO를 직접 import하지 않는다."
- 규칙 파일: "UseCase는 `domain/` 아래, 2개 이상 ViewModel이 쓰는 경우에만. PR 설명에 사용처 2곳을 적는다."
- 나중에 로직이 복잡해지면 해당 feature 모듈만 3계층으로 승격할 수 있다(모듈 경계가 있으므로 국소적).
