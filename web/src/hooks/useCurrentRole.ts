/*
 * 현재 사용자 역할 — 1주차 스텁(STUB).
 *
 * 인증이 없어서 개발 편의로 항상 ADMIN을 돌려준다. 로그인·사용자 조회 API(계약 v1)가 생기면 세션의
 * 실제 역할을 읽도록 바꾼다. 역할 이름도 그때 생성 타입(src/generated/)의 값으로 맞춘다.
 */
export type Role = 'USER' | 'ADMIN';

const STUB_ROLE: Role = 'ADMIN';

export function useCurrentRole(): Role {
  return STUB_ROLE;
}
