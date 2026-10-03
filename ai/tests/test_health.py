from fastapi.testclient import TestClient

from app.main import app


def test_health_reports_ok_with_mock_claude_and_no_model():
    with TestClient(app) as client:
        response = client.get("/ai/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["claude_mode"] == "mock"
    assert body["vision_model"] == {
        "loaded": False,
        "name": None,
        "version": None,
        "stage": None,
        "source": None,
    }


def test_vision_says_model_not_loaded():
    with TestClient(app) as client:
        response = client.post("/ai/vision")

    assert response.status_code == 503
    assert "로드되지 않았습니다" in response.json()["detail"]


def test_stub_endpoints_return_501():
    with TestClient(app) as client:
        for path in ("/ai/meal", "/ai/routine", "/ai/plan", "/ai/chat"):
            response = client.post(path)
            assert response.status_code == 501, path
            assert "아직 구현되지 않았습니다" in response.json()["detail"]


def test_openapi_operation_ids_are_unique():
    schema = app.openapi()
    ids = [op["operationId"] for item in schema["paths"].values() for op in item.values()]
    assert len(ids) == len(set(ids))
