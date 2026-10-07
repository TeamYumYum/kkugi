"""예측과 정답을 맞춰 채점하고 집계한다. 모델 호출 없는 순수 계산.

예측 항목 형식은 v1 Vision 응답의 `detected_items` 원소를 따른다:
`{"name": str, "estimated_grams": 숫자, "kcal": 숫자, ...}`.
"""

from __future__ import annotations

import statistics
from typing import Any

from photo_meal.dataset import GtItem, Sample

# 예측 합계가 정답보다 이 % 넘게 크면 이중 계산을 의심한다. 요리 전체와 구성 재료를
# 동시에 출력하면 합계가 2배 근처로 간다.
DOUBLE_COUNT_BIAS = 50.0


# ── 음식명 매칭 ──────────────────────────────────────────────────────────────


def normalize(name: str) -> str:
    """괄호 안 조리법과 공백을 떼고 소문자로 만든다. "닭가슴살(구이)" == "닭 가슴살"."""
    out: list[str] = []
    depth = 0
    for ch in name:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth = max(0, depth - 1)
        elif depth == 0 and not ch.isspace():
            out.append(ch.lower())
    return "".join(out)


def match_score(gt: GtItem, pred_name: str) -> int:
    """2 = 이름/별칭 일치, 1 = 부분 문자열 포함, 0 = 불일치."""
    p = normalize(pred_name)
    if not p:
        return 0
    candidates = {normalize(gt.name)} | {normalize(a) for a in gt.aliases}
    candidates.discard("")
    if p in candidates:
        return 2
    if any(c in p or p in c for c in candidates):
        return 1
    return 0


def assign(gt_items: list[GtItem], preds: list[dict]) -> list[tuple[int, int, int]]:
    """정답과 예측을 점수 높은 순으로 1:1 배정한다. (gt_idx, pred_idx, score) 목록."""
    pairs: list[tuple[int, int, int]] = []
    for gi, gt in enumerate(gt_items):
        for pi, pred in enumerate(preds):
            s = match_score(gt, str(pred.get("name", "")))
            if s > 0:
                pairs.append((s, gi, pi))
    pairs.sort(key=lambda t: -t[0])

    used_gt: set[int] = set()
    used_pred: set[int] = set()
    matched: list[tuple[int, int, int]] = []
    for s, gi, pi in pairs:
        if gi in used_gt or pi in used_pred:
            continue
        used_gt.add(gi)
        used_pred.add(pi)
        matched.append((gi, pi, s))
    return matched


# ── 오차 ─────────────────────────────────────────────────────────────────────


def ape(pred: float, truth: float) -> float | None:
    """절대 백분율 오차. 정답이 0 이하면 정의되지 않는다."""
    if truth <= 0:
        return None
    return abs(pred - truth) / truth * 100.0


def density(kcal: float | None, grams: float | None) -> float | None:
    """kcal/g. 그램이 0 이하거나 kcal이 없으면 정의되지 않는다."""
    if kcal is None or grams is None or grams <= 0:
        return None
    return kcal / grams


