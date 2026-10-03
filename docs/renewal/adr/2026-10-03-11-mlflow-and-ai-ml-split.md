# ADR-11: 추론(ai/)과 학습(ml/)을 분리하고, ML 아티팩트는 MLflow에

**Date:** 2026-10-03

## Context

MLOps 1회전이 MVP-3에 들어간다: 수정 데이터 적재 → 검수 → 데이터셋 → 학습 → 오프라인 평가 → 품질 게이트 → 모델 버전 → 추론 서버 교체.
v1의 `ai/`는 FastAPI 추론 서버(routers/services/schemas)이고, 학습 코드는 없었다.
모델 버전·지표·실험을 어디에 기록할지, 학습 코드를 어디에 둘지 정해야 한다. 담당은 E 1명.

## Decision

```
ai/                      FastAPI 추론 서버 (v1 구조 유지)
├── app/routers/         /ai/plan, /ai/routine, /ai/meal, /ai/vision, /ai/chat
├── app/services/        claude_service(단일 진입점) · vision_service · rag_service
├── app/schemas/
└── app/model_loader.py  MLflow 레지스트리에서 "Production" 스테이지 모델 로드

ml/                      학습·평가 (추론 서버 이미지에 포함되지 않음)
├── datasets/            수정 데이터 → 데이터셋 빌드 스크립트, 버전 태그
├── training/            fine-tune 스크립트
├── evaluation/          오프라인 평가 (top-1 acc, 혼동 행렬), 품질 게이트
└── registry/            MLflow 등록·스테이지 승격 스크립트
```

- **MLflow**를 docker compose 서비스로 추가한다(tracking + model registry, 백엔드 스토어는 MySQL 별도 스키마 또는 SQLite, 아티팩트는 로컬 볼륨).
- 업무 테이블(`meal_prediction`, `meal_correction`, `correction_review`)은 **Spring만 쓰기**(v1 원칙 유지). `ml/datasets`는 읽기만.
- 품질 게이트: 새 모델의 top-1 정확도 ≥ 현재 Production 모델. 통과 시 `Staging` → 수동 승인 후 `Production`.
- 관리자 웹의 모델 버전 조회는 **Spring이 MLflow REST를 프록시**한다(웹이 MLflow에 직접 붙지 않음 — 인증 경로 하나로).

## Rationale

- **추론과 학습을 한 이미지에 넣으면** 추론 서버에 PyTorch 학습 의존성·데이터셋 도구가 실린다. 분리하면 `ai/` 이미지가 가볍고 배포가 단순하다.
- **MLflow는 실험 추적 UI와 레지스트리를 공짜로** 준다. 자체 테이블로 하면 E가 UI까지 만들어야 한다. compose 서비스 1개 추가 비용이 더 싸다.
- ML 전용 테이블을 직접 설계하는 대안은 "FastAPI/ML이 업무 DB에 쓰기"라는 v1 원칙 예외를 만든다. MLflow를 쓰면 예외가 필요 없다.
- GPT 제안의 `ai/domains/{meal,coaching}/`는 E 1인 소유라 경계 이점이 없고, Claude 코칭이 여러 도메인을 섬겨 경계가 애매하다. v1 레이어 구조 유지가 이식 비용이 가장 낮다.

## Alternatives Considered

- **MySQL ML 전용 테이블(model_version, eval_run)**: 서비스 추가 없음. UI를 직접 만들어야 하고 실험 추적 없음. 기각.
- **파일 레지스트리(JSON + 모델 파일)**: 가장 단순. 관리자 웹 조회가 어색. 기각.
- **`ai/` 안에 `ml/` 포함**: 단순하지만 추론 이미지에 학습 의존성. 기각.
- **Kubeflow / Airflow / Feast**: 1회전 데모에 과함. 기각.

## Consequences

- compose에 `mlflow` 서비스 추가(E, 1주차). `ai/`는 기동 시 레지스트리에서 모델을 받는다 — 레지스트리 장애 시 **마지막 로컬 캐시**로 기동(폴백 규칙).
- Vision 베이스 모델 선정(자체 fine-tune vs 외부 API + 분류기)은 **미결** — 1주차 E가 데이터셋 확보 가능성 보고 결정. 외부 API를 쓰더라도 "예측 vs 수정" 적재와 평가 루프는 동일하게 성립한다.
- RAG(F703)는 `ai/app/services/rag_service.py`로 v1 코드 이식. 최후순위.
