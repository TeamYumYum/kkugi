# ADR-01: 모바일은 네이티브 Android(Kotlin + Compose) + Wear OS — Flutter 아님

**Date:** 2026-10-03

## Context

리뉴얼의 Primary 표면은 모바일이고, 워치(Wear OS)가 MVP 핵심 기능(웨이트 세트 기록)을 담당한다.
사전 GPT 상담에서는 "모바일 Flutter + Rive, 워치 Kotlin Compose"가 결론이었으나,
가드레일 키트의 규칙 파일이 요구하는 결정 항목(Hilt·Clean Architecture·app/wear 모듈·Data Layer)은 네이티브 Android를 전제로 한다.
팀에 Hilt + MVVM 경험자가 있고, 6명 중 4명 이상이 Compose + Spring을 직접 쓸 수 있다.

## Decision

모바일 앱은 **네이티브 Android(Kotlin, Jetpack Compose)**, 워치는 **Wear OS(Compose for Wear)**로 개발한다. iOS는 범위 밖.

## Rationale

- **워치와 모듈·코드를 공유한다.** `:core`(모델·Data Layer 계약·Room 스키마)를 폰과 워치가 같은 Gradle 프로젝트에서 공유. Flutter 폰 + Kotlin 워치는 두 언어·두 빌드 체계로 같은 Workout 도메인을 두 번 쓴다.
- **Data Layer(DataClient·MessageClient)·Health Services·Health Connect·FCM이 전부 1급 Kotlin API다.** Flutter에선 플러그인 또는 플랫폼 채널을 거친다.
- **팀 경험이 네이티브 쪽에 있다.** Hilt·MVVM 경험이 바로 쓰인다. Flutter는 전원 학습 비용.
- **웹과 UI를 공유하지 않기로 했으므로**(모바일 = 감성적 consumer UX, 웹 = 데이터 대시보드) Flutter의 크로스플랫폼 이점이 없다.

## Alternatives Considered

- **Flutter + Rive**: iOS 동시 지원이 유일한 이점. 8주 안에 iOS까지 QA할 여력 없음. 워치 연동이 불리. 기각.
- **Flutter 폰 + Kotlin 워치 혼합**: Workout 도메인 모델이 Dart와 Kotlin에 중복. 수직 소유자(B)가 두 스택을 다룸. 기각.
- **KMP(Kotlin Multiplatform)**: 웹·iOS 공유 대상이 없으므로 이점 없음. 기각.

## Consequences

- Android 담당 2명(A 폰 홈, B Wear 홈)이 공통 기반(앱 셸·DI·디자인 시스템·Data Layer)을 1주차에 세운다.
- iOS 사용자는 웹 대시보드만 쓸 수 있다. 발표에서 "Android 우선" 명시.
- 디자인 시스템은 Compose 기준으로 다시 정의한다(PRODUCT.md·DESIGN.md의 웹용 토큰은 참고만).
