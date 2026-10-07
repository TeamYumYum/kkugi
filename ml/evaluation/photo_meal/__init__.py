"""사진 식사 인식의 음식명·그램·kcal 정확도 평가(v1 `ai/eval/eval_photo_meal.py`에서 이식).

모델과 무관하게 "정답 라벨 + 예측 JSONL"만으로 채점한다. 예측을 만드는 쪽(Claude Vision,
fine-tune 모델 등)은 Vision 베이스 모델이 정해진 뒤 붙인다. 사용법은 `ml/evaluation/README.md`.
"""
