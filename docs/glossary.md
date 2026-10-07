# 용어집

도메인 6개와 표면 5개가 같은 단어를 쓰게 하는 기준 표다. ERD의 테이블·컬럼, API 필드, 화면 문구, 이벤트 이름은
이 표의 식별자를 따른다. 새 용어는 코드에 쓰기 전에 이 표에 먼저 추가하고, 뜻이 바뀌면 표를 고친 뒤 링크된 문서를 확인한다.

| 항목 | 값 |
|---|---|
| 상태 | 초안. 각 도메인 소유자 검토 전 |
| 갱신 | 현행 갱신. 용어를 추가·변경하는 MR에서 함께 고친다 |
| 출처 | [기획서](./renewal/plan.md), [ADR](./adr/README.md), [이벤트 목록](./renewal/events.md), 영역 README |

`(가정)`은 팀이 아직 확정하지 않은 값이나 이름이다. 확정되면 표기를 지운다.

## 제품·프로젝트

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| 냠냠코치 | NyamNyam Coach | 제품명. 사용자가 기록하는 앱이 아니라 냠냠이가 미리 준비해 두고 사용자는 확인만 하는 AI 건강 코치 | 기획서 1장 |
| 냠냠이 | Nyam | 사용자의 성장을 외형으로 보여주는 캐릭터. 외형 단계는 Growth가 관리한다 | 기획서 1·3장 |
| Create → Confirm | - | UX 원칙. 앱이 먼저 제시하고 사용자는 확인하거나 살짝 고친다 | 기획서 2장 |
| 표면 | surface | 배포·기술 경계 단위. Android 폰, Wear OS, 웹, Spring, FastAPI·ml | 기획서 5.4, ADR-0012 |
| 홈 담당 | home owner | 표면의 공통 기반을 소유하고 그 표면의 MR을 리뷰하는 사람 | ADR-0012 |
| 수직 소유 | vertical ownership | 도메인 하나를 폰·백엔드·마이그레이션까지 한 사람이 소유하는 방식 | ADR-0012 |
| MVP-1·2·3 | - | 3·5·7주차 시연 단위. 범위는 기획서 3.2 | 기획서 3.2 |
| 기능 동결 | freeze | 7주 말 이후 신규 기능 금지. `freeze` 태그 이후 `fix/`·`docs/`만 병합 | Git 컨벤션 4장 |
| 판정 | lite · standard · strict | 영역 `AGENTS.md`가 변경 범위로 정하는 절차 단계(경량·표준·엄격) | 영역 AGENTS.md 3장 |
| 플랜·리뷰 | plans/ | 표준·엄격 판정의 산출물. 양식은 `docs/templates/` | 영역 AGENTS.md 4장 |

## Member

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| 회원 | member | 가입한 사용자. 소셜 계정으로 식별한다 | 기획서 3.1 |
| 소셜 계정 | social_account | 카카오·구글 계정 연결 정보. (provider, provider_user_id)로 유일 (가정) | 기획서 3.1 |
| 개발용 이메일 로그인 | EMAIL_DEV (가정) | 소셜 로그인 심사 지연에 대비한 임시 로그인. 운영에서는 끈다 | 기획서 8장 |
| 온보딩 | onboarding | 가입 직후 HealthGoal·신체 정보를 입력해 Program 생성을 트리거하는 절차 | 기획서 3.1 |
| 건강 목표 | HealthGoal: LOSE · MAINTAIN · GAIN (가정) | 온보딩에서 고르는 목표. Program 산식의 입력 | 기획서 3.1, 이벤트 목록 |
| 프로필 | member_profile | 닉네임과 신체 정보(성별·생년·키·몸무게) | 기획서 3.1 |
| 비활성화 | DEACTIVATED | 회원이 이용을 중단한 상태. 로그인을 막고 데이터는 보존한다 | 기획서 3.1 |
| 기기 | member_device | FCM 토큰을 가진 사용자 기기 | ADR-0013 |
| 역할 | role: USER · ADMIN (가정) | 웹 관리자 화면 접근 기준 | web/README |

