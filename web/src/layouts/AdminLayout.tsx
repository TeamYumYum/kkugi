/*
 * 관리자 레이아웃(`/admin/*`). 역할 가드(routes/RequireRole) 안에서만 렌더된다.
 * 관리자 화면은 3개를 넘기지 않는다(ADR-10).
 */
import { NavLink, Outlet } from 'react-router';
import { path } from '../routes/paths';
import styles from './Layout.module.css';

export default function AdminLayout() {
  return (
    <div className={styles.shell}>
      <header className={styles.header}>
        <span className={styles.brand}>냠냠코치 관리자</span>
        <nav aria-label="관리자 메뉴">
          <ul className={styles.nav}>
            <li>
              <NavLink to={path.adminHome()} end>
                관리자 홈
              </NavLink>
            </li>
            <li>
              <NavLink to={path.home()}>대시보드로</NavLink>
            </li>
          </ul>
        </nav>
      </header>
      <Outlet />
    </div>
  );
}
