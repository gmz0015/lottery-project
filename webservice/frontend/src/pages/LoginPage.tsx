import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { login } from "../api";
import { setToken } from "../auth";

export default function LoginPage() {
  const nav = useNavigate();
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    try {
      const { token } = await login(password);
      setToken(token);
      nav("/");
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div>
      <h2>登录</h2>
      {error && <div role="alert" style={{ color: "crimson" }}>{error}</div>}
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="口令" />
      <button onClick={submit}>登录</button>
    </div>
  );
}
