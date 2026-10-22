"""평가셋(labels.jsonl) 로드. 사진 1장당 한 줄, 스키마는 `ml/evaluation/README.md`."""

from __future__ import annotations

import json
import warnings
from dataclasses import dataclass, field
from pathlib import Path

# kcal 정답을 어디서 얻었는지. DB에서 베낀 정답으로 같은 DB를 쓰는 방식을 채점하면
# 순환논증이 되므로 지표를 출처별로 갈라 본다.
KCAL_SOURCES = {"package", "scale+db", "mfds"}

MEDIA_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


class DatasetError(ValueError):
    """평가셋 형식 오류. 메시지에 파일:줄 번호를 담는다."""


@dataclass
class GtItem:
    name: str
    grams: float
    kcal: float | None = None
    kcal_source: str | None = None
    aliases: list[str] = field(default_factory=list)


@dataclass
class Sample:
    id: str
    image: Path
    meal_type: str
    kind: str
    items: list[GtItem]
    note: str = ""
    # 항목별 정답 없이 사진 전체 합계만 아는 샘플. 반찬칸이 나뉜 도시락은 포장이
    # 총 내용량·총 열량만 주므로 항목별 그램을 알 수 없다. 이런 샘플은 항목 지표에서
    # 빠지고 사진 합계 kcal 지표에만 기여한다 — 앱이 보여주는 숫자가 총 칼로리다.
    total_only: bool = False
    total_kcal_gt: float | None = None
    total_grams_gt: float | None = None

    @property
    def total_kcal(self) -> float | None:
        """total_only면 명시된 합계를, 아니면 항목 합을 낸다."""
        if self.total_only:
            return self.total_kcal_gt
        if not self.items or any(i.kcal is None for i in self.items):
            return None
        return sum(i.kcal for i in self.items)  # type: ignore[misc]


def _optional_float(value: object) -> float | None:
    return None if value is None else float(value)  # type: ignore[arg-type]


def load_dataset(path: Path, *, check_images: bool = True) -> list[Sample]:
    """labels.jsonl을 읽는다. 빈 줄과 `//` 주석 줄은 건너뛴다.

    check_images=False면 사진 파일 존재를 확인하지 않는다(예측이 이미 있는 채점 전용).
    """
    if not path.exists():
        raise DatasetError(f"평가셋이 없다 — {path}")

    base = path.parent
    samples: list[Sample] = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        raw = raw.strip()
        if not raw or raw.startswith("//"):
            continue
        where = f"{path}:{lineno}"
        try:
            d = json.loads(raw)
        except json.JSONDecodeError as e:
            raise DatasetError(f"{where} JSON 파싱 실패 — {e}") from e

        image = (base / d["image"]).resolve()
        if image.suffix.lower() not in MEDIA_TYPES:
            raise DatasetError(f"{where} 지원하지 않는 확장자 — {image.name}")
        if check_images and not image.exists():
            raise DatasetError(f"{where} 사진 없음 — {image}")

        total_only = bool(d.get("total_only", False))
        if total_only and d.get("total_kcal") is None:
            raise DatasetError(f"{where} total_only 샘플에는 total_kcal이 필요하다")

        items = []
        for i in d.get("items", []):
            src = i.get("kcal_source")
            if src is not None and src not in KCAL_SOURCES:
                raise DatasetError(
                    f"{where} kcal_source가 '{src}'다. {sorted(KCAL_SOURCES)} 중 하나여야 한다"
                )
            if i.get("kcal") is not None and src is None:
                warnings.warn(
                    f"{where} '{i['name']}'에 kcal은 있는데 kcal_source가 없다",
                    stacklevel=2,
                )
            items.append(
                GtItem(
                    name=i["name"],
                    grams=float(i["grams"]),
                    kcal=_optional_float(i.get("kcal")),
                    kcal_source=src,
                    aliases=list(i.get("aliases", [])),
                )
            )
        if not total_only and not items:
            raise DatasetError(f"{where} items가 비었다 (total_only도 아니다)")

        samples.append(
            Sample(
                id=str(d["id"]),
                image=image,
                meal_type=d["meal_type"],
                kind=d.get("kind", "single"),
                items=items,
                note=d.get("note", ""),
                total_only=total_only,
                total_kcal_gt=_optional_float(d.get("total_kcal")),
                total_grams_gt=_optional_float(d.get("total_grams")),
            )
        )

    if not samples:
        raise DatasetError(f"{path}: 유효한 샘플이 없다")
    return samples
