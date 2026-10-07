"""Claude 호출의 단일 진입점(ADR-11). 모든 router·service는 이 모듈의 함수만 쓴다.

- `CLAUDE_MOCK=true`(기본): 외부 호출 없이 고정 응답을 돌려준다.
- `CLAUDE_MOCK=false`: SSAFY GMS(Anthropic Messages API 호환)로 호출한다.
  `GMS_API_KEY`·`GMS_BASE_URL`이 없으면 조용히 mock으로 떨어지지 않고 명확한 오류를 낸다.
- 실제 호출 1건마다 지연·토큰·비용을 구조화 로그(`ai.claude`)로 남긴다.

v1 `ai/app/services/claude_service.py`에서 이식했다. 도메인별 프롬프트와 mock 문구는
각 스토리에서 해당 router·service 쪽으로 옮긴다.
"""

import json
import logging
import time

import httpx

from app.config import Settings, load_settings

logger = logging.getLogger("ai.claude")

MOCK_RESPONSE = "[mock] 냠냠코치 응답입니다. CLAUDE_MOCK=false로 실제 호출을 켭니다."

# 음식 사진 인식 mock 응답(v1 형식). Meal 응답 계약이 정해지면 그 형식에 맞춘다.
MOCK_VISION_RESPONSE = json.dumps(
    {
        "detected_items": [
            {
                "name": "닭가슴살",
                "estimated_grams": 150.0,
                "kcal": 165.0,
                "protein_g": 31.0,
                "carb_g": 0.0,
                "fat_g": 3.6,
            },
            {
                "name": "현미밥",
                "estimated_grams": 200.0,
                "kcal": 278.0,
                "protein_g": 5.6,
                "carb_g": 58.0,
                "fat_g": 1.6,
            },
        ],
        "ai_comment": "[mock] 고단백 균형 식단이네요! 단백질 섭취가 훌륭합니다.",
    },
    ensure_ascii=False,
)

# 모델별 $/1M 토큰 단가 (input, output). 확인된 모델만 등록 — 없는 모델은 cost_usd=None으로 로깅.
# 출처: platform.claude.com/docs/en/about-claude/pricing (2026-09-11 확인, v1)
_PRICING_USD_PER_1M: dict[str, tuple[float, float]] = {
    "claude-haiku-4-5-20251001": (1.00, 5.00),
    "claude-opus-4-5-20251101": (5.00, 25.00),
}

# 로그에 실어도 되는 호출 맥락 키. 프롬프트·개인정보가 로그로 새지 않게 허용 목록으로 둔다.
_LOG_CONTEXT_KEYS = ("operation", "coaching_run_id")


class ClaudeConfigError(RuntimeError):
    """실제 호출 모드인데 필수 설정이 없을 때."""


def is_mock(settings: Settings | None = None) -> bool:
    return (settings or load_settings()).claude_mock


def strip_json_code_block(raw: str) -> str:
    """Claude 응답에서 ```json ... ``` 코드블록 마커를 제거하고 JSON 본문만 반환한다."""
    cleaned = raw.strip()
    if "```" in cleaned:
        parts = cleaned.split("```")
        cleaned = parts[1] if len(parts) > 1 else cleaned
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    return cleaned.strip()


async def call_claude(
    prompt: str,
    *,
    model: str | None = None,
    max_tokens: int = 1000,
    log_context: dict[str, str] | None = None,
    settings: Settings | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> str:
    """프롬프트 하나를 보내고 응답 본문 텍스트를 돌려준다."""
    settings = settings or load_settings()
    if settings.claude_mock:
        return MOCK_RESPONSE

    return await _post_messages(
        kind="text",
        content=prompt,
        model=model or settings.claude_model,
        max_tokens=max_tokens,
        timeout=30.0,
        log_context=log_context,
        settings=settings,
        transport=transport,
    )


async def call_claude_vision(
    image_base64: str,
    media_type: str,
    prompt: str,
    *,
    model: str | None = None,
    max_tokens: int = 800,
    log_context: dict[str, str] | None = None,
    settings: Settings | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> str:
    """이미지(base64) 한 장과 프롬프트를 보내고 응답 본문 텍스트를 돌려준다."""
    settings = settings or load_settings()
    if settings.claude_mock:
        return MOCK_VISION_RESPONSE

    content = [
        {
            "type": "image",
            "source": {"type": "base64", "media_type": media_type, "data": image_base64},
        },
        {"type": "text", "text": prompt},
    ]
    return await _post_messages(
        kind="vision",
        content=content,
        model=model or settings.claude_model,
        max_tokens=max_tokens,
        timeout=25.0,
        log_context=log_context,
        settings=settings,
        transport=transport,
    )


async def _post_messages(
    *,
    kind: str,
    content: str | list[dict],
    model: str,
    max_tokens: int,
    timeout: float,
    log_context: dict[str, str] | None,
    settings: Settings,
    transport: httpx.AsyncBaseTransport | None,
) -> str:
    if not settings.gms_api_key or not settings.gms_base_url:
        raise ClaudeConfigError(
            "CLAUDE_MOCK=false인데 GMS_API_KEY 또는 GMS_BASE_URL이 비어 있습니다. "
            "infra/.env(또는 셸 환경)에 값을 넣거나 CLAUDE_MOCK=true로 두세요."
        )

    start = time.monotonic()
    try:
        async with httpx.AsyncClient(
            base_url=settings.gms_base_url, timeout=timeout, transport=transport
        ) as client:
            response = await client.post(
                "/v1/messages",
                headers={
                    "x-api-key": settings.gms_api_key,
                    "anthropic-version": settings.anthropic_version,
                    "content-type": "application/json",
                },
                json={
                    "model": model,
                    "max_tokens": max_tokens,
                    "messages": [{"role": "user", "content": content}],
                },
            )
            response.raise_for_status()
    except Exception as e:
        _log_claude_call(
            kind=kind,
            model=model,
            latency_ms=(time.monotonic() - start) * 1000,
            usage=None,
            error=f"{type(e).__name__}: {e}",
            log_context=log_context,
        )
        raise

    body = response.json()
    _log_claude_call(
        kind=kind,
        model=model,
        latency_ms=(time.monotonic() - start) * 1000,
        usage=body.get("usage"),
        log_context=log_context,
    )
    return "".join(
        block.get("text", "") for block in body.get("content", []) if block.get("type") == "text"
    )


def _log_claude_call(
    *,
    kind: str,
    model: str,
    latency_ms: float,
    usage: dict | None,
    error: str | None = None,
    log_context: dict[str, str] | None = None,
) -> None:
    """Claude 호출 1건의 latency/토큰/비용을 구조화 로그로 남긴다."""
    input_tokens = (usage or {}).get("input_tokens", 0)
    output_tokens = (usage or {}).get("output_tokens", 0)

    pricing = _PRICING_USD_PER_1M.get(model)
    cost_usd = None
    if pricing and usage is not None:
        cost_usd = round(
            input_tokens / 1_000_000 * pricing[0] + output_tokens / 1_000_000 * pricing[1],
            6,
        )

    payload = {
        "event": "claude_call",
        "kind": kind,  # "text" | "vision"
        "model": model,
        "latency_ms": round(latency_ms, 1),
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": cost_usd,
        "error": error,
    }
    if log_context:
        payload.update({key: log_context[key] for key in _LOG_CONTEXT_KEYS if key in log_context})
    logger.info(json.dumps(payload, ensure_ascii=False))