## Meal

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| 식사 | meal | 한 번의 식사 기록. 음식 항목 1개 이상 | 기획서 3.1 |
| 식사 항목 | meal_item | 식사에 포함된 음식 하나와 양 (가정) | ERD |
| 음식 | food | 영양 정보를 가진 음식 사전 항목. 검색 입력과 영양 계산의 원천 | 기획서 3.1 |
| 인식 | recognition | 사진을 Vision 모델에 보내 음식 후보를 받는 과정 | 기획서 J1 |
| 예측 | prediction · meal_prediction | Vision 모델 출력 원본. 사용자가 고쳐도 보존한다 | 기획서 J1, ADR-0011 |
| 수정 | correction · meal_correction | 사용자가 확정한 값. 예측과 쌍으로 보존해 학습 원료가 된다 | 기획서 J1, ADR-0011 |
| 검색 입력 | input_method = SEARCH | 사진 대신 음식 이름으로 찾아 기록하는 폴백 경로 | 기획서 3.1 |
| 영양 | nutrition | kcal와 탄수화물·단백질·지방(g) | 기획서 J1 |
| 식사 구분 | meal_type: BREAKFAST · LUNCH · DINNER · SNACK (가정) | 하루 안에서 식사의 위치 | 요구사항 Meal |

## Workout

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| 운동 | exercise | 벤치프레스처럼 종목 하나 | 기획서 J2 |
| 루틴 | routine | 운동일 하나의 계획. 운동 목록과 세트·무게·횟수 목표. AI 추천 또는 직접 생성 | 기획서 3.1 |
| 세션 | workout_session | 실제로 수행한 운동 1회. 시작·종료·세트·심박 요약·소모 kcal | 기획서 J2 |
| 세트 | workout_set | 무게 × 횟수 1회 | 기획서 J2 |
| Workout Mode | - | 워치의 세트 기록 화면. 빠르고 최소 | 기획서 2장 |
| 휴식 타이머 | rest timer | 세트 완료 후 자동 시작하는 타이머 | 기획서 J2 |
| 개인 기록 | PR · personal_record | 운동별 최고 무게·횟수 | 기획서 J2 |
| 볼륨 | total_volume_kg | 세션의 무게 × 횟수 합 | 기획서 J2 |
| 점진적 과부하 조정 | adjustment: UP · HOLD · DOWN · VOLUME_UP · DELOAD | 세션 결과로 다음 루틴의 무게·볼륨을 조정하는 결정 | 기획서 3.1 |
| 세션 소유권 | session owner | 먼저 시작한 기기가 세션의 주인. 다른 기기는 읽기 전용 미러 | ADR-0002 |
| 업로드 대기 | pending_upload | 폰 Room에 저장됐지만 서버에 아직 올라가지 않은 세션 상태 | ADR-0003 |
| 클라이언트 UUID | client_uuid | 세션 업로드의 멱등 키. 세션을 시작한 기기가 만든다 | ADR-0003 |
| 심박 요약 | HR summary | 세션의 평균·최대 심박. 실시간 미러링은 없다 | ADR-0002 |

## Coaching

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| Program | program | 온보딩 결과로 만든 코칭 계획. 목표 칼로리와 영양 비율 | 기획서 3.1 |
| DailyGoal | daily_goal | 하루 목표. Program에서 파생되며 달성 판정의 대상 | 기획서 3.1 |
| 칼로리 밸런스 | calorie balance | 섭취 − 목표. 운동 소모를 반영한다 | 기획서 3.1 |
| TDEE | - | 하루 총 에너지 소비량. Health Connect 걸음 수로 보정 | 기획서 5.3 |
| 마지막 끼니 추천 | last-meal recommendation | 17시 이후 잔여 1끼일 때 잔여 칼로리 ±20% 안의 식사 추천 | 기획서 3.1 |
| 주간 리포트 | weekly_report | 한 주의 식사·운동·체중 요약 | 기획서 3.1 |
| 체중 기록 | weight_record | 체중 1회 기록. 수동 입력 또는 Health Connect 자동 입력 | 이벤트 목록 |
| 체중 추세 | weight trend | 체중 기록으로 계산한 변화 방향. 칼로리 재조정의 입력 | 기획서 3.1 |
| RAG 영양 채팅 | - | 문서 검색 기반 영양 질문 답변. 최후순위, 응답은 SSE | ADR-0013 |

