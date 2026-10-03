# ADR-10: 웹은 React + Vite, feelm 폴더 구조 그대로 — Next.js·Vue 아님

**Date:** 2026-10-03

## Context

웹은 Secondary 표면이다: 사용자 대시보드(~6화면)와 관리자(~3화면), 전부 로그인 뒤, 전부 "읽고 조금 쓰는" 화면.
F 1명이 횡단 소유하고, 3~5주차엔 Workout 페어로 빠진다.
후보: React+Vite(feelm, 팀의 가장 최근 경험), Next.js(GPT 초기 제안), Vue 3(yumyum v1).

## Decision

**React 19 + Vite + react-router**, feelm 폴더 구조를 그대로 가져온다.

```
web/src/
├── api/          fetch 래퍼 (도메인별 파일: meals.ts, workouts.ts, admin.ts)
├── generated/    openapi-typescript 출력 (ADR-09) — 손으로 수정 금지
├── components/   공용 UI, 평평 (Button, Chip, StatCard …)
├── pages/        화면, 영역별 폴더 (dashboard/, meals/, workouts/, reports/, admin/)
├── hooks/ contexts/ layouts/ routes/ mocks/ types/ utils/
```

도메인별 `domains/{meal}/…` 폴더는 두지 않는다.

## Rationale

- **SSR/SEO가 필요 없다.** 모든 화면이 로그인 뒤. Next.js의 핵심 이점이 쓸모없고, Node 서버 런타임을 하나 더 운영해야 한다. 정적 빌드 → nginx가 v1 인프라와 같다.
- **팀의 최근 손맛이 React다.** feelm의 eslint·vitest·msw·openapi-typescript 파이프라인을 그대로 이식해 1주차 비용이 거의 없다.
- **웹은 1인 횡단 소유**다. GPT가 제안한 `domains/` 경계는 소유자가 여럿일 때 빛난다. 홈·리포트는 Meal+Workout+Coaching을 한 화면에 합치는 횡단 화면이라 도메인 폴더가 오히려 걸린다. `pages/{영역}/` 그룹핑으로 충분한 지역성이 나온다.
- 디자인은 모바일과 **공유하지 않는다**(모바일 = 감성적 consumer UX, 웹 = 데이터 대시보드). 토큰·브랜드만 공유.

## Alternatives Considered

- **Next.js**: SSR·파일 라우팅. 이 제품에선 이점 없음. 팀 경험 없음. 기각.
- **Vue 3 (v1 유지)**: v1 `api/`·store 코드 재사용. 그러나 v1 화면은 모바일 Primary 제품에 맞지 않고, feelm 팀 경험과 단절. 기각.
- **React + `domains/` 폴더(GPT식)**: 백엔드와 대칭. F 1인·횡단 화면에 과함. 후속에 웹 소유자가 늘면 재검토.

## Consequences

- 대시보드 화면 수 상한 **6**, 관리자 **3**. 넘으면 범위 조정(F가 3~5주차에 빠지므로).
- 관리자 화면은 같은 앱 안에서 `/admin/*` 라우트 + 역할 가드. 별도 앱 아님.
- 모델 버전 조회는 Spring 경유 또는 MLflow REST 직접 호출(ADR-11) — CORS·인증 경로를 1주차에 결정.
