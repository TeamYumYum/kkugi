"""아직 구현하지 않은 AI 엔드포인트(ADR-11 경로만 확보). 모두 501을 돌려준다.

각 도메인 스토리에서 이 파일의 항목을 지우고 자기 router 파일(`meal.py` 등)과
`app/schemas/<도메인>.py`를 만든다. v1 이식 예정.
"""

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.schemas.common import ErrorResponse

# (경로, 태그, 담당 스토리 설명)
_STUBS = [
    ("/ai/meal", "AI Meal", "식사 분석·추천(Meal 스토리)"),
    ("/ai/routine", "AI Routine", "루틴 생성·조정(Workout·Coaching 스토리)"),
    ("/ai/plan", "AI Plan", "목표·식단 계획(Coaching 스토리)"),
    ("/ai/chat", "AI Chat", "RAG 채팅(최후순위, ADR-13 SSE)"),
]


def _make_router(prefix: str, tag: str, story: str) -> APIRouter:
    router = APIRouter(prefix=prefix, tags=[tag])
    segment = prefix.rsplit("/", 1)[-1]

    # operation_id를 경로별로 줘서 OpenAPI operationId가 겹치지 않게 한다.
    @router.post(
        "",
        status_code=501,
        responses={501: {"model": ErrorResponse}},
        operation_id=f"{segment}_not_implemented",
    )
    def not_implemented() -> JSONResponse:
        return JSONResponse(
            status_code=501,
            content={"detail": f"{prefix}는 아직 구현되지 않았습니다 — {story}."},
        )

    return router


routers = [_make_router(*stub) for stub in _STUBS]
