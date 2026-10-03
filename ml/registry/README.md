# registry — MLflow 등록·승격

- 모델 이름: `nyamnyam-vision`(추론 서버 `VISION_MODEL_NAME` 기본값과 같다).
- 품질 게이트를 통과한 run의 모델을 등록하고 `Staging`으로 둔다.
- 사람이 관리자 웹(Spring이 MLflow REST를 프록시) 또는 MLflow UI에서 확인한 뒤 `Production`으로 승격한다.
- 추론 서버는 재기동 시 `Production` 버전을 받는다(`ai/app/model_loader.py`). 레지스트리 장애 시 마지막 로컬 캐시로 기동한다.

참고: MLflow 3은 stage 대신 alias(`@production` 등)를 권장하고 stage API는 폐기 예정 경고를 낸다.
ADR-11 문구대로 stage로 시작하며, alias 전환 여부는 결정 필요 항목이다.

할 일(MVP-3): 등록 스크립트, 승격 스크립트(수동 실행).
