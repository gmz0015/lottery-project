import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { getDraw, type Draw } from "../api";
import type { Category } from "../validation";
import Card from "../components/Card";
import Button from "../components/Button";
import Badge from "../components/Badge";
import DataField from "../components/DataField";
import NumberBall, { type BallType } from "../components/NumberBall";
import styles from "./DrawDetailPage.module.css";

const ballTypes = (c: Category): { front: BallType; back: BallType } =>
  c === "ssq" ? { front: "ssq-red", back: "ssq-blue" } : { front: "dlt-front", back: "dlt-back" };

export default function DrawDetailPage() {
  const nav = useNavigate();
  const { category = "", issue = "" } = useParams();
  const [draw, setDraw] = useState<Draw | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getDraw(category, issue).then(setDraw).catch((e) => setError(e.message));
  }, [category, issue]);

  if (error) return <div role="alert" className={styles.error}>{error}</div>;
  if (!draw) return <div className={styles.loading}>加载中…</div>;

  const t = ballTypes(draw.category);
  const prizes = draw.prizes ? Object.entries(draw.prizes) : [];
  return (
    <div>
      <Link to="/draws" className={styles.back}>← 返回列表</Link>
      <div className={styles.head}>
        <Badge category={draw.category} />
        <h1 className={styles.title}>第 {draw.issue} 期</h1>
        <span className={styles.date}>{draw.drawDate || "—"}</span>
      </div>

      <Card className={styles.numbers}>
        <div className={styles.balls}>
          {draw.frontNumbers.map((n, i) => <NumberBall key={`f${i}`} value={n} type={t.front} size="lg" />)}
          <span className={styles.plus}>+</span>
          {draw.backNumbers.map((n, i) => <NumberBall key={`b${i}`} value={n} type={t.back} size="lg" />)}
        </div>
      </Card>

      <Card className={styles.prizes}>
        <h3 className={styles.h}>奖级 / 奖金</h3>
        {prizes.length === 0 && <p className={styles.muted}>暂无奖金数据</p>}
        {prizes.map(([k, v]) => <DataField key={k} label={k} value={`¥ ${Number(v).toLocaleString()}`} />)}
      </Card>

      <div className={styles.actions}>
        <Button onClick={() => nav(`/draws/edit/${draw.category}/${draw.issue}`)}>编辑</Button>
        <Button variant="secondary" onClick={() => nav("/draws")}>返回列表</Button>
      </div>
    </div>
  );
}
