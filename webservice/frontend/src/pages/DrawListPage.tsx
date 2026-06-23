import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { listDraws, type Draw } from "../api";
import type { Category } from "../validation";
import Card from "../components/Card";
import Button from "../components/Button";
import Badge from "../components/Badge";
import Segmented from "../components/Segmented";
import NumberBall, { type BallType } from "../components/NumberBall";
import styles from "./DrawListPage.module.css";

function ballTypes(c: Category): { front: BallType; back: BallType } {
  return c === "ssq" ? { front: "ssq-red", back: "ssq-blue" } : { front: "dlt-front", back: "dlt-back" };
}

export default function DrawListPage() {
  const nav = useNavigate();
  const [items, setItems] = useState<Draw[]>([]);
  const [category, setCategory] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listDraws(category || undefined).then((r) => setItems(r.items)).catch((e) => setError(e.message));
  }, [category]);

  return (
    <div>
      <div className={styles.head}>
        <h1 className={styles.title}>开奖记录</h1>
        <Button onClick={() => nav("/draws/new")}>+ 录入</Button>
      </div>
      <Segmented value={category} onChange={setCategory}
        options={[{ label: "全部", value: "" }, { label: "双色球", value: "ssq" }, { label: "大乐透", value: "dlt" }]} />
      {error && <div role="alert" className={styles.error}>{error}</div>}
      {items.length === 0 && !error && (
        <Card className={styles.empty}>还没有开奖记录,点「+ 录入」添加一条。</Card>
      )}
      <div className={styles.list}>
        {items.map((d) => {
          const t = ballTypes(d.category);
          return (
            <Link key={`${d.category}-${d.issue}`} to={`/draws/${d.category}/${d.issue}`} className={styles.row}>
              <Card className={styles.card}>
                <div className={styles.meta}>
                  <Badge category={d.category} />
                  <span className={styles.issue}>第 {d.issue} 期</span>
                  {d.drawDate && <span className={styles.date}>{d.drawDate}</span>}
                </div>
                <div className={styles.balls}>
                  {d.frontNumbers.map((n, i) => <NumberBall key={`f${i}`} value={n} type={t.front} size="sm" />)}
                  <span className={styles.plus}>+</span>
                  {d.backNumbers.map((n, i) => <NumberBall key={`b${i}`} value={n} type={t.back} size="sm" />)}
                </div>
                <span className={styles.arrow} aria-hidden>›</span>
              </Card>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
