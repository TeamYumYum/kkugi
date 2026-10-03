"""공통 응답 스키마. `ai/schemas` 변경은 Spring ↔ FastAPI 계약 변경이므로 E 리뷰 필수(ADR-09)."""

from typing import Literal

from pydantic import BaseModel


class VisionModelStatus(BaseModel):
    loaded: bool
    name: str | None = None
    version: str | None = None
    stage: str | None = None
    source: Literal["registry", "cache"] | None = None


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str
    claude_mode: Literal["mock", "live"]
    vision_model: VisionModelStatus


class ErrorResponse(BaseModel):
    detail: str
