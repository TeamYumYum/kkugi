# 냠냠코치 리뉴얼 기획서

**작성일:** 2026-10-03 · **상태:** 초안 v0.1 · **결정 근거:** `docs/adr/` (ADR-0001~0013)

> SSAFY 자율 프로젝트에서 냠냠코치를 새로 개발한다. v1(4주·2인·웹)의 제품 방향은 잇되,
> 표면·팀·아키텍처는 처음부터 다시 결정했다. 이 문서는 "무엇을, 누가, 언제" 만드는지의 합의본이다.

---

## 1. 개요

**한 줄 정의**
> 사용자가 기록하는 앱이 아니라, **냠냠이가 미리 준비해 두고 사용자는 확인만 하는** AI 건강 코치. 폰과 워치가 주 무대다.

**v1 대비 달라지는 점**

| | v1 (2026-06) | 리뉴얼 |
|---|---|---|
| 표면 | Vue 웹 단일 | **Android 폰(Primary)** + **Wear OS** + React 웹(대시보드·관리자) |
| 식사 입력 | 텍스트 검색 → 수동 선택 | **사진 촬영 → Vision 인식 → 수정** |
| 운동 입력 | 폰 폼 입력 | **워치 1탭 세트 기록**, 휴식 타이머, 심박 |
| AI | Claude 코멘트·추천 | Claude + **Vision 모델 + MLOps 피드백 루프** |
| 성장 지표 | Streak · Nyam 외형 | + **XP·레벨·뱃지 복원** |
| 팀 · 기간 | 2인 · 4주 | **6인 · 8주**, 도메인 개인 수직 소유 |

---

## 2. 사용자와 문제

**페르소나** (PRODUCT.md 계승)
한국어 사용, 건강 관리 입문~중급. 전문 도구보다 **부담 없이 습관을 만들고 싶은** 사람. 하루 여러 번, 짧게 쓴다. 헬스장에선 폰을 사물함에 두고 워치만 찬다.

**문제**
식단·운동 기록 앱은 입력이 번거로워 3일을 못 넘긴다. 특히 웨이트 기록은 운동명 검색 → 세트 추가 → 무게·횟수 입력을 폰을 들었다 놨다 하며 반복해야 한다. 기록이 목적이 되는 순간 습관은 끊긴다.

**UX 원칙 — Create → Confirm**

1. **입력 최소화** — 앱이 먼저 제시한다(오늘 루틴, 추천 무게, 인식된 음식). 사용자는 확인하거나 살짝 고친다.
2. **한 화면 한 행동** — 지금 할 일 하나와 큰 버튼 하나. 상세는 Progressive Disclosure.
3. **운동 중엔 조용히, 전후에 보상** — Workout Mode는 빠르고 최소. 완료 화면에서 캐릭터·XP·PR·Streak이 터진다.
4. **AI는 채팅이 아니라 UI를 없애는 데 쓴다** — 사진이 입력 폼을 대체하고, 수정 한 번이 다음 모델을 만든다.

**수용 기준 (측정 가능한 것만)**

| 기준 | 목표 |
|---|---|
| 앱 실행 → 운동 시작 | ≤ 3탭 |
| 세트 완료 | ≤ 1탭 (워치) |
| 무게 변경 | ≤ 2탭 |
| 이전 기록 | 세트 화면에 항상 표시 |
| 네트워크 없는 운동 기록 | 가능 (워치·폰 모두) |
| 촬영 → 식사 저장 | ≤ 3탭 (촬영·확인·저장) |

---

## 3. 핵심 기능

### 3.1 도메인(Bounded Context) 6개

