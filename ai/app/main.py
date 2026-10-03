"""냠냠코치 AI 추론 서버. Spring만 내부 HTTP(`/ai/**`)로 호출한다(plan.md 5.2)."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.model_loader import load_model
from app.routers import health, stubs, vision
from app.services import vision_service

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    # 레지스트리 장애·모델 없음이어도 기동은 계속한다(ADR-11 폴백 규칙).
    vision_service.set_model(load_model())
    yield


app = FastAPI(
    title="냠냠코치 AI Server",
    description="Spring Boot → FastAPI 내부 추론 API (계약: contracts/ai-openapi.json, ADR-09)",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health.router)
app.include_router(vision.router)
for stub_router in stubs.routers:
    app.include_router(stub_router)
