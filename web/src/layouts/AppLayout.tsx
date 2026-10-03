/*
 * 사용자 대시보드 레이아웃. 화면(pages/)이 `<main>`을 가지므로 여기서는 머리글과 탐색만 둔다.
 * 대시보드 화면은 6개를 넘기지 않는다(ADR-10).
 */
import { NavLink, Outlet } from 'react-router';
import { path } from '../routes/paths';
import styles from './Layout.module.css';

export default function AppLayout() {
  return (
    <div className={styles.shell}>
      <header className={styles.header}>
        <span className={styles.brand}>냠냠코치</span>
        <nav aria-label="주 메뉴">
          <ul className={styles.nav}>
            <li>
              <NavLink to={path.home()} end>
                홈
              </NavLink>
            </li>
          </ul>
        </nav>
      </header>
      <Outlet />
    </div>
  );
}
