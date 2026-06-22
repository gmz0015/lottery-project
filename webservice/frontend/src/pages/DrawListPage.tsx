import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { listDraws, type Draw } from "../api";

export default function DrawListPage() {
  const [items, setItems] = useState<Draw[]>([]);
  const [category, setCategory] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listDraws(category || undefined).then((r) => setItems(r.items)).catch((e) => setError(e.message));
  }, [category]);

  return (
    <div>
      <h2>开奖列表</h2>
      <Link to="/new">+ 录入</Link>
      <select value={category} onChange={(e) => setCategory(e.target.value)}>
        <option value="">全部</option>
        <option value="ssq">双色球</option>
        <option value="dlt">大乐透</option>
      </select>
      {error && <div role="alert">{error}</div>}
      <ul>
        {items.map((d) => (
          <li key={`${d.category}-${d.issue}`}>
            <Link to={`/draw/${d.category}/${d.issue}`}>
              [{d.category}] {d.issue} — {d.frontNumbers.join(" ")} + {d.backNumbers.join(" ")}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
