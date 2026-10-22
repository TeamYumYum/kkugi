"""정답 라벨과 예측 JSONL로 채점한다.

    cd ml/evaluation
    python -m photo_meal.score --dataset data/labels.jsonl \
        --predictions results/preds.jsonl --out results/score.json

예측 JSONL은 사진 1장당 한 줄: `{"id": "0001", "detected_items": [...], "error": null}`.
예측이 없는 사진은 실패로 보고 빈 예측으로 채점한다(미검출로 잡힌다).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from photo_meal.dataset import DatasetError, load_dataset
from photo_meal.scoring import aggregate, by_kcal_source, by_kind, score_sample


def load_predictions(path: Path) -> dict[str, dict[str, Any]]:
    preds: dict[str, dict[str, Any]] = {}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        raw = raw.strip()
        if not raw:
            continue
        try:
            d = json.loads(raw)
        except json.JSONDecodeError as e:
            raise DatasetError(f"{path}:{lineno} JSON 파싱 실패 — {e}") from e
        preds[str(d["id"])] = d
    return preds


def _items(pred: dict[str, Any] | None) -> tuple[list[dict], str | None]:
    if pred is None:
        return [], "예측 없음"
    if pred.get("error"):
        return [], str(pred["error"])
    items = pred.get("detected_items", [])
    if not isinstance(items, list):
        return [], "detected_items가 배열이 아니다"
    return [p for p in items if isinstance(p, dict)], None


def score(dataset: Path, predictions: Path) -> dict[str, Any]:
    samples = load_dataset(dataset, check_images=False)
    preds = load_predictions(predictions)

    scored = []
    for sample in samples:
        items, error = _items(preds.get(sample.id))
        result = score_sample(sample, items)
        result["error"] = error
        scored.append(result)

    unknown = sorted(set(preds) - {s.id for s in samples})
    return {
        "dataset": str(dataset),
        "predictions": str(predictions),
        "unknown_prediction_ids": unknown,
        "metrics": aggregate(scored),
        "by_kind": by_kind(scored),
        "by_kcal_source": by_kcal_source(scored),
        "samples": scored,
    }


def _summary(result: dict[str, Any]) -> list[str]:
    m = result["metrics"]
    bias = m["total_kcal_bias"]
    lines = [
        f"사진 {m['photos']}장 (합계 전용 {m['total_only_photos']}장, 실패 {m['errors']}장)",
        f"음식명  P {m['name']['precision']}  R {m['name']['recall']}  F1 {m['name']['f1']}",
        (
            f"그램 MAPE {m['grams']['mape']}%   항목 kcal MAPE {m['item_kcal']['mape']}%   "
            f"밀도 MAPE {m['density']['mape']}%"
        ),
        (
            f"합계 kcal MAPE {m['total_kcal']['mape']}%   편향 {bias['mean']}%   "
            f"이중 계산 의심 {bias['over']}장"
        ),
    ]
    if result["unknown_prediction_ids"]:
        lines.append(f"경고: 라벨에 없는 예측 id {result['unknown_prediction_ids']}")
    return lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--predictions", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)

    # Windows 콘솔 기본 인코딩(cp949)에서 한글 출력이 깨지는 것을 막는다.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
        except (AttributeError, OSError):
            pass

    try:
        result = score(args.dataset, args.predictions)
    except DatasetError as e:
        print(f"오류: {e}", file=sys.stderr)
        return 2

    for line in _summary(result):
        print(line)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