| 도메인 | 책임 | MVP 기능 | 표면 | 소유 |
|---|---|---|---|---|
| **Member** | 계정·온보딩·프로필 | 소셜 로그인(카카오·구글), 온보딩(HealthGoal·신체 정보 → Program 생성 트리거), 프로필 조회·수정·비활성화 | 폰 · 웹 | C |
| **Meal** | 식사 기록과 영양 | 사진 촬영 → Vision 인식 → 결과 수정 → 저장(**예측값·수정값 모두 보존**), 검색 입력(폴백), 영양 합산, 오늘 칼로리 | 폰 | A |
| **Workout** | 루틴·세션·세트 | 루틴 생성(AI 추천/직접), 오늘 루틴 워치 동기화, **Workout Mode**(세트 완료·휴식 타이머·심박 요약), 세션 완료 화면(볼륨·PR), 점진적 과부하 조정(UP/HOLD/DOWN/VOLUME_UP/DELOAD) | **워치** · 폰 | B + F |
| **Coaching** | 목표와 조언 | Program·DailyGoal, 칼로리 밸런스(운동 소모 반영), 마지막 끼니 추천(17시 이후·잔여 1끼 ±20%), WeeklyReport, 체중 추세 → 칼로리 재조정, FCM 트리거 판단, RAG 영양 채팅(시간 나면) | 폰 · 웹 | D |
| **Growth** | 동기부여 | XP·레벨, Nyam 외형 변화, Streak·마일스톤(3·7·30·100일), 뱃지, 일일 미션 | 폰 · 워치 Tile | C |
| **Admin / ML Platform** | 모델 운영 | 수정 데이터 검수(승인·반려), 데이터셋 버전, 학습·오프라인 평가, MLflow 모델 버전·품질 게이트, 관리자 조회 | 웹 · `ml/` | E (+F UI) |

### 3.2 시연 단위 (MVP)

| 단위 | 주차 | 들어가는 것 | 시연 |
|---|---|---|---|
| **MVP-1** | 2~3 | 소셜 로그인 → 온보딩 → **사진 식사 기록** → 홈(Nyam·Streak·오늘 칼로리·XP) | 폰만으로 |
| **MVP-2** | 4~5 | 루틴 생성 → **워치 Workout Mode** → 폰 완료 화면 → AI 루틴 조정 → 칼로리 밸런스 | 워치 + 폰 |
| **MVP-3** | 6~7 | 웹 대시보드, FCM(Streak 리마인드·마지막 끼니), **MLOps 1회전**(수정 적재 → 검수 → 평가 → 버전), WeeklyReport, 뱃지 | 웹 + 전체 |

### 3.3 기능 의존 사슬 (= 개발 순서)

```
소셜 로그인 ─▶ 온보딩(Program 생성) ─▶ 홈(Nyam · Streak · 오늘 칼로리 · XP)
                                         │
             ┌───────────────────────────┼────────────────────────────┐
             ▼                           ▼                            ▼
   식사: 사진 → 인식 → 수정 → 저장   운동: 루틴 → 워치 Workout Mode    Growth: XP · Streak · 뱃지
             │                           │  → 완료 화면 → AI 조정           ▲
             │                           └── 칼로리 밸런스 ───────────────┘ (이벤트)
             ▼
   예측 vs 수정 적재 ─▶ 관리자 검수 ─▶ 데이터셋 ─▶ 학습·평가 ─▶ MLflow 버전 ─▶ 추론 모델 교체
             │
             └──────────────────▶ 웹 대시보드 (식사 · 운동 · 체중 · 리포트)      ◀── 운동 세션
   FCM: Streak 리마인드 · 마지막 끼니 추천 (Coaching이 조건 판단)
```

---

## 4. 핵심 사용자 여정

### J1. 사진 한 장으로 식사 기록 (폰, MVP-1)
홈 → **[촬영]** → 사진 → 인식 결과 카드(음식명·양·칼로리·탄단지) → (틀리면) 음식명/양 수정 → **[저장]** → Nyam 반응 + XP + 오늘 칼로리 갱신.
뒤에서: `prediction`(모델 출력 그대로)과 `correction`(사용자 확정값)을 둘 다 저장한다. 이 쌍이 J3의 원료다.

### J2. 폰은 사물함에 (워치, MVP-2)
전날 밤 폰이 "내일 Push Day" 루틴을 워치에 내려둔다. 헬스장에서 폰은 사물함, 워치만 착용.
워치: "오늘 Push Day예요" → **[시작]** → `벤치프레스 · 지난번 80×8 · 오늘 82.5×8` → **[✓ 세트 완료]** → 진동 + 휴식 01:30 → 다음 세트 자동 준비 → … → **[운동 종료]**.
워치는 전부 로컬에 저장하고, 폰이 BT 범위에 들어오면 세션(세트·평균/최대 심박·소모 kcal)을 넘긴다.
폰: 🎉 완료 화면 — 총 볼륨 8,250kg · New PR 벤치 +2.5kg · +120 XP · 🔥 7일 연속. 그 사이 AI가 다음 주 루틴을 조정해 둔다.

