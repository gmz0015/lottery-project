import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { upsertDraw } from "../api";
import { validateNumbers, type Category } from "../validation";

const parse = (s: string): number[] =>
  s.split(/[\s,]+/).filter(Boolean).map((x) => parseInt(x, 10));

export default function DrawFormPage() {
  const nav = useNavigate();
  const params = useParams();
  const [category, setCategory] = useState<Category>((params.category as Category) || "ssq");
  const [issue, setIssue] = useState(params.issue || "");
  const [front, setFront] = useState("");
  const [back, setBack] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    const f = parse(front);
    const b = parse(back);
    const err = !issue ? "请填写期数" : validateNumbers(category, f, b);
    if (err) { setError(err); return; }
    try {
      await upsertDraw({ category, issue, frontNumbers: f, backNumbers: b });
      nav("/");
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div>
      <h2>录入 / 编辑开奖</h2>
      {error && <div role="alert" style={{ color: "crimson" }}>{error}</div>}
      <label>彩种
        <select value={category} onChange={(e) => setCategory(e.target.value as Category)}>
          <option value="ssq">双色球</option>
          <option value="dlt">大乐透</option>
        </select>
      </label>
      <label htmlFor="issue">期数</label>
      <input id="issue" value={issue} onChange={(e) => setIssue(e.target.value)} />
      <label htmlFor="front">前区/红球</label>
      <input id="front" value={front} onChange={(e) => setFront(e.target.value)} placeholder="空格分隔" />
      <label htmlFor="back">后区/蓝球</label>
      <input id="back" value={back} onChange={(e) => setBack(e.target.value)} placeholder="空格分隔" />
      <button onClick={submit}>保存</button>
    </div>
  );
}
