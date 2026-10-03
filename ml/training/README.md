# training — 학습

사전학습 모델 fine-tune 스크립트를 둔다(plan.md 8장: 소규모 데이터셋으로 1회전).

- 입력: `datasets/`가 만든 데이터셋 버전.
- 기록: MLflow run에 하이퍼파라미터·데이터셋 버전·지표·모델 아티팩트를 남긴다(`MLFLOW_TRACKING_URI`).
- 베이스 모델과 프레임워크는 미결이다(plan.md 9장, 1주차 E 결정). 외부 Vision API를 쓰더라도
  "예측 vs 수정" 적재와 평가 루프는 같게 유지한다(ADR-11).

할 일(MVP-3): 학습 스크립트, 재현용 설정 파일, GPU 없는 환경에서의 실행 방법.
