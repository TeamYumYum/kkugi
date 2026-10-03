"""음식 사진 인식 서비스(골격).

기동 시 model_loader가 고른 모델을 보관한다. 추론은 Vision 베이스 모델 선정
(plan.md 9장, 1주차 E 결정) 뒤 2주차 스토리에서 구현한다.
"""

from app.model_loader import LoadedModel

_model: LoadedModel | None = None


def set_model(model: LoadedModel | None) -> None:
    global _model
    _model = model


def current_model() -> LoadedModel | None:
    return _model


def is_ready() -> bool:
    return _model is not None
