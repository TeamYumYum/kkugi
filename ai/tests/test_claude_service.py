import asyncio

import httpx
import pytest

from app.config import load_settings
from app.services import claude_service


def test_mock_mode_returns_canned_text_without_network():
    def fail(_: httpx.Request) -> httpx.Response:
        raise AssertionError("mock 모드에서 외부 호출이 일어났다")

    result = asyncio.run(
        claude_service.call_claude("안녕", transport=httpx.MockTransport(fail))
    )

    assert result == claude_service.MOCK_RESPONSE


def test_live_mode_without_key_fails_clearly(monkeypatch):
    monkeypatch.setenv("CLAUDE_MOCK", "false")

    with pytest.raises(claude_service.ClaudeConfigError, match="GMS_API_KEY"):
        asyncio.run(claude_service.call_claude("안녕"))


def test_live_mode_sends_messages_request(monkeypatch):
    monkeypatch.setenv("CLAUDE_MOCK", "false")
    monkeypatch.setenv("GMS_API_KEY", "test-key")
    monkeypatch.setenv("GMS_BASE_URL", "https://gms.example.invalid")
    seen: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["path"] = request.url.path
        seen["key"] = request.headers["x-api-key"]
        return httpx.Response(200, json={"content": [{"type": "text", "text": "실제 응답"}]})

    result = asyncio.run(
        claude_service.call_claude(
            "안녕", settings=load_settings(), transport=httpx.MockTransport(handler)
        )
    )

    assert result == "실제 응답"
    assert seen == {"path": "/v1/messages", "key": "test-key"}
