import { getToken } from "./auth";
import type { Category } from "./validation";

export interface Draw {
  category: Category;
  issue: string;
  frontNumbers: number[];
  backNumbers: number[];
  drawDate?: string | null;
  prizes?: Record<string, number> | null;
  createdAt?: string;
  updatedAt?: string;
}
export interface DrawList { items: Draw[]; total: number; page: number; pageSize: number; }

async function req(path: string, init: RequestInit = {}) {
  const headers: Record<string, string> = { "Content-Type": "application/json", ...(init.headers as any) };
  const t = getToken();
  if (t) headers["Authorization"] = `Bearer ${t}`;
  const res = await fetch(`/api/v1${path}`, { ...init, headers });
  if (!res.ok) {
    const detail = await res.json().catch(() => ({}));
    throw new Error(detail.detail || `请求失败 ${res.status}`);
  }
  return res.status === 204 ? null : res.json();
}

export const login = (password: string): Promise<{ token: string }> =>
  req("/auth/login", { method: "POST", body: JSON.stringify({ password }) });
export const listDraws = (category?: string, page = 1): Promise<DrawList> =>
  req(`/draws?${category ? `category=${category}&` : ""}page=${page}`);
export const getDraw = (category: string, issue: string): Promise<Draw> =>
  req(`/draws/${category}/${issue}`);
export const upsertDraw = (draw: Draw): Promise<Draw> =>
  req("/draws", { method: "POST", body: JSON.stringify(draw) });
export const deleteDraw = (category: string, issue: string): Promise<null> =>
  req(`/draws/${category}/${issue}`, { method: "DELETE" });