### J3. 수정이 모델이 된다 (관리자 웹 + ml/, MVP-3)
J1의 수정 데이터가 쌓인다 → 관리자 웹에서 검수(예측 vs 수정 비교, 승인/반려) → 승인분으로 데이터셋 v2 → 학습 → 오프라인 평가(top-1 정확도, 혼동 상위 쌍) → 품질 게이트(이전 모델 이상) 통과 시 MLflow에 등록 → 추론 서버가 새 버전 로드 → 관리자 웹에서 버전·지표 확인.
발표에서 "사용자의 수정 한 번이 다음 모델을 만든다"를 한 사이클 실제로 보여준다.

---

## 5. 시스템 아키텍처

### 5.1 전체 구성

```
┌─ Wear OS ─────────┐  DataClient / MessageClient   ┌─ Android 폰 ───────────────────────┐
│ Workout Mode       │◀──────────────────────────────▶│ :app  :feature:{member,meal,        │
│ Streak Tile        │  루틴 ↓  세션 ↑  (끊겨도 보관)   │        workout,coaching,growth}     │
│ Room (세션 로컬)    │                               │ :core (모델·네트워크·Room·DS·DataLayer)│
│ Health Services    │                               │ Room(운동만) · WorkManager · FCM     │
└────────────────────┘                               │ Health Connect(읽기)                 │
                                                     └───────────────┬─────────────────────┘
┌─ Web (React+Vite) ─┐                                               │ REST (SSE: RAG 채팅)
│ 대시보드 · 관리자    │──────────────────────┐                        │
└────────────────────┘                      ▼                        ▼
                                     ┌─ Nginx ─┐ ─────▶ ┌─ Spring Boot ───────────────────┐
                                     └─────────┘        │ domain/{member,meal,workout,     │
                                                        │   coaching,growth,admin}         │
                                                        │ 도메인 이벤트 · 스케줄러 · FCM 발송  │
                                                        │ springdoc → openapi.json         │
                                                        └──────┬─────────────┬─────────────┘
                                                               │ 내부 HTTP    │
                                                               ▼             ▼
                                           ┌─ FastAPI (ai/) ──────────┐   MySQL ◀── Spring만 쓰기
                                           │ Vision 추론 · Claude 코칭  │   Redis (JWT·캐시)
                                           │ RAG(후순위)               │
                                           └──────┬───────────────────┘
                                                  │ 모델 로드
                                           ┌─ ml/ ─────────────────────┐
                                           │ datasets · training       │──▶ MLflow (추적·레지스트리)
                                           │ evaluation · 품질 게이트    │
                                           └───────────────────────────┘
```

### 5.2 데이터 흐름 규칙

| 구간 | 규칙 |
|---|---|
| 워치 ↔ 폰 | 워치는 서버·인증을 모른다. `DataClient`로 루틴 내려받기·세션 올리기(연결 끊겨도 보관), `MessageClient`로 시작/종료 이벤트. **세션 소유권 단일** — 먼저 시작한 기기가 주인, 다른 쪽은 읽기 전용 |
| 폰 오프라인 | **운동 세션만** Room에 먼저 쓰고 WorkManager가 업로드 재시도. 식사·홈·코칭은 온라인 전용(마지막 응답 캐시만) |
| 폰·웹 ↔ 서버 | REST + FCM. RAG 채팅 응답만 SSE. WebSocket 없음 |
| Spring ↔ FastAPI | Spring → FastAPI 내부 HTTP(`/ai/**`). FastAPI는 업무 DB 읽기 전용. Vue/Android는 FastAPI를 모른다 |
| 도메인 간 (Spring) | 상태 변경 전파는 **도메인 이벤트**(`WorkoutSessionCompleted` → Growth XP·Streak, Coaching 조정). 단순 조회만 타 도메인 public service 호출. 타 도메인 Repository 직접 접근 금지(ArchUnit) |
| API 계약 | `springdoc` → `contracts/openapi.json` → `openapi-typescript`(웹 `generated/`) + `openapi-generator kotlin`(Android `:core`). 계약 변경 = 양쪽 컴파일 에러 |
| ML 아티팩트 | MLflow(모델·지표·실험). 업무 테이블은 Spring만 쓰기. 관리자 웹은 Spring 경유 또는 MLflow API 조회 |

### 5.3 외부 연동

