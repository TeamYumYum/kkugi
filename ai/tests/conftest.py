import pytest


@pytest.fixture(autouse=True)
def isolated_env(monkeypatch, tmp_path):
    """개인 셸 환경의 값이 테스트에 섞이지 않게 관련 변수를 고정한다."""
    for name in ("GMS_API_KEY", "GMS_BASE_URL", "CLAUDE_MODEL", "MLFLOW_TRACKING_URI"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("CLAUDE_MOCK", "true")
    monkeypatch.setenv("MODEL_CACHE_DIR", str(tmp_path / "model-cache"))
    yield
