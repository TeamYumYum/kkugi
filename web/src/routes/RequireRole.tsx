/*
 * 역할 가드 — 1주차 스텁(STUB).
 *
 * 현재 역할은 hooks/useCurrentRole의 고정값이다. 실제 인증(로그인 세션·토큰과 사용자 역할 조회)이 정해지면
 * 그 훅만 바꾸고, 이 가드는 "역할이 맞으면 children, 아니면 거부 화면"이라는 동작을 유지한다.
 * 서버 인가를 대신하지 않는다. 관리자 API는 서버가 역할을 다시 검사해야 한다.
 */
import type { ReactNode } from 'react';
import { useCurrentRole, type Role } from '../hooks/useCurrentRole';

type RequireRoleProps = {
  requiredRole: Role;
  children: ReactNode;
};

export default function RequireRole({ requiredRole, children }: RequireRoleProps) {
  const currentRole = useCurrentRole();

  if (currentRole !== requiredRole) {
    return (
      <main>
        <h1>접근 권한이 없습니다</h1>
        <p>이 화면은 관리자만 볼 수 있습니다.</p>
      </main>
    );
  }

  return children;
}
