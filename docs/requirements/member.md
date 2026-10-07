# 요구사항 명세 — Member

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). 소유자 C 확정 전 |
| 도메인 소유 | C (Member + Growth) |
| 표면 | 폰 · 웹 |
| MVP | 1: 소셜 로그인, 온보딩, 프로필, 비활성화. 3: 기기 토큰, 웹 역할 |
| 관련 | [기획서 3.1·5.3·9장](../renewal/plan.md), [이벤트 목록](../renewal/events.md), [ERD Member](../design/erd.md#2-member), [API 공통 규약](../api/conventions.md) |

## 1. 범위

- 포함: 소셜 로그인(카카오·구글), 개발용 이메일 로그인, 토큰 발급·갱신·로그아웃, 온보딩, 프로필 조회·수정, 비활성화, FCM 기기 토큰 저장, 웹 역할
- 제외: 비밀번호 기반 일반 가입, 이메일 인증, 팔로우·커뮤니티(기획서 7장), 한 회원에 여러 소셜 계정 연결

## 2. 기능 요구사항

| ID | 요구사항 | 인수 조건 | MVP | 상태 |
|---|---|---|---|---|
| REQ-MEMBER-01 | 카카오 계정으로 로그인한다 | 최초 로그인은 회원을 만들고 응답에 `onboarded=false`를 담는다. 같은 카카오 계정으로 다시 로그인하면 같은 회원 ID를 돌려준다. (provider, provider_user_id)는 유일하다 | 1 | 제안 |
| REQ-MEMBER-02 | 구글 계정으로 로그인한다 (가정: 동시 지원) | REQ-MEMBER-01과 같은 조건. 카카오만으로 시작하기로 정하면 이 항목을 `폐기`로 바꾼다 | 1 | 제안 |
| REQ-MEMBER-03 | 개발용 이메일 로그인을 제공한다 | 이메일만으로 토큰을 받는다. 운영 프로필에서는 꺼져 있어 404 `NOT_FOUND` (가정). 소셜 로그인 키가 나오면 폐기 시점을 정한다 | 1 | 제안 |
| REQ-MEMBER-04 | 로그인하면 토큰을 발급하고 갱신·로그아웃할 수 있다 (가정: JWT access + refresh, Redis 블랙리스트) | 보호 API에 유효 토큰 없이 접근하면 401 `UNAUTHORIZED`가 ApiResponse 모양으로 온다. 로그아웃한 access 토큰은 만료 전이라도 401. refresh로 새 access를 받는다 | 1 | 제안 |
| REQ-MEMBER-05 | 온보딩에서 HealthGoal과 신체 정보를 입력한다 | 필수 항목은 HealthGoal, 성별, 생년, 키, 몸무게 (가정). 하나라도 없으면 400 `INVALID_INPUT`과 누락 필드명. 성공하면 `onboarded_at`이 기록되고 커밋 후 `MemberOnboarded(memberId, healthGoal)`가 발행된다 | 1 | 제안 |
| REQ-MEMBER-06 | 온보딩은 한 번만 완료한다 | 이미 완료한 회원이 다시 요청하면 409 (가정: `MEMBER_ALREADY_ONBOARDED`). 이벤트는 다시 발행되지 않는다 | 1 | 제안 |
| REQ-MEMBER-07 | 온보딩 전 회원은 홈에 들어갈 수 없다 | 로그인 응답의 `onboarded`가 false면 폰은 온보딩 화면으로 보낸다. 온보딩 전 회원이 홈 데이터 API를 부르면 403 (가정: `MEMBER_NOT_ONBOARDED`) | 1 | 제안 |
| REQ-MEMBER-08 | 내 프로필을 조회·수정한다 | `/members/me`로 닉네임·신체 정보·HealthGoal을 읽고 고친다. 몸무게 변경은 프로필 값만 바꾸고 체중 기록을 만들지 않는다. 체중 기록은 Coaching이 맡는다 | 1 | 제안 |
| REQ-MEMBER-09 | 닉네임 규칙을 검사한다 (가정) | 2~12자, 앞뒤 공백 제거, 제어 문자 금지. 위반 시 400 `INVALID_INPUT`. 중복 허용 여부는 미결 | 1 | 제안 |
| REQ-MEMBER-10 | 회원을 비활성화한다 | 비활성화 후 모든 토큰이 무효가 되고 로그인 시 403 (가정: `MEMBER_DEACTIVATED`). 데이터는 삭제하지 않는다. 재활성화와 보존 기간은 미결 | 1 | 제안 |
| REQ-MEMBER-11 | 다른 도메인에 프로필 읽기 전용 조회를 제공한다 | Coaching이 Program을 만들 때 쓰는 public service가 신체 정보·HealthGoal을 DTO로 돌려준다. Entity를 노출하지 않는다 | 1 | 제안 |
| REQ-MEMBER-12 | 기기의 FCM 토큰을 등록·갱신한다 | 같은 기기(가정: 앱 설치 ID)의 토큰은 덮어쓴다. 로그아웃·비활성화한 회원의 토큰으로는 발송하지 않는다 | 3 | 제안 |
| REQ-MEMBER-13 | 웹은 역할로 관리자 화면을 보호한다 | ADMIN만 `/admin/*`에 들어간다. USER가 관리자 API를 부르면 403 `FORBIDDEN`. 역할 부여 방식은 미결 (가정: DB 직접 지정) | 3 | 제안 |

## 3. 정책

- 소셜 계정 하나는 회원 하나에만 연결된다.
- 인증 실패(401·403)도 ApiResponse 모양이다. `SecurityConfig`의 EntryPoint와 AccessDeniedHandler에서 맞춘다.
- 소셜 로그인 심사가 끝나기 전까지 개발용 이메일 로그인으로 MVP-1 여정을 검증한다(기획서 8장).
- 비활성화 회원의 기록은 통계·학습 데이터에서 제외하지 않는다 (가정). 확정 필요.

## 4. 이벤트와 공개 조회

| 구분 | 이름 | 시점·용도 | 페이로드·반환 |
|---|---|---|---|
| 발행 | `MemberOnboarded` | 온보딩 완료 저장 커밋 후 | memberId, healthGoal |
| 공개 조회 | 프로필 조회 (가정: `MemberQueryService.getProfile`) | Coaching의 Program 생성 | 성별·생년·키·몸무게·HealthGoal DTO |

구독하는 이벤트는 없다. 상세는 [이벤트 목록](../renewal/events.md).

## 5. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| 소셜 로그인 범위(카카오만 / 구글 동시) | C | 1주차 |
| 인증 방식(JWT, 저장 위치, 헤더 또는 쿠키 전달) | D·C | 1주차 |
| 신체 정보 필수 항목과 활동량 입력 여부 | C·D | 2주차 |
| 닉네임 중복 허용 | C | 2주차 |
| 비활성화 후 데이터 보존 기간과 재활성화 | C | MVP-1 이전 |
| 관리자 역할 부여 방식 | C·F | MVP-3 이전 |
