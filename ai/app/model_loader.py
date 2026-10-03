"""Vision 모델 로더(ADR-11).

기동 시 MLflow 레지스트리에서 `VISION_MODEL_STAGE`(기본 "Production") 버전을 받아
로컬 캐시에 저장한다. 레지스트리에 닿지 못하거나 등록된 모델이 없으면 **마지막 로컬 캐시**로
기동하고, 캐시도 없으면 `None`을 돌려준다. 어떤 경우에도 예외로 서버 기동을 막지 않는다.

이 단계에서는 아티팩트 경로·버전만 다룬다. 실제 모델 역직렬화(프레임워크별 로드)는
Vision 베이스 모델이 정해진 뒤(plan.md 9장) vision_service에서 붙인다.
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import tempfile
from collections.abc import Callable
from dataclasses import asdict, dataclass
from pathlib import Path

from app.config import Settings, load_settings

logger = logging.getLogger("ai.model_loader")

_META_FILE = "meta.json"
_CURRENT_DIR = "current"


@dataclass(frozen=True)
class LoadedModel:
    name: str
    version: str
    stage: str
    path: str
    source: str  # "registry" | "cache"


# (tracking_uri, name, stage, dst_dir) -> 다운로드한 버전 문자열. 등록된 버전이 없으면 None.
RegistryFetch = Callable[[str, str, str, Path], "str | None"]


def _fetch_from_mlflow(tracking_uri: str, name: str, stage: str, dst_dir: Path) -> str | None:
    # 레지스트리가 죽어 있을 때 기동이 오래 멈추지 않게 재시도·타임아웃을 줄인다.
    os.environ.setdefault("MLFLOW_HTTP_REQUEST_MAX_RETRIES", "0")
    os.environ.setdefault("MLFLOW_HTTP_REQUEST_TIMEOUT", "5")

    from mlflow import MlflowClient
    from mlflow.artifacts import download_artifacts

    client = MlflowClient(tracking_uri=tracking_uri, registry_uri=tracking_uri)
    # 결정 필요: MLflow 3은 stage 대신 alias를 권장한다. ADR-11 문구대로 stage를 쓴다.
    versions = client.get_latest_versions(name, stages=[stage])
    if not versions:
        return None
    version = str(versions[0].version)
    download_artifacts(
        artifact_uri=f"models:/{name}/{version}",
        dst_path=str(dst_dir),
        tracking_uri=tracking_uri,
    )
    return version


def _model_dir(cache_dir: Path, name: str) -> Path:
    return cache_dir / name


def _read_cache(cache_dir: Path, name: str) -> LoadedModel | None:
    model_dir = _model_dir(cache_dir, name)
    meta_path = model_dir / _META_FILE
    current = model_dir / _CURRENT_DIR
    if not meta_path.is_file() or not current.is_dir():
        return None
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        return LoadedModel(
            name=meta["name"],
            version=str(meta["version"]),
            stage=meta["stage"],
            path=str(current),
            source="cache",
        )
    except (OSError, ValueError, KeyError) as exc:
        logger.warning("모델 캐시 메타데이터를 읽지 못했다: %s", exc)
        return None


def _write_cache(cache_dir: Path, name: str, version: str, stage: str, downloaded: Path) -> Path:
    model_dir = _model_dir(cache_dir, name)
    model_dir.mkdir(parents=True, exist_ok=True)
    current = model_dir / _CURRENT_DIR
    if current.exists():
        shutil.rmtree(current)
    shutil.move(str(downloaded), str(current))
    meta = {"name": name, "version": version, "stage": stage}
    (model_dir / _META_FILE).write_text(json.dumps(meta, ensure_ascii=False), encoding="utf-8")
    return current


def load_model(
    settings: Settings | None = None,
    fetch: RegistryFetch = _fetch_from_mlflow,
) -> LoadedModel | None:
    """레지스트리 → 로컬 캐시 순으로 시도한다. 실패해도 예외를 던지지 않는다."""
    settings = settings or load_settings()
    cache_dir = Path(settings.model_cache_dir)
    name, stage = settings.vision_model_name, settings.vision_model_stage

    if settings.mlflow_tracking_uri:
        try:
            cache_dir.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(dir=cache_dir) as tmp:
                staging = Path(tmp) / "download"
                staging.mkdir()
                version = fetch(settings.mlflow_tracking_uri, name, stage, staging)
                if version is not None:
                    path = _write_cache(cache_dir, name, version, stage, staging)
                    logger.info("레지스트리에서 모델을 받았다: %s v%s (%s)", name, version, stage)
                    return LoadedModel(name, version, stage, str(path), "registry")
                logger.warning("레지스트리에 %s(%s) 버전이 없다. 로컬 캐시를 본다.", name, stage)
        except Exception as exc:  # noqa: BLE001 — 레지스트리 장애는 기동을 막지 않는다
            logger.warning("MLflow 레지스트리 조회 실패, 로컬 캐시로 폴백한다: %s", exc)
    else:
        logger.info("MLFLOW_TRACKING_URI가 비어 있어 레지스트리를 건너뛴다.")

    cached = _read_cache(cache_dir, name)
    if cached is None:
        logger.warning("사용할 Vision 모델이 없다(레지스트리·캐시 모두 없음).")
    return cached


def describe(model: LoadedModel | None) -> dict:
    """health 응답용 요약. 경로는 노출하지 않는다."""
    if model is None:
        return {"loaded": False}
    data = asdict(model)
    data.pop("path")
    return {"loaded": True, **data}