def _num(value: Any) -> float:
    """모델이 문자열이나 null로 준 숫자를 안전하게 float으로 만든다."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _round(value: float | None, digits: int = 2) -> float | None:
    return None if value is None else round(value, digits)


def _total(sample: Sample, preds: list[dict]) -> dict[str, Any]:
    gt_total = sample.total_kcal
    pred_total = sum(_num(p.get("kcal")) for p in preds)
    total_ape = ape(pred_total, gt_total) if gt_total is not None else None
    # 부호 있는 오차. 절대값만 보면 과대·과소가 섞여 이중 계산을 식별할 수 없다.
    bias = (pred_total - gt_total) / gt_total * 100.0 if gt_total else None
    return {
        "total_kcal_ape": _round(total_ape),
        "total_kcal_bias": _round(bias),
        "gt_total_kcal": gt_total,
        "pred_total_kcal": round(pred_total, 1),
    }


# ── 샘플 채점 ────────────────────────────────────────────────────────────────


def score_sample(sample: Sample, preds: list[dict]) -> dict[str, Any]:
    if sample.total_only:
        return _score_total_only(sample, preds)

    matched = assign(sample.items, preds)
    grams_apes: list[float] = []
    kcal_apes: list[float] = []
    density_apes: list[float] = []
    detail: list[dict[str, Any]] = []

    for gi, pi, s in matched:
        gt = sample.items[gi]
        pred = preds[pi]
        pred_grams = _num(pred.get("estimated_grams"))
        pred_kcal = _num(pred.get("kcal"))

        g_ape = ape(pred_grams, gt.grams)
        k_ape = ape(pred_kcal, gt.kcal) if gt.kcal is not None else None
        # 밀도(kcal/g) 오차 = 그램 오차를 소거한 순수 계수 오차.
        # kcal 오차는 그램 오차와 계수 오차의 합이라 부호가 반대면 상쇄된다.
        gt_density = density(gt.kcal, gt.grams)
        pred_density = density(pred_kcal, pred_grams)
        d_ape = (
            None if gt_density is None or pred_density is None else ape(pred_density, gt_density)
        )

        if g_ape is not None:
            grams_apes.append(g_ape)
        if k_ape is not None:
            kcal_apes.append(k_ape)
        if d_ape is not None:
            density_apes.append(d_ape)
        detail.append(
            {
                "gt_name": gt.name,
                "pred_name": pred.get("name"),
                "match": "exact" if s == 2 else "partial",
                "gt_grams": gt.grams,
                "pred_grams": pred.get("estimated_grams"),
                "grams_ape": _round(g_ape),
                "gt_kcal": gt.kcal,
                "pred_kcal": pred.get("kcal"),
                "kcal_ape": _round(k_ape),
                "kcal_source": gt.kcal_source,
                "density_ape": _round(d_ape),
            }
        )

    matched_gt = {gi for gi, _, _ in matched}
    matched_pred = {pi for _, pi, _ in matched}
    return {
        "id": sample.id,
        "kind": sample.kind,
        "tp": len(matched),
        "exact": sum(1 for _, _, s in matched if s == 2),
        "fp": len(preds) - len(matched),
        "fn": len(sample.items) - len(matched),
        "grams_apes": grams_apes,
        "kcal_apes": kcal_apes,
        "density_apes": density_apes,
        **_total(sample, preds),
        # 어떤 음식을 놓치고 무엇을 지어내는지가 개선 단서다
        "missed": [it.name for i, it in enumerate(sample.items) if i not in matched_gt],
        "spurious": [p.get("name") for i, p in enumerate(preds) if i not in matched_pred],
        "items": detail,
        # 원시 예측을 남긴다. 라벨·aliases를 고쳐도 모델 재호출 없이 다시 채점할 수 있다.
        "preds": preds,
    }


def _score_total_only(sample: Sample, preds: list[dict]) -> dict[str, Any]:
    """항목 지표는 비우고 사진 합계 kcal만 채점한다.

    tp/fp/fn을 0으로 둔다. 항목 정답이 없는데 예측을 과검출로 세면, 반찬을 제대로
    감지한 모델을 라벨이 거칠다는 이유로 벌주게 된다.
    """
    return {
        "id": sample.id,
        "kind": sample.kind,
        "total_only": True,
        "tp": 0,
        "exact": 0,
        "fp": 0,
        "fn": 0,
        "grams_apes": [],
        "kcal_apes": [],
        "density_apes": [],
        **_total(sample, preds),
        "missed": [],
        "spurious": [],
        "items": [],
        "preds": preds,
    }


# ── 집계 ─────────────────────────────────────────────────────────────────────


def _stats(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"n": 0, "mape": None, "median": None, "p90": None}
    s = sorted(values)
    return {
        "n": len(s),
        "mape": round(statistics.fmean(s), 2),
        "median": round(statistics.median(s), 2),
        "p90": round(s[min(len(s) - 1, int(len(s) * 0.9))], 2),
    }


def _bias_stats(scored: list[dict[str, Any]]) -> dict[str, Any]:
    """부호 있는 합계 kcal 오차. 과대추정 쏠림과 이중 계산 의심 사진을 잡는다."""
    vals = [s["total_kcal_bias"] for s in scored if s.get("total_kcal_bias") is not None]
    if not vals:
        return {"n": 0, "mean": None, "median": None, "over": 0, "suspects": []}
    suspects = sorted(
        (
            (s["id"], s["kind"], s["total_kcal_bias"])
            for s in scored
            if (s.get("total_kcal_bias") or 0) > DOUBLE_COUNT_BIAS
        ),
        key=lambda t: -t[2],
    )
    return {
        "n": len(vals),
        "mean": round(statistics.fmean(vals), 2),
        "median": round(statistics.median(vals), 2),
        "over": len(suspects),
        "suspects": suspects[:10],
    }


def aggregate(scored: list[dict[str, Any]]) -> dict[str, Any]:
    tp = sum(s["tp"] for s in scored)
    fp = sum(s["fp"] for s in scored)
    fn = sum(s["fn"] for s in scored)
    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / (tp + fn) if tp + fn else 0.0
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0

    return {
        "photos": len(scored),
        "total_only_photos": sum(1 for s in scored if s.get("total_only")),
        "errors": sum(1 for s in scored if s.get("error")),
        "name": {
            "tp": tp,
            "exact": sum(s["exact"] for s in scored),
            "fp": fp,
            "fn": fn,
            "precision": round(precision, 4),
            "recall": round(recall, 4),
            "f1": round(f1, 4),
        },
        "grams": _stats([v for s in scored for v in s["grams_apes"]]),
        "item_kcal": _stats([v for s in scored for v in s["kcal_apes"]]),
        "density": _stats([v for s in scored for v in s["density_apes"]]),
        "total_kcal": _stats(
            [s["total_kcal_ape"] for s in scored if s["total_kcal_ape"] is not None]
        ),
        "total_kcal_bias": _bias_stats(scored),
    }


def by_kind(scored: list[dict[str, Any]]) -> dict[str, Any]:
    kinds: dict[str, list[dict[str, Any]]] = {}
    for s in scored:
        kinds.setdefault(s["kind"], []).append(s)
    return {k: aggregate(v) for k, v in sorted(kinds.items())}


def by_kcal_source(scored: list[dict[str, Any]]) -> dict[str, Any]:
    """kcal 정답 출처별 분해. DB에서 베낀 정답이 섞였는지 갈라 본다."""
    groups: dict[str, list[dict[str, Any]]] = {}
    for s in scored:
        for d in s["items"]:
            groups.setdefault(d.get("kcal_source") or "(미기재)", []).append(d)

    def pick(ds: list[dict[str, Any]], key: str) -> list[float]:
        return [d[key] for d in ds if d.get(key) is not None]

    return {
        src: {
            "items": len(ds),
            "kcal": _stats(pick(ds, "kcal_ape")),
            "density": _stats(pick(ds, "density_ape")),
        }
        for src, ds in sorted(groups.items())
    }