| 연동 | 용도 | 담당 | 1주차 할 일 |
|---|---|---|---|
| 카카오 · 구글 로그인 | 가입·로그인 | C | 앱 등록·키 발급 (심사 지연 대비) |
| Health Services (워치) | 운동 중 심박 샘플링 → 세션 요약 | B | 권한 플로우 |
| Health Connect (폰, 읽기) | 걸음 → TDEE 보정, 체중 → 자동 입력 | C | 권한 선언 |
| FCM | Streak 리마인드, 마지막 끼니 추천, WeeklyReport 알림 | D | Firebase 프로젝트 |
| Vision 모델 | 음식 사진 인식 | E | 베이스 모델 선정 (§9) |
| Claude API | 코칭 코멘트·루틴 조정·추천·RAG | E | v1 `claude_service` 이식, mock 모드 |
| MLflow | 실험 추적·모델 레지스트리 | E | compose 서비스 추가 |

### 5.4 저장소 구조 (모노레포)

```
nyamnyam/
├── android/        :app  :wear  :core  :feature:{member,meal,workout,coaching,growth}
├── backend/        Spring Boot — domain/{…}/{controller,dto,entity,event,repository,service} · global/ · infrastructure/{ai,fcm,oauth}
├── ai/             FastAPI — routers/ services/ schemas/ (추론 전용)
├── ml/             datasets/ training/ evaluation/ (학습·평가·MLflow)
├── web/            React+Vite — api/ generated/ components/ pages/{영역}/ hooks/ routes/
├── contracts/      openapi.json (빌드 산출물, 생성기 입력)
├── infra/          docker-compose · nginx · CI
└── docs/           기획서 · ADR · API 노트
```

최상위는 **배포·기술 경계**, 내부는 **도메인 경계**. 스토리 하나는 `android/feature/meal` + `backend/domain/meal` + 마이그레이션을 한 브랜치에서 끝낸다.

---

## 6. 팀과 일정

### 6.1 소유 — 개인 수직 4 + 횡단 2

| 사람 | 도메인 (수직: 폰 + 백엔드 + 마이그레이션) | 홈 표면 (공통 기반 소유 · 그 표면 PR 리뷰) |
|---|---|---|
| **A** | Meal | Android 폰 (앱 셸·DI·디자인 시스템·Room) |
| **B** | Workout — 폰 + **워치 전체** + Data Layer | Wear |
| **C** | Member + Growth | 인프라 · CI/CD |
| **D** | Coaching | Spring (Security·ApiResponse·이벤트 인프라·스케줄러) |
| **E** | AI / ML 플랫폼 — Vision · Claude · MLflow · RAG(후순위). A·B·D에 계약 제공 | FastAPI · `ml/` |
| **F** | Web — 대시보드 · 관리자 UI. **3~5주차 Workout 페어** | Web |

### 6.2 작업 규칙

- **1 Story = 1 Branch = 1 PR.** `feature/{JIRA-ID}-{short-name}`. 폰·백엔드·마이그레이션을 한 브랜치에. `develop` 없음, `main`에 직접 머지.
- **리뷰어 = 상대 표면 홈 담당.** A가 Spring 코드를 쓰면 D가 본다. 개인 수직에서 표면 일관성을 지키는 유일한 장치.
- **AI 계약(`ai/schemas`) 변경은 E 리뷰 필수.** OpenAPI 계약 변경은 소비 표면 담당 리뷰 필수.
- **공통 변경**(`:core`, `global/`, `components/`)은 홈 담당 승인.
- 머지 조건: 수용 기준 충족 · CI 통과 · 핵심 여정 수동 확인.

### 6.3 주차 계획

| 주차 | 마일스톤 | 내용 |
|---|---|---|
| **1** | 기반 | 표면별 셸(앱·워치·Spring·FastAPI·웹) + 규칙 파일 + ERD + API 계약 v1 + 외부 키 신청. **1주로 압축 — 끝에 체크리스트로 검증** |
| 2 | MVP-1 | 로그인·온보딩·홈. E: Vision 추론 엔드포인트. F: 웹 셸만 |
| **3** | **MVP-1 데모 ★** | 사진 식사 기록 → 홈 |
| 4 | MVP-2 | 루틴 → 워치 Workout Mode. B+F 페어 피크. D: adjust 연동 |
| **5** | **MVP-2 데모 ★** | 워치 세트 기록 → 완료 화면 → AI 조정. F 웹 복귀 |
| 6 | MVP-3 | 웹 대시보드 · FCM · MLflow 1회전 · WeeklyReport |
| **7** | **MVP-3 데모 ★ · 기능 동결** | 관리자 검수 · 뱃지 · (RAG). **7주 말 이후 신규 기능 금지** |
| 8 | QA · 발표 | 버그만. 발표 자료 · 시연 리허설 |