## Growth

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| XP | xp | 경험치. 식사·운동·미션으로 적립 | 기획서 3.1 |
| 레벨 | level | XP 누적 구간 | 기획서 3.1 |
| 외형 단계 | nyam_stage | 레벨에 따른 냠냠이 모습. 단계 수는 미결 (가정 5) | 기획서 3.1 |
| Streak | streak_days | DailyGoal 연속 달성 일수 | 기획서 3.1 |
| 마일스톤 | milestone | Streak 3·7·30·100일 | 기획서 3.1 |
| 뱃지 | badge | 조건 달성 시 주는 표식. PR·마일스톤 등 | 기획서 3.1 |
| 일일 미션 | daily_mission | 하루 단위 과제 | 기획서 3.1 |
| Tile | - | 워치 홈에 보이는 읽기 전용 카드. Streak·오늘 칼로리 | ADR-0002 |

## Admin · ML

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| 검수 | correction_review | 관리자가 예측 vs 수정 쌍을 승인·반려하는 것 | ADR-0011 |
| 데이터셋 버전 | dataset version | 승인분으로 만든 학습 데이터 묶음. 태그로 식별하고 MLflow에 기록 | ml/README |
| 오프라인 평가 | offline evaluation | top-1 정확도와 혼동 상위 쌍 | 기획서 J3 |
| 품질 게이트 | quality gate | 새 모델 top-1 정확도 ≥ 현재 Production 모델 | ADR-0011 |
| 모델 레지스트리 | MLflow Model Registry | 모델 버전·스테이지 저장소. 스테이지 대신 alias를 쓸지는 미결 | ADR-0011, 기획서 9장 |
| MLOps 1회전 | - | 수정 적재 → 검수 → 데이터셋 → 학습 → 평가 → 등록 → 추론 교체 한 사이클 | 기획서 J3 |

## 기술·아키텍처

| 용어 | 식별자 | 뜻 | 출처 |
|---|---|---|---|
| 도메인 이벤트 | domain event | 도메인 간 상태 변경 전파 수단. `domain/{x}/event/`에 두고 커밋 후 비동기로 처리 | ADR-0008 |
| 공개 서비스 조회 | public service | 다른 도메인이 동기 조회할 때 부르는 service 메서드. 읽기 전용 DTO를 돌려준다 | ADR-0008 |
| 계약 | contracts/ | springdoc·FastAPI가 만든 OpenAPI 산출물. 손 편집 금지 | ADR-0009 |
| 생성 타입 | generated/ | 계약에서 만든 웹·Android 타입. 손 편집 금지, MR 마지막 커밋에서 재생성 | ADR-0009 |
| Companion | - | 서버·인증을 모르는 워치 앱 방식 | ADR-0002 |
| Data Layer | DataClient · MessageClient | 워치 ↔ 폰 동기화 API. 루틴 내려받기·세션 올리기·즉시 이벤트 | ADR-0002 |
| Health Services | - | 워치 심박 샘플링 API | 기획서 5.3 |
| Health Connect | - | 폰의 걸음·체중 읽기 API. 쓰기는 범위 밖 | 기획서 5.3·7장 |
| ApiResponse | - | 모든 API 응답의 공통 포장 `success` · `data` · `error{code,message}` | [API 공통 규약](./api/conventions.md) |
| ErrorCode | - | 오류 코드 enum. 이름이 그대로 클라이언트 분기 기준이 된다 | [API 공통 규약](./api/conventions.md) |
