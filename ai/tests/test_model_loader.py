from pathlib import Path

from app.config import load_settings
from app.model_loader import load_model


def _registry_down(*_args):
    raise ConnectionError("mlflow unreachable")


def _registry_with_v3(_uri: str, _name: str, _stage: str, dst: Path) -> str:
    (dst / "weights.bin").write_bytes(b"v3")
    return "3"


def test_no_tracking_uri_and_no_cache_returns_none():
    assert load_model(load_settings(), fetch=_registry_down) is None


def test_registry_down_without_cache_returns_none(monkeypatch):
    monkeypatch.setenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")

    assert load_model(load_settings(), fetch=_registry_down) is None


def test_registry_download_is_cached_then_used_as_fallback(monkeypatch):
    monkeypatch.setenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")
    settings = load_settings()

    first = load_model(settings, fetch=_registry_with_v3)
    assert first is not None
    assert (first.source, first.version, first.stage) == ("registry", "3", "Production")
    assert (Path(first.path) / "weights.bin").read_bytes() == b"v3"

    fallback = load_model(settings, fetch=_registry_down)
    assert fallback is not None
    assert (fallback.source, fallback.version) == ("cache", "3")
    assert (Path(fallback.path) / "weights.bin").read_bytes() == b"v3"


def test_registry_without_production_version_falls_back_to_cache(monkeypatch):
    monkeypatch.setenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")
    settings = load_settings()
    load_model(settings, fetch=_registry_with_v3)

    result = load_model(settings, fetch=lambda *_: None)

    assert result is not None
    assert (result.source, result.version) == ("cache", "3")


def test_real_mlflow_client_unreachable_does_not_raise(monkeypatch):
    # 실제 MLflow 클라이언트로 닿지 않는 주소를 조회해도 예외 없이 폴백한다.
    monkeypatch.setenv("MLFLOW_TRACKING_URI", "http://127.0.0.1:9")

    assert load_model(load_settings()) is None