---

## 7. 범위 밖 (명시적으로 뺀 것)

| 뺀 것 | 이유 |
|---|---|
| 커뮤니티 (팔로우·게시판·댓글·피드) | 별도 도메인, 화면 많음. 후속 |
| Multi-Agent 코칭 (F704) · 2주 체크인 (F804) | 핵심 여정에 없음 |
| 자동 재학습 · A/B 테스트 · drift 모니터링 | MLOps 1회전 이후 단계 |
| Health Connect **쓰기** | 권한·중복 처리 비용 대비 가치 낮음 |
| 심박 실시간 미러링 · 심박 기반 휴식 타이머 | 사물함 시나리오와 충돌 / 튜닝 필요 |
| 워치 식사 기록 | 워치는 Workout Mode + Tile만 |
| 전체 오프라인 양방향 동기화 | 8주에 가장 흔히 터지는 지점 |
| Food DB 관리자 CRUD | 검수·모델 버전 조회가 관리자 최소 범위 |
| iOS | 네이티브 Android 선택 |

---

## 8. 리스크와 대응

| 리스크 | 징후 | 대응 |
|---|---|---|
| 워치 ↔ 폰 동기화 버그 | 세션 유실·중복, 루틴 안 내려감 | B+F 페어, 세션 소유권 단일, **2주차 말 Data Layer 스파이크**(실기기 왕복 1회 성공을 기반 체크리스트에) |
| AI/ML 1인 과부하 | E의 스토리 적체 | RAG 최후순위, Vision은 **사전학습 모델 fine-tune** 또는 외부 API 폴백, 학습은 소규모 데이터셋으로 1회전만 |
| 웹 겸용(사용자 + 관리자) F 1인 | 6주차에 화면 밀림 | 대시보드 화면 상한 6, 관리자 3. F는 5주차에 웹 복귀 확정 |
| 소셜 로그인 심사·키 지연 | 2주차에도 로그인 불가 | 1주차 신청, 그때까지 개발용 이메일 로그인 유지 |
| Vision 정확도 낮음 | 수정률 > 50% | 제품은 **수정 UX로 성립**. 낮은 정확도는 MLOps 스토리의 출발점으로 전환 |
| 기능 동결 위반 | 8주차 신규 PR | 7주 말 동결, 8주차는 `fix/`만 머지 |
| 기반 1주 압축 | 2주차에 셸이 흔들림 | 1주차 금요일 체크리스트: 각 표면 빌드·배포·로그인 왕복·규칙 파일 적용 확인 |

---

## 9. 확인 필요 (미결)

- **Vision 베이스 모델** — 자체 fine-tune(한식 데이터셋 확보 여부) vs 외부 Vision API + 자체 분류기. 1주차 E 결정.
- **디자인 파운데이션** — v1 PRODUCT.md(네오브루탈 · #58cc02)와 DESIGN.md(#FF8C42) 불일치. 모바일 Primary에 맞춰 다시 정한다.
- **소셜 로그인 범위** — 카카오만으로 시작할지, 구글 동시 지원할지.
- **XP 규칙** — 세트·식사·미션별 XP와 Nyam 외형 단계 매핑 (Growth 소유자 C가 2주차 초안).
- **팀원 실명 배정** — A~F에 사람 매핑. 풀스택 4명을 A·B·C·D에.
- **마이그레이션 도구** — 지금 `ddl-auto: none`, 도구 미정. 추천: Flyway(ADR-0007이 "스토리 하나 = 폰·백엔드·마이그레이션 한 브랜치"를 전제). 1주차 D.
- **인증 방식** — 지금 `SecurityConfig`가 `permitAll` 임시. 추천: v1의 JWT + Redis 블랙리스트 재사용(소셜 로그인 뒤에 붙이기 쉬움). 401·403도 `ApiResponse` 형태로. 1주차 D·C.
- **`:core` OpenAPI Kotlin 생성** — Gradle 설정 없음. ADR-0009 1주차 항목: openapi-generator 플러그인, DTO만 생성할지 Retrofit 인터페이스까지 생성할지. 1주차 A.
- **MLflow stage vs alias** — 지금 `get_latest_versions(stages=["Production"])`(MLflow 3에서 deprecated, 코드에 "결정 필요" 주석). 추천: alias(`@production`)로 바꾸고 ADR-0011 문구 수정. 1주차 E.
