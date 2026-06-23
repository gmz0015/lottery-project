import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { upsertDraw } from "../api";
import { validateNumbers, RULES, type Category } from "../validation";
import Card from "../components/Card";
import Button from "../components/Button";
import Segmented from "../components/Segmented";
import NumberBall, { type BallType } from "../components/NumberBall";
import styles from "./DrawFormPage.module.css";

const parse = (s: string): number[] => s.split(/[\s,]+/).filter(Boolean).map((x) => parseInt(x, 10));
const ballTypes = (c: Category): { front: BallType; back: BallType } =>
  c === "ssq" ? { front: "ssq-red", back: "ssq-blue" } : { front: "dlt-front", back: "dlt-back" };

function Preview({ raw, type }: { raw: string; type: BallType }) {
  const nums = parse(raw).filter((n) => Number.isInteger(n) && n > 0);
  if (nums.length === 0) return null;
  return <div className={styles.preview}>{nums.map((n, i) => <NumberBall key={i} value={n} type={type} size="sm" />)}</div>;
}

export default function DrawFormPage() {
  const nav = useNavigate();
  const params = useParams();
  const editing = Boolean(params.issue);
  const [category, setCategory] = useState<Category>((params.category as Category) || "ssq");
  const [issue, setIssue] = useState(params.issue || "");
  const [front, setFront] = useState("");
  const [back, setBack] = useState("");
  const [prize1, setPrize1] = useState("");
  const [prize2, setPrize2] = useState("");
  const [error, setError] = useState<string | null>(null);
  const t = ballTypes(category);
  const r = RULES[category];

  async function submit() {
    const f = parse(front), b = parse(back);
    const err = !issue ? "请填写期数" : validateNumbers(category, f, b);
    if (err) { setError(err); return; }
    const prizes: Record<string, number> = {};
    if (prize1) prizes["一等奖"] = Number(prize1);
    if (prize2) prizes["二等奖"] = Number(prize2);
    try {
      await upsertDraw({ category, issue, frontNumbers: f, backNumbers: b,
        prizes: Object.keys(prizes).length ? prizes : null });
      nav("/draws");
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div>
      <h1 className={styles.title}>{editing ? "编辑开奖" : "录入开奖"}</h1>
      {error && <div role="alert" className={styles.error}>{error}</div>}

      <Card className={styles.section}>
        <h3 className={styles.h}>基本信息</h3>
        <div className={styles.field}>
          <span className={styles.label}>彩种</span>
          <Segmented value={category} onChange={(v) => setCategory(v as Category)}
            options={[{ label: "双色球", value: "ssq" }, { label: "大乐透", value: "dlt" }]} />
        </div>
        <label className={styles.field}>
          <span className={styles.label}>期数</span>
          <input className={styles.input} aria-label="期数" value={issue}
            onChange={(e) => setIssue(e.target.value)} disabled={editing} />
        </label>
      </Card>

      <Card className={styles.section}>
        <h3 className={styles.h}>开奖号码</h3>
        <label className={styles.field}>
          <span className={styles.label}>前区/红球(共 {r.fc} 个,空格分隔)</span>
          <input className={styles.input} aria-label="前区/红球" value={front}
            onChange={(e) => setFront(e.target.value)}
            placeholder={`例:${Array.from({ length: r.fc }, (_, i) => i + 1).join(" ")}`} />
        </label>
        <Preview raw={front} type={t.front} />
        <label className={styles.field}>
          <span className={styles.label}>后区/蓝球(共 {r.bc} 个,空格分隔)</span>
          <input className={styles.input} aria-label="后区/蓝球" value={back}
            onChange={(e) => setBack(e.target.value)} placeholder={r.bc === 1 ? "例:8" : "例:8 12"} />
        </label>
        <Preview raw={back} type={t.back} />
      </Card>

      <Card className={styles.section}>
        <h3 className={styles.h}>奖金(可选)</h3>
        <label className={styles.field}>
          <span className={styles.label}>一等奖金额</span>
          <input className={styles.input} aria-label="一等奖金额" inputMode="numeric"
            value={prize1} onChange={(e) => setPrize1(e.target.value)} />
        </label>
        <label className={styles.field}>
          <span className={styles.label}>二等奖金额</span>
          <input className={styles.input} aria-label="二等奖金额" inputMode="numeric"
            value={prize2} onChange={(e) => setPrize2(e.target.value)} />
        </label>
      </Card>

      <div className={styles.actions}>
        <Button onClick={submit}>保存</Button>
        <Button variant="secondary" onClick={() => nav("/draws")}>取消</Button>
      </div>
    </div>
  );
}
