from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.schemas.common import ErrorResponse
from app.services import vision_service

router = APIRouter(prefix="/ai/vision", tags=["AI Vision"])


@router.post(
    "",
    status_code=501,
    responses={501: {"model": ErrorResponse}, 503: {"model": ErrorResponse}},
)
def recognize() -> JSONResponse:
    """음식 사진 인식(골격). 요청·응답 스키마는 2주차 Vision 스토리에서 정한다."""
    if not vision_service.is_ready():
        return JSONResponse(
            status_code=503,
            content={"detail": "Vision 모델이 로드되지 않았습니다(MLflow 레지스트리·로컬 캐시 모두 없음)."},
        )
    return JSONResponse(
        status_code=501,
        content={"detail": "Vision 추론은 아직 구현되지 않았습니다(2주차 Vision 스토리)."},
    )
