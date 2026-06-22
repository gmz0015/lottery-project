import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getDraw, type Draw } from "../api";

export default function DrawDetailPage() {
  const { category = "", issue = "" } = useParams();
  const [draw, setDraw] = useState<Draw | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getDraw(category, issue).then(setDraw).catch((e) => setError(e.message));
  }, [category, issue]);

  if (error) return <div role="alert">{error}</div>;
  if (!draw) return <div>加载中…</div>;
  return (
    <div>
      <Link to="/">← 返回</Link>
      <h2>[{draw.category}] {draw.issue}</h2>
      <p>号码：{draw.frontNumbers.join(" ")} + {draw.backNumbers.join(" ")}</p>
      <p>开奖日期：{draw.drawDate || "—"}</p>
      <p>奖金：{draw.prizes ? JSON.stringify(draw.prizes) : "—"}</p>
      <Link to={`/edit/${draw.category}/${draw.issue}`}>编辑</Link>
    </div>
  );
}
