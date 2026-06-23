import type { ReactNode } from "react";
import { Link, useNavigate } from "react-router-dom";
import { clearToken } from "../auth";
import Button from "./Button";
import styles from "./AppLayout.module.css";

export default function AppLayout({ children }: { children: ReactNode }) {
  const nav = useNavigate();
  return (
    <div className={styles.shell}>
      <header className={styles.bar}>
        <Link to="/draws" className={styles.logo}>验奖 · 数据管理</Link>
        <Button variant="text" onClick={() => { clearToken(); nav("/login"); }}>退出登录</Button>
      </header>
      <main className={styles.main}>{children}</main>
    </div>
  );
}
