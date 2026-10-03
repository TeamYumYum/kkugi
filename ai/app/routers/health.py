from fastapi import APIRouter

from app.model_loader import describe
from app.schemas.common import HealthResponse, VisionModelStatus
from app.services import claude_service, vision_service

router = APIRouter(prefix="/ai", tags=["Health"])


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="nyamnyam-ai",
        claude_mode="mock" if claude_service.is_mock() else "live",
        vision_model=VisionModelStatus(**describe(vision_service.current_model())),
    )
