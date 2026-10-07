import json

import pytest

from photo_meal.dataset import DatasetError, GtItem, Sample, load_dataset
from photo_meal.score import main, score
from photo_meal.scoring import aggregate, assign, match_score, normalize, score_sample


def _write_jsonl(path, rows):
    path.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in rows), encoding="utf-8")
    return path


def _sample(items, **kw) -> Sample:
    return Sample(id="s", image=None, meal_type="LUNCH", kind="single", items=items, **kw)


def test_normalize는_괄호와_공백을_뗀다():
    assert normalize("닭가슴살(구이)") == normalize("닭 가슴살") == "닭가슴살"


def test_match_score():
    gt = GtItem(name="제육덮밥", grams=500, aliases=["돼지불고기덮밥"])
    assert match_score(gt, "제육 덮밥") == 2
    assert match_score(gt, "돼지불고기덮밥") == 2
    assert match_score(gt, "매운 제육덮밥 곱빼기") == 1
    assert match_score(gt, "김밥") == 0
    assert match_score(gt, "") == 0


def test_assign은_정확일치를_부분일치보다_먼저_배정한다():
    gts = [GtItem(name="밥", grams=210), GtItem(name="현미밥", grams=210)]
    preds = [{"name": "현미밥"}, {"name": "흰밥"}]
    # "현미밥" 예측은 "현미밥" 정답(2점)에, "흰밥"은 "밥" 정답(부분 1점)에 간다
    assert sorted(assign(gts, preds)) == [(0, 1, 1), (1, 0, 2)]


def test_score_sample_오차와_검출():
    sample = _sample(
        [
            GtItem(name="닭가슴살", grams=100, kcal=110, kcal_source="package"),
            GtItem(name="쌀밥", grams=210, kcal=325, kcal_source="package"),
        ]
    )
    preds = [
        {"name": "닭가슴살(구이)", "estimated_grams": 150, "kcal": 165},
        {"name": "샐러드", "estimated_grams": 50, "kcal": "20"},
    ]
    r = score_sample(sample, preds)

    assert (r["tp"], r["fp"], r["fn"]) == (1, 1, 1)
    assert r["grams_apes"] == [50.0]
    assert r["kcal_apes"] == [50.0]
    assert r["density_apes"] == [0.0]  # 그램·kcal 모두 1.5배 → 계수 오차 없음
    assert r["missed"] == ["쌀밥"] and r["spurious"] == ["샐러드"]
    assert r["pred_total_kcal"] == 185.0
    assert r["total_kcal_bias"] == round((185 - 435) / 435 * 100, 2)


def test_total_only는_항목_지표를_세지_않는다():
    sample = _sample([], total_only=True, total_kcal_gt=600)
    r = score_sample(sample, [{"name": "a", "kcal": 500}, {"name": "b", "kcal": 400}])

    assert (r["tp"], r["fp"], r["fn"]) == (0, 0, 0)
    assert r["total_kcal_bias"] == 50.0


def test_aggregate가_이중_계산_의심을_잡는다():
    double = score_sample(_sample([], total_only=True, total_kcal_gt=500), [{"kcal": 1000}])
    fine = score_sample(_sample([], total_only=True, total_kcal_gt=500), [{"kcal": 520}])
    bias = aggregate([double, fine])["total_kcal_bias"]

    assert bias["over"] == 1
    assert bias["suspects"][0][2] == 100.0


def test_load_dataset_형식_오류(tmp_path):
    bad_source = _write_jsonl(
        tmp_path / "labels.jsonl",
        [
            {
                "id": "1",
                "image": "a.jpg",
                "meal_type": "LUNCH",
                "items": [{"name": "밥", "grams": 210, "kcal": 300, "kcal_source": "guess"}],
            }
        ],
    )
    with pytest.raises(DatasetError, match="kcal_source"):
        load_dataset(bad_source, check_images=False)

    missing_image = _write_jsonl(
        tmp_path / "labels2.jsonl",
        [{"id": "1", "image": "a.jpg", "meal_type": "LUNCH", "items": [{"name": "밥", "grams": 1}]}],
    )
    with pytest.raises(DatasetError, match="사진 없음"):
        load_dataset(missing_image)


def test_score_cli(tmp_path, capsys):
    labels = _write_jsonl(
        tmp_path / "labels.jsonl",
        [
            {
                "id": "1",
                "image": "a.jpg",
                "meal_type": "LUNCH",
                "items": [{"name": "바나나", "grams": 100, "kcal": 89, "kcal_source": "package"}],
            },
            {"id": "2", "image": "b.png", "meal_type": "LUNCH", "total_only": True, "total_kcal": 700},
        ],
    )
    preds = _write_jsonl(
        tmp_path / "preds.jsonl",
        [
            {"id": "1", "detected_items": [{"name": "바나나", "estimated_grams": 120, "kcal": 107}]},
            {"id": "9", "detected_items": []},
        ],
    )
    out = tmp_path / "out" / "score.json"

    assert main(["--dataset", str(labels), "--predictions", str(preds), "--out", str(out)]) == 0

    result = json.loads(out.read_text(encoding="utf-8"))
    assert result["metrics"]["errors"] == 1  # id 2는 예측 없음
    assert result["unknown_prediction_ids"] == ["9"]
    assert result["metrics"]["name"]["f1"] == 1.0
    assert "F1 1.0" in capsys.readouterr().out
    assert score(labels, preds)["metrics"] == result["metrics"]
