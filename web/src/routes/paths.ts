/*
 * 라우트 경로. 화면은 `harness scaffold web screen <Name> --var area=<영역>`이 출력한 조각을 여기와
 * router.tsx에 붙인다. 관리자 화면은 `/admin/*` 아래에 둔다(ADR-10).
 */
export const ROUTE_PATTERN = {
  home: '/',
  adminHome: '/admin',
};

export const path = {
  home: () => ROUTE_PATTERN.home,
  adminHome: () => ROUTE_PATTERN.adminHome,
};
