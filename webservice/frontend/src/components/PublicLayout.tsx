import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import Button from "./Button";
import styles from "./PublicLayout.module.css";

export default function PublicLayout({ children }: { children: ReactNode }) {
  return (
    <div className={styles.shell}>
      <header className={styles.bar}>
        <Link to="/" className={styles.logo}>验奖</Link>
        <Link to="/draws"><Button variant="secondary">进入数据管理</Button></Link>
      </header>
      <main>{children}</main>
      <footer className={styles.footer}>
        <span>验奖 · 大乐透 / 双色球</span>
        <a href="https://github.com" target="_blank" rel="noreferrer">GitHub</a>
        <Link to="/draws">进入数据管理</Link>
      </footer>
    </div>
  );
}
