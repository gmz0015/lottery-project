import { useState } from "react";
import { useLocation, useNavigate, Link } from "react-router-dom";
import { login } from "../api";
import { setToken } from "../auth";
import Card from "../components/Card";
import Button from "../components/Button";
import styles from "./LoginPage.module.css";

export default function LoginPage() {
  const nav = useNavigate();
  const loc = useLocation();
  const from = (loc.state as { from?: string } | null)?.from || "/draws";
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    try {
      const { token } = await login(password);
      setToken(token);
      nav(from, { replace: true });
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div className={styles.wrap}>
      <Card className={styles.card}>
        <Link to="/" className={styles.logo}>验奖</Link>
        <h2 className={styles.title}>数据管理登录</h2>
        {error && <div role="alert" className={styles.error}>{error}</div>}
        <form onSubmit={submit} className={styles.form}>
          <input className={styles.input} type="password" value={password}
            onChange={(e) => setPassword(e.target.value)} placeholder="访问口令" autoFocus />
          <Button type="submit">登录</Button>
        </form>
      </Card>
    </div>
  );
}
