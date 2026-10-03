# ml — 학습·평가·모델 등록

음식 Vision 모델의 MLOps 1회전(plan.md J3, MVP-3)을 담는다. 추론 서버(`ai/`) 이미지에 포함되지 않는다
([ADR-11](../docs/adr/0011-mlflow-and-ai-ml-split.md)). 홈 담당은 E.

```
수정 데이터(Spring 업무 DB, 읽기 전용)
  → datasets/   데이터셋 빌드·버전 태그
  → training/   fine-tune, MLflow에 실험 기록
  → evaluation/ 오프라인 평가 · 품질 게이트
  → registry/   MLflow 등록 → Staging → (수동 승인) → Production
  → ai/ model_loader가 Production 버전을 로드
```

| 디렉터리 | 내용 |
|---|---|
| [datasets/](datasets/README.md) | 수정 데이터 → 학습용 데이터셋 |
| [training/](training/README.md) | 학습 스크립트 |
| [evaluation/](evaluation/README.md) | top-1 정확도·혼동 행렬, 품질 게이트 |
| [registry/](registry/README.md) | MLflow 등록·승격 |

## 규칙

- 업무 테이블(`meal_prediction`·`meal_correction`·`correction_review`)은 **읽기만** 한다. 쓰기는 Spring만.
- 모델·지표·실험은 MLflow에 남긴다(compose의 `mlflow` 서비스, `infra/README.md`).
- 데이터셋 원본·모델 파일은 git에 커밋하지 않는다.
- 1주차에는 코드가 없다. Vision 베이스 모델(자체 fine-tune vs 외부 API + 분류기)이 정해진 뒤 채운다(plan.md 9장).

## 의존성

[`requirements.txt`](requirements.txt)는 자리만 잡아 둔 초안이다. 학습 프레임워크(PyTorch 등)는 베이스 모델 결정 후 고정한다.
