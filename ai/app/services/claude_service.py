"""Claude 호출의 단일 진입점(ADR-11). 모든 router·service는 이 모듈의 `call_claude`만 쓴다.

- `CLAUDE_MOCK=true`(기본): 외부 호출 없이 고정 문구를 돌려준다.
- `CLAUDE_MOCK=false`: SSAFY GMS(Anthropic Messages API 호환)로 호출한다.
  `GMS_API_KEY`·`GMS_BASE_URL`이 없으면 조용히 mock으로 떨어지지 않고 명확한 오류를 낸다.

v1 이식 예정: 비용·지연 구조화 로그, Vision 호출(`call_claude_vision`), JSON 코드블록 정리,
도메인별 프롬프트는 각 스토리에서 v1 `ai/app/services/claude_service.py`를 기준으로 옮긴다.
"""

import httpx

from app.config import Settings, load_settings

MOCK_RESPONSE = "[mock] 냠냠코치 응답입니다. CLAUDE_MOCK=false로 실제 호출을 켭니다."


class ClaudeConfigError(RuntimeError):
    """실제 호출 모드인데 필수 설정이 없을 때."""


def is_mock(settings: Settings | None = None) -> bool:
    return (settings or load_settings()).claude_mock


async def call_claude(
    prompt: str,
    *,
    max_tokens: int = 1000,
    settings: Settings | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> str:
    """프롬프트 하나를 보내고 응답 본문 텍스트를 돌려준다."""
    settings = settings or load_settings()
    if settings.claude_mock:
        return MOCK_RESPONSE

    if not settings.gms_api_key or not settings.gms_base_url:
        raise ClaudeConfigError(
            "CLAUDE_MOCK=false인데 GMS_API_KEY 또는 GMS_BASE_URL이 비어 있습니다. "
            "infra/.env(또는 셸 환경)에 값을 넣거나 CLAUDE_MOCK=true로 두세요."
        )

    async with httpx.AsyncClient(
        base_url=settings.gms_base_url, timeout=30.0, transport=transport
    ) as client:
        response = await client.post(
            "/v1/messages",
            headers={
                "x-api-key": settings.gms_api_key,
                "anthropic-version": settings.anthropic_version,
                "content-type": "application/json",
            },
            json={
                "model": settings.claude_model,
                "max_tokens": max_tokens,
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        response.raise_for_status()
        body = response.json()

    return "".join(
        block.get("text", "") for block in body.get("content", []) if block.get("type") == "text"
    )
