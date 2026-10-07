import asyncio
import json
import logging

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


def _live_env(monkeypatch):
    monkeypatch.setenv("CLAUDE_MOCK", "false")
    monkeypatch.setenv("GMS_API_KEY", "test-key")
    monkeypatch.setenv("GMS_BASE_URL", "https://gms.example.invalid")


def test_vision_mock_mode_returns_parseable_json_without_network():
    def fail(_: httpx.Request) -> httpx.Response:
        raise AssertionError("mock 모드에서 외부 호출이 일어났다")

    result = asyncio.run(
        claude_service.call_claude_vision(
            "aW1n", "image/jpeg", "음식을 찾아줘", transport=httpx.MockTransport(fail)
        )
    )

    assert json.loads(result)["detected_items"]


def test_vision_live_mode_sends_image_and_prompt(monkeypatch):
    _live_env(monkeypatch)
    seen: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["body"] = json.loads(request.content)
        return httpx.Response(200, json={"content": [{"type": "text", "text": "{}"}]})

    result = asyncio.run(
        claude_service.call_claude_vision(
            "aW1n", "image/png", "음식을 찾아줘", transport=httpx.MockTransport(handler)
        )
    )

    assert result == "{}"
    image, text = seen["body"]["messages"][0]["content"]
    assert image["source"] == {"type": "base64", "media_type": "image/png", "data": "aW1n"}
    assert text == {"type": "text", "text": "음식을 찾아줘"}
    assert seen["body"]["model"] == "claude-haiku-4-5-20251001"


def test_live_call_logs_tokens_and_cost(monkeypatch, caplog):
    _live_env(monkeypatch)

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "content": [{"type": "text", "text": "응답"}],
                "usage": {"input_tokens": 1_000_000, "output_tokens": 1_000_000},
            },
        )

    with caplog.at_level(logging.INFO, logger="ai.claude"):
        asyncio.run(
            claude_service.call_claude(
                "안녕",
                log_context={"operation": "test", "prompt": "로그에 남으면 안 된다"},
                transport=httpx.MockTransport(handler),
            )
        )

    payload = json.loads(caplog.records[-1].getMessage())
    assert payload["event"] == "claude_call"
    assert payload["kind"] == "text"
    assert payload["cost_usd"] == 6.0
    assert payload["operation"] == "test"
    assert "prompt" not in payload


def test_live_call_failure_is_logged_and_raised(monkeypatch, caplog):
    _live_env(monkeypatch)

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"error": "boom"})

    with (
        caplog.at_level(logging.INFO, logger="ai.claude"),
        pytest.raises(httpx.HTTPStatusError),
    ):
        asyncio.run(claude_service.call_claude("안녕", transport=httpx.MockTransport(handler)))

    payload = json.loads(caplog.records[-1].getMessage())
    assert payload["error"].startswith("HTTPStatusError")
    assert payload["cost_usd"] is None


def test_unknown_model_logs_without_cost(monkeypatch, caplog):
    _live_env(monkeypatch)

    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"content": [], "usage": {"input_tokens": 10, "output_tokens": 10}},
        )

    with caplog.at_level(logging.INFO, logger="ai.claude"):
        asyncio.run(
            claude_service.call_claude(
                "안녕", model="unknown-model", transport=httpx.MockTransport(handler)
            )
        )

    assert json.loads(caplog.records[-1].getMessage())["cost_usd"] is None


@pytest.mark.parametrize(
    "raw",
    [
        '{"a": 1}',
        '```json\n{"a": 1}\n```',
        '```JSON\n{"a": 1}\n```',
        '```\n{"a": 1}\n```',
        '분석 결과입니다.\n```json\n{"a": 1}\n```\n참고하세요.',
    ],
)
def test_strip_json_code_block(raw):
    assert json.loads(claude_service.strip_json_code_block(raw)) == {"a": 1}
