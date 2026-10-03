import { createBrowserRouter, type RouteObject } from 'react-router';
import AdminLayout from '../layouts/AdminLayout';
import AppLayout from '../layouts/AppLayout';
import AdminHomePage from '../pages/admin/AdminHomePage';
import HomePage from '../pages/dashboard/HomePage';
import { ROUTE_PATTERN } from './paths';
import RequireRole from './RequireRole';

/*
 * 사용자 대시보드는 AppLayout 아래, 관리자 화면은 `/admin/*` + 역할 가드 + AdminLayout 아래에 둔다(ADR-10).
 * 로그인 가드는 인증 방식이 정해지면 두 묶음 바깥에 더한다(1주차에는 없다).
 */
export const routes: RouteObject[] = [
  {
    element: <AppLayout />,
    children: [{ path: ROUTE_PATTERN.home, element: <HomePage /> }],
  },
  {
    path: ROUTE_PATTERN.adminHome,
    element: (
      <RequireRole requiredRole="ADMIN">
        <AdminLayout />
      </RequireRole>
    ),
    children: [{ index: true, element: <AdminHomePage /> }],
  },
];

export const router = createBrowserRouter(routes);
