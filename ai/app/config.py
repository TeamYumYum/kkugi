"""환경 변수 설정. 값은 `infra/.env`(compose) 또는 개인 셸 환경에서 주입한다.

Secret(`GMS_API_KEY`)의 기본값은 두지 않는다(docs/secret-environment-variables.md).
"""

import os
from dataclasses import dataclass


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_str(name: str, default: str = "") -> str:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    return raw.strip()


@dataclass(frozen=True)
class Settings:
    # Claude(SSAFY GMS 경유). 기본은 mock — 크레딧을 쓰지 않는다.
    claude_mock: bool
    gms_api_key: str
    gms_base_url: str
    claude_model: str
    anthropic_version: str

    # MLflow 레지스트리(ADR-11). 비어 있으면 레지스트리를 건너뛰고 로컬 캐시만 본다.
    mlflow_tracking_uri: str
    vision_model_name: str
    vision_model_stage: str
    model_cache_dir: str


def load_settings() -> Settings:
    return Settings(
        claude_mock=_env_bool("CLAUDE_MOCK", True),
        gms_api_key=_env_str("GMS_API_KEY"),
        gms_base_url=_env_str("GMS_BASE_URL"),
        claude_model=_env_str("CLAUDE_MODEL", "claude-haiku-4-5-20251001"),
        anthropic_version=_env_str("ANTHROPIC_VERSION", "2023-06-01"),
        mlflow_tracking_uri=_env_str("MLFLOW_TRACKING_URI"),
        vision_model_name=_env_str("VISION_MODEL_NAME", "nyamnyam-vision"),
        vision_model_stage=_env_str("VISION_MODEL_STAGE", "Production"),
        model_cache_dir=_env_str("MODEL_CACHE_DIR", "model-cache"),
    )
