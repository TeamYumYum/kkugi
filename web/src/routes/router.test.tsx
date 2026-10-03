import { cleanup, render, screen } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { useCurrentRole } from '../hooks/useCurrentRole';
import { routes } from './router';

vi.mock('/src/api/client', () => ({ request: vi.fn() }));
vi.mock('/src/hooks/useCurrentRole', () => ({ useCurrentRole: vi.fn(() => 'ADMIN') }));

function renderAt(url: string) {
  const router = createMemoryRouter(routes, { initialEntries: [url] });
  render(<RouterProvider router={router} />);
}

afterEach(() => {
  cleanup();
  vi.mocked(useCurrentRole).mockReturnValue('ADMIN');
});

describe('router', () => {
  it('/는 대시보드 레이아웃 안에 홈 화면을 보여 준다', () => {
    renderAt('/');

    expect(screen.getByRole('navigation', { name: '주 메뉴' })).toBeTruthy();
    expect(screen.getByRole('heading', { level: 1, name: '대시보드 홈' })).toBeTruthy();
  });

  it('/admin은 관리자 역할이면 관리자 레이아웃 안에 관리자 홈을 보여 준다', () => {
    renderAt('/admin');

    expect(screen.getByRole('navigation', { name: '관리자 메뉴' })).toBeTruthy();
    expect(screen.getByRole('heading', { level: 1, name: '관리자 홈' })).toBeTruthy();
  });

  it('/admin은 관리자 역할이 아니면 거부 화면을 보여 주고 관리자 화면을 렌더하지 않는다', () => {
    vi.mocked(useCurrentRole).mockReturnValue('USER');

    renderAt('/admin');

    expect(screen.getByRole('heading', { level: 1, name: '접근 권한이 없습니다' })).toBeTruthy();
    expect(screen.queryByRole('heading', { name: '관리자 홈' })).toBeNull();
    expect(screen.queryByRole('navigation', { name: '관리자 메뉴' })).toBeNull();
  });
});
