# Web 前端重设计 + Mac App 介绍首页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `webservice/frontend/` 重设计登录/列表/表单/详情 4 个页面并新增公开 Landing 首页,建立统一苹果风设计系统。

**Architecture:** 原生 CSS 设计令牌(`tokens.css`)+ CSS Modules + 一组可复用组件(NumberBall/Card/Button/Badge/Segmented/DataField)+ 两种 Layout(Public/App)。路由迁移:首页公开于 `/`,工具页移到 `/draws/*` 并保留登录。先用 Claude Design 出 HTML 原型供视觉确认,再落地 React。

**Tech Stack:** React 18 + Vite 5 + react-router-dom 6 + TypeScript + Vitest + 原生 CSS(零新增依赖)。

## Global Constraints

- 零额外 npm 依赖(不引入 Tailwind / 组件库)。
- 不改动后端 API、`src/api.ts`、`src/auth.ts`、`src/validation.ts` 的逻辑(仅引用)。
- 彩种 / 来源标识用枚举值字符串:`"ssq"` / `"dlt"`。
- 设计令牌值固定:`--bg #FBFBFD`、`--surface #FFFFFF`、`--border #E5E5EA`、`--text #1D1D1F`、`--text-secondary #6E6E73`、`--accent #0071E3`、`--ssq-red #E63946`、`--ssq-blue #1D6FB8`、`--dlt-front #E63946`、`--dlt-back #F4A300`、`--win-green #34C759`。
- 字体栈:`-apple-system, "SF Pro Text", "PingFang SC", system-ui, sans-serif`。
- 圆角:卡片 16px、按钮 12px、号码球 999px。阴影:`0 4px 20px rgba(0,0,0,.06)`。
- 暂无 App 截图/图标/下载链接 → 占位框 + 禁用态「敬请期待」CTA。
- 命令在 `webservice/frontend/` 下运行;测试 `npm test`,构建 `npm run build`,本地 `npm run dev`。

---

## File Structure

**新建:**
- `src/styles/tokens.css` — 全局设计令牌 + reset + base。
- `src/components/NumberBall.tsx` + `.module.css` — 彩色号码球。
- `src/components/Card.tsx` + `.module.css`
- `src/components/Button.tsx` + `.module.css`
- `src/components/Badge.tsx` + `.module.css`
- `src/components/Segmented.tsx` + `.module.css`
- `src/components/DataField.tsx` + `.module.css`
- `src/components/PublicLayout.tsx` + `.module.css` — 公开页顶栏/页脚。
- `src/components/AppLayout.tsx` + `.module.css` — 工具页顶栏。
- `src/pages/LandingPage.tsx` + `.module.css` — 新首页。
- `src/components/__tests__/NumberBall.test.tsx`
- `src/components/__tests__/Segmented.test.tsx`
- `design-prototype/` (Claude Design 产出的 HTML 原型,作为视觉参考,不进 React 构建)

**修改:**
- `src/main.tsx` — 引入 `tokens.css`。
- `src/App.tsx` — 路由迁移到 `/draws/*` + 公开 `/` + 登录回跳。
- `src/pages/LoginPage.tsx` — 重写 UI + 回跳。
- `src/pages/DrawListPage.tsx` — 重写 UI(卡片 + 号码球 + 分段筛选)。
- `src/pages/DrawFormPage.tsx` — 重写 UI(分组卡片 + 球形输入)。
- `src/pages/DrawDetailPage.tsx` — 重写 UI(大号码球 + 奖金表)。
- `src/__tests__/DrawFormPage.test.tsx` — 适配新表单的可访问标签。
- `index.html` — 标题改为「验奖 · 大乐透/双色球」。

---

## Task 1: Claude Design 高保真原型(视觉确认)

**Files:**
- Create: `design-prototype/index.html`(由 Claude Design 生成或导出)

**目的:** 在动 React 前用 Claude Design 产出 5 个页面 + 设计系统的高保真 HTML 原型,渲染预览供用户确认视觉方向。

- [ ] **Step 1:** 用 `mcp__claude_design__create_project` 创建项目「Lottery Web Redesign」。
- [ ] **Step 2:** 用 `write_files` 写入符合本设计文档(令牌/号码球/5 页面布局)的单页 HTML 原型(含 design system 展示区 + Landing + Login + List + Form + Detail)。
- [ ] **Step 3:** 用 `render_preview` 渲染,把预览给用户确认。
- [ ] **Step 4:** 用户确认后,导出 HTML 到 `design-prototype/` 作为落地参考。
- [ ] **Step 5:** Commit。

```bash
git add design-prototype/
git commit -m "design: Claude Design 高保真原型(视觉参考)"
```

> 若 Claude Design 工具不可用,降级为:直接按本文档令牌实现 React,跳过原型导出(不阻塞后续任务)。

---

## Task 2: 设计令牌与全局样式

**Files:**
- Create: `src/styles/tokens.css`
- Modify: `src/main.tsx`、`index.html`

**Interfaces:**
- Produces: 全局 CSS 变量(见 Global Constraints),供所有 `*.module.css` 通过 `var(--x)` 引用。

- [ ] **Step 1:** 创建 `src/styles/tokens.css`

```css
:root {
  --bg: #FBFBFD;
  --surface: #FFFFFF;
  --border: #E5E5EA;
  --text: #1D1D1F;
  --text-secondary: #6E6E73;
  --accent: #0071E3;
  --ssq-red: #E63946;
  --ssq-blue: #1D6FB8;
  --dlt-front: #E63946;
  --dlt-back: #F4A300;
  --win-green: #34C759;

  --radius-card: 16px;
  --radius-btn: 12px;
  --shadow-card: 0 4px 20px rgba(0, 0, 0, 0.06);

  --s1: 4px; --s2: 8px; --s3: 12px; --s4: 16px;
  --s5: 24px; --s6: 32px; --s7: 48px; --s8: 64px;

  --font: -apple-system, "SF Pro Text", "PingFang SC", system-ui, sans-serif;
}

* { box-sizing: border-box; }

html, body, #root { margin: 0; padding: 0; min-height: 100%; }

body {
  font-family: var(--font);
  color: var(--text);
  background: var(--bg);
  -webkit-font-smoothing: antialiased;
  line-height: 1.5;
}

a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }

.tabular { font-variant-numeric: tabular-nums; }
```

- [ ] **Step 2:** 在 `src/main.tsx` 顶部引入(import 第一行)

```tsx
import "./styles/tokens.css";
```

- [ ] **Step 3:** 修改 `index.html` 的 `<title>` 为 `验奖 · 大乐透/双色球`。
- [ ] **Step 4:** 运行 `npm run dev` 确认无报错(背景变近白、字体生效)。
- [ ] **Step 5:** Commit `git add -A && git commit -m "feat(web): 添加设计令牌与全局样式"`

---

## Task 3: 核心 UI 组件

**Files:**
- Create: `src/components/{NumberBall,Card,Button,Badge,Segmented,DataField}.tsx` (+ 各自 `.module.css`)
- Test: `src/components/__tests__/NumberBall.test.tsx`、`src/components/__tests__/Segmented.test.tsx`

**Interfaces:**
- Produces:
  - `NumberBall({ value, type, size })` — `type: 'ssq-red'|'ssq-blue'|'dlt-front'|'dlt-back'`,`size?: 'lg'|'md'|'sm'`(默认 md)。渲染 `<span role="img" aria-label="号码 {value}">`。
  - `Card({ children, className?, as? })` — 容器。
  - `Button({ variant?, children, ...buttonProps })` — `variant: 'primary'|'secondary'|'text'`(默认 primary)。透传原生 button 属性(含 `disabled`、`onClick`、`type`)。
  - `Badge({ category })` 或 `Badge({ label, tone })` — 彩种标签:`category: 'ssq'|'dlt'`;通用:`tone: 'red'|'gold'|'green'|'gray'`。
  - `Segmented({ options, value, onChange })` — `options: {label:string; value:string}[]`,渲染 `role="tablist"` + 每项 `role="tab"` `aria-selected`。
  - `DataField({ label, value })` — 标签+值成对。

- [ ] **Step 1: 写 NumberBall 失败测试** `src/components/__tests__/NumberBall.test.tsx`

```tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import NumberBall from "../NumberBall";

describe("NumberBall", () => {
  it("渲染补零后的号码并带可访问标签", () => {
    render(<NumberBall value={7} type="ssq-red" />);
    const el = screen.getByLabelText("号码 7");
    expect(el).toHaveTextContent("07");
  });
});
```

- [ ] **Step 2:** 运行 `npx vitest run src/components/__tests__/NumberBall.test.tsx` → FAIL(模块不存在)。

- [ ] **Step 3:** 创建 `src/components/NumberBall.tsx`

```tsx
import styles from "./NumberBall.module.css";

export type BallType = "ssq-red" | "ssq-blue" | "dlt-front" | "dlt-back";

export default function NumberBall({
  value, type, size = "md",
}: { value: number; type: BallType; size?: "lg" | "md" | "sm" }) {
  const text = String(value).padStart(2, "0");
  return (
    <span
      role="img"
      aria-label={`号码 ${value}`}
      className={`${styles.ball} ${styles[type]} ${styles[size]}`}
    >
      {text}
    </span>
  );
}
```

- [ ] **Step 4:** 创建 `src/components/NumberBall.module.css`

```css
.ball {
  display: inline-flex; align-items: center; justify-content: center;
  border-radius: 999px; color: #fff; font-weight: 600;
  font-variant-numeric: tabular-nums;
  background-image: linear-gradient(160deg, rgba(255,255,255,.35), rgba(255,255,255,0) 55%);
  box-shadow: inset 0 -2px 4px rgba(0,0,0,.18), 0 1px 3px rgba(0,0,0,.2);
}
.lg { width: 48px; height: 48px; font-size: 20px; }
.md { width: 36px; height: 36px; font-size: 16px; }
.sm { width: 28px; height: 28px; font-size: 13px; }
.ssq-red, .dlt-front { background-color: var(--ssq-red); }
.ssq-blue { background-color: var(--ssq-blue); }
.dlt-back { background-color: var(--dlt-back); }
```

- [ ] **Step 5:** 运行 NumberBall 测试 → PASS。

- [ ] **Step 6:** 创建 `Card.tsx` + `Card.module.css`

```tsx
import type { ReactNode } from "react";
import styles from "./Card.module.css";
export default function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`${styles.card} ${className}`}>{children}</div>;
}
```
```css
.card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-card); box-shadow: var(--shadow-card);
  padding: var(--s5);
}
```

- [ ] **Step 7:** 创建 `Button.tsx` + `Button.module.css`

```tsx
import type { ButtonHTMLAttributes } from "react";
import styles from "./Button.module.css";
type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "text" };
export default function Button({ variant = "primary", className = "", ...rest }: Props) {
  return <button className={`${styles.btn} ${styles[variant]} ${className}`} {...rest} />;
}
```
```css
.btn { font: inherit; font-weight: 600; border-radius: var(--radius-btn);
  padding: 10px 18px; cursor: pointer; border: 1px solid transparent; transition: opacity .15s; }
.btn:disabled { opacity: .45; cursor: not-allowed; }
.primary { background: var(--accent); color: #fff; }
.secondary { background: var(--surface); color: var(--text); border-color: var(--border); }
.text { background: transparent; color: var(--accent); padding: 6px 8px; }
.btn:not(:disabled):hover { opacity: .88; }
```

- [ ] **Step 8:** 创建 `Badge.tsx` + `Badge.module.css`

```tsx
import styles from "./Badge.module.css";
const CATEGORY = { ssq: { label: "双色球", tone: "red" }, dlt: { label: "大乐透", tone: "gold" } } as const;
type Tone = "red" | "gold" | "green" | "gray";
export default function Badge(
  props: { category: "ssq" | "dlt" } | { label: string; tone: Tone },
) {
  const { label, tone } = "category" in props ? CATEGORY[props.category] : props;
  return <span className={`${styles.badge} ${styles[tone]}`}>{label}</span>;
}
```
```css
.badge { display: inline-block; padding: 2px 10px; border-radius: 999px;
  font-size: 13px; font-weight: 600; }
.red { background: rgba(230,57,70,.12); color: var(--ssq-red); }
.gold { background: rgba(244,163,0,.16); color: #B9760A; }
.green { background: rgba(52,199,89,.14); color: #1E8E3E; }
.gray { background: rgba(110,110,115,.12); color: var(--text-secondary); }
```

- [ ] **Step 9: 写 Segmented 失败测试** `src/components/__tests__/Segmented.test.tsx`

```tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import Segmented from "../Segmented";

describe("Segmented", () => {
  it("点击选项触发 onChange 且标记选中", () => {
    const onChange = vi.fn();
    render(<Segmented value="ssq" onChange={onChange}
      options={[{ label: "双色球", value: "ssq" }, { label: "大乐透", value: "dlt" }]} />);
    expect(screen.getByRole("tab", { name: "双色球" })).toHaveAttribute("aria-selected", "true");
    fireEvent.click(screen.getByRole("tab", { name: "大乐透" }));
    expect(onChange).toHaveBeenCalledWith("dlt");
  });
});
```

- [ ] **Step 10:** 运行 → FAIL。创建 `Segmented.tsx` + `Segmented.module.css`

```tsx
import styles from "./Segmented.module.css";
export interface SegOption { label: string; value: string; }
export default function Segmented({
  options, value, onChange,
}: { options: SegOption[]; value: string; onChange: (v: string) => void }) {
  return (
    <div role="tablist" className={styles.group}>
      {options.map((o) => (
        <button key={o.value} role="tab" type="button" aria-selected={value === o.value}
          className={`${styles.seg} ${value === o.value ? styles.active : ""}`}
          onClick={() => onChange(o.value)}>{o.label}</button>
      ))}
    </div>
  );
}
```
```css
.group { display: inline-flex; background: #EFEFF4; border-radius: 10px; padding: 3px; gap: 2px; }
.seg { font: inherit; border: none; background: transparent; color: var(--text);
  padding: 6px 16px; border-radius: 8px; cursor: pointer; font-weight: 500; }
.active { background: var(--surface); box-shadow: 0 1px 3px rgba(0,0,0,.12); }
```

- [ ] **Step 11:** 运行 Segmented 测试 → PASS。

- [ ] **Step 12:** 创建 `DataField.tsx` + `DataField.module.css`

```tsx
import type { ReactNode } from "react";
import styles from "./DataField.module.css";
export default function DataField({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className={styles.field}>
      <span className={styles.label}>{label}</span>
      <span className={`${styles.value} tabular`}>{value}</span>
    </div>
  );
}
```
```css
.field { display: flex; justify-content: space-between; align-items: baseline;
  padding: 12px 0; border-bottom: 1px solid var(--border); gap: var(--s4); }
.label { color: var(--text-secondary); font-size: 14px; }
.value { font-weight: 600; }
```

- [ ] **Step 13:** 运行全部组件测试 `npx vitest run src/components` → PASS。

- [ ] **Step 14:** Commit `git add -A && git commit -m "feat(web): 添加核心 UI 组件(NumberBall/Card/Button/Badge/Segmented/DataField)"`

---

## Task 4: 布局与路由迁移

**Files:**
- Create: `src/components/PublicLayout.tsx` (+ css)、`src/components/AppLayout.tsx` (+ css)
- Modify: `src/App.tsx`

**Interfaces:**
- Consumes: `Button`(Task 3)、`getToken`/`clearToken`(`src/auth.ts`)。
- Produces:
  - `PublicLayout({ children })` — 公开页顶栏(Logo「验奖」+「进入数据管理」按钮 → `/draws`)+ 页脚。
  - `AppLayout({ children })` — 工具页顶栏(Logo + 退出登录,`clearToken()` 后跳 `/login`)。
  - 路由:`/` 公开 Landing;`/login`;`/draws`、`/draws/new`、`/draws/edit/:category/:issue`、`/draws/:category/:issue` 受 `RequireAuth` 保护;`RequireAuth` 未登录跳 `/login` 并携带 `state.from`。

- [ ] **Step 1:** 创建 `src/components/AppLayout.tsx`

```tsx
import type { ReactNode } from "react";
import { Link, useNavigate } from "react-router-dom";
import { clearToken } from "../auth";
import Button from "./Button";
import styles from "./AppLayout.module.css";

export default function AppLayout({ children }: { children: ReactNode }) {
  const nav = useNavigate();
  return (
    <div className={styles.shell}>
      <header className={styles.bar}>
        <Link to="/draws" className={styles.logo}>验奖 · 数据管理</Link>
        <Button variant="text" onClick={() => { clearToken(); nav("/login"); }}>退出登录</Button>
      </header>
      <main className={styles.main}>{children}</main>
    </div>
  );
}
```

- [ ] **Step 2:** 创建 `src/components/AppLayout.module.css`

```css
.shell { min-height: 100vh; }
.bar { display: flex; align-items: center; justify-content: space-between;
  padding: var(--s3) var(--s5); background: rgba(255,255,255,.8);
  backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 10; }
.logo { font-weight: 700; color: var(--text); }
.main { max-width: 880px; margin: 0 auto; padding: var(--s6) var(--s4); }
```

- [ ] **Step 3:** 创建 `src/components/PublicLayout.tsx`

```tsx
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
```

- [ ] **Step 4:** 创建 `src/components/PublicLayout.module.css`

```css
.shell { min-height: 100vh; display: flex; flex-direction: column; }
.bar { display: flex; align-items: center; justify-content: space-between;
  padding: var(--s3) var(--s5); position: sticky; top: 0; z-index: 10;
  background: rgba(251,251,253,.8); backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid var(--border); }
.logo { font-weight: 700; font-size: 18px; color: var(--text); }
.footer { margin-top: auto; display: flex; gap: var(--s5); justify-content: center;
  align-items: center; padding: var(--s6); color: var(--text-secondary);
  font-size: 14px; border-top: 1px solid var(--border); }
```

- [ ] **Step 5:** 重写 `src/App.tsx`

```tsx
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { getToken } from "./auth";
import LandingPage from "./pages/LandingPage";
import LoginPage from "./pages/LoginPage";
import DrawListPage from "./pages/DrawListPage";
import DrawFormPage from "./pages/DrawFormPage";
import DrawDetailPage from "./pages/DrawDetailPage";
import AppLayout from "./components/AppLayout";

function RequireAuth({ children }: { children: JSX.Element }) {
  const loc = useLocation();
  if (!getToken()) return <Navigate to="/login" replace state={{ from: loc.pathname }} />;
  return <AppLayout>{children}</AppLayout>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/draws" element={<RequireAuth><DrawListPage /></RequireAuth>} />
      <Route path="/draws/new" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/draws/edit/:category/:issue" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/draws/:category/:issue" element={<RequireAuth><DrawDetailPage /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
```

- [ ] **Step 6:** `npx tsc -b` 此时会因 `LandingPage` 等未重写而报错属预期;先 `git add src/components/AppLayout* src/components/PublicLayout* src/App.tsx`,在 Task 5-9 完成后统一构建。先 Commit 布局:`git commit -m "feat(web): 添加 Public/App 布局与路由迁移到 /draws"`(LandingPage 等将在后续任务补齐)。

> 注:为避免中间态 import 报错,建议把 Task 4 与 Task 5-9 视为一个连续批次执行,最后在 Task 10 统一 `npm run build`。

---

## Task 5: Landing 首页

**Files:**
- Create: `src/pages/LandingPage.tsx` + `LandingPage.module.css`

**Interfaces:**
- Consumes: `PublicLayout`、`Card`、`Button`、`Badge`、`NumberBall`。

- [ ] **Step 1:** 创建 `src/pages/LandingPage.tsx`

```tsx
import { Link } from "react-router-dom";
import PublicLayout from "../components/PublicLayout";
import Card from "../components/Card";
import Button from "../components/Button";
import Badge from "../components/Badge";
import NumberBall, { type BallType } from "../components/NumberBall";
import styles from "./LandingPage.module.css";

const FEATURES = [
  { icon: "📷", title: "拍照识别号码", desc: "多模态 AI 识别彩票照片上的号码,识别后由你确认。" },
  { icon: "✅", title: "一键验奖", desc: "大乐透 / 双色球自动比对,逐注计算中奖等级与奖金。" },
  { icon: "🌐", title: "官方开奖同步", desc: "自动获取官方/自建数据源开奖结果,带版本快照。" },
  { icon: "📈", title: "中奖记录与盈亏图表", desc: "记录每张票,直观看投入与回报趋势。" },
  { icon: "🔒", title: "本地存储 · 隐私", desc: "数据存于本机 SwiftData,你的彩票信息不上云。" },
];
const STEPS = ["拍照", "识别确认", "验奖", "记录"];
const DEMO: { value: number; type: BallType }[] = [
  { value: 3, type: "dlt-front" }, { value: 11, type: "dlt-front" }, { value: 18, type: "dlt-front" },
  { value: 27, type: "dlt-front" }, { value: 33, type: "dlt-front" },
  { value: 4, type: "dlt-back" }, { value: 9, type: "dlt-back" },
];

export default function LandingPage() {
  return (
    <PublicLayout>
      <section className={styles.hero}>
        <div className={styles.heroText}>
          <h1 className={styles.title}>拍张照,自动验奖</h1>
          <p className={styles.subtitle}>大乐透 / 双色球验奖助手 —— 拍照识别号码,一键比对开奖,自动记录盈亏。</p>
          <Button disabled title="敬请期待">下载 App · 敬请期待</Button>
        </div>
        <div className={styles.shot} aria-label="App 截图占位">Mac App 截图</div>
      </section>

      <section className={styles.features}>
        {FEATURES.map((f) => (
          <Card key={f.title} className={styles.feature}>
            <div className={styles.icon} aria-hidden>{f.icon}</div>
            <h3>{f.title}</h3>
            <p>{f.desc}</p>
          </Card>
        ))}
      </section>

      <section className={styles.flow}>
        <h2>四步搞定</h2>
        <div className={styles.steps}>
          {STEPS.map((s, i) => (
            <div key={s} className={styles.step}>
              <span className={styles.stepNo}>{i + 1}</span><span>{s}</span>
            </div>
          ))}
        </div>
      </section>

      <section className={styles.support}>
        <div className={styles.tags}><Badge category="dlt" /><Badge category="ssq" /></div>
        <div className={styles.balls}>
          {DEMO.map((b, i) => <NumberBall key={i} value={b.value} type={b.type} />)}
        </div>
        <Link to="/draws"><Button variant="secondary">进入数据管理 →</Button></Link>
      </section>
    </PublicLayout>
  );
}
```

- [ ] **Step 2:** 创建 `src/pages/LandingPage.module.css`

```css
.hero { display: grid; grid-template-columns: 1fr 1fr; gap: var(--s7);
  align-items: center; max-width: 1040px; margin: 0 auto; padding: var(--s8) var(--s4); }
.title { font-size: 52px; line-height: 1.1; margin: 0 0 var(--s4); letter-spacing: -1px; }
.subtitle { font-size: 19px; color: var(--text-secondary); margin: 0 0 var(--s5); }
.shot { aspect-ratio: 4/3; border-radius: var(--radius-card); border: 1px solid var(--border);
  background: linear-gradient(160deg,#fff,#f1f1f5); box-shadow: var(--shadow-card);
  display: flex; align-items: center; justify-content: center; color: var(--text-secondary); }
.features { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--s4);
  max-width: 1040px; margin: 0 auto; padding: var(--s6) var(--s4); }
.feature h3 { margin: var(--s3) 0 var(--s2); font-size: 18px; }
.feature p { margin: 0; color: var(--text-secondary); font-size: 15px; }
.icon { font-size: 28px; }
.flow { text-align: center; padding: var(--s7) var(--s4); }
.steps { display: flex; gap: var(--s4); justify-content: center; flex-wrap: wrap; margin-top: var(--s5); }
.step { display: flex; align-items: center; gap: var(--s2); background: var(--surface);
  border: 1px solid var(--border); border-radius: 999px; padding: 8px 18px; font-weight: 600; }
.stepNo { width: 24px; height: 24px; border-radius: 999px; background: var(--accent); color: #fff;
  display: inline-flex; align-items: center; justify-content: center; font-size: 13px; }
.support { text-align: center; padding: var(--s7) var(--s4) var(--s8); }
.tags { display: flex; gap: var(--s2); justify-content: center; margin-bottom: var(--s4); }
.balls { display: flex; gap: var(--s2); justify-content: center; margin-bottom: var(--s5); flex-wrap: wrap; }
@media (max-width: 760px) {
  .hero { grid-template-columns: 1fr; padding: var(--s6) var(--s4); }
  .title { font-size: 38px; }
  .features { grid-template-columns: 1fr; }
}
```

- [ ] **Step 3:** Commit(可与 Task 4 合并)`git add -A && git commit -m "feat(web): 添加 Mac App 介绍首页"`

---

## Task 6: 登录页重写

**Files:**
- Modify: `src/pages/LoginPage.tsx`
- Create: `src/pages/LoginPage.module.css`

**Interfaces:**
- Consumes: `login`(api)、`setToken`(auth)、`Card`、`Button`、`useLocation().state.from`。

- [ ] **Step 1:** 重写 `src/pages/LoginPage.tsx`

```tsx
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
```

- [ ] **Step 2:** 创建 `src/pages/LoginPage.module.css`

```css
.wrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: var(--s4); }
.card { width: 100%; max-width: 360px; text-align: center; }
.logo { font-weight: 700; font-size: 20px; color: var(--text); }
.title { margin: var(--s4) 0 var(--s5); font-size: 20px; }
.form { display: flex; flex-direction: column; gap: var(--s3); }
.input { font: inherit; padding: 12px 14px; border: 1px solid var(--border);
  border-radius: var(--radius-btn); background: var(--bg); }
.input:focus { outline: 2px solid var(--accent); outline-offset: 0; border-color: transparent; }
.error { color: var(--ssq-red); background: rgba(230,57,70,.1); border-radius: 10px;
  padding: 8px 12px; font-size: 14px; margin-bottom: var(--s3); }
```

- [ ] **Step 3:** Commit `git add -A && git commit -m "feat(web): 重设计登录页"`

---

## Task 7: 开奖列表页重写

**Files:**
- Modify: `src/pages/DrawListPage.tsx`
- Create: `src/pages/DrawListPage.module.css`

**Interfaces:**
- Consumes: `listDraws`、`Draw`(api)、`Card`、`Button`、`Badge`、`Segmented`、`NumberBall`。
- 号码球颜色规则:ssq → 前区 `ssq-red`、后区 `ssq-blue`;dlt → 前区 `dlt-front`、后区 `dlt-back`。封装为模块内辅助 `ballTypes(category)`。

- [ ] **Step 1:** 重写 `src/pages/DrawListPage.tsx`

```tsx
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
```

- [ ] **Step 2:** 创建 `src/pages/DrawListPage.module.css`

```css
.head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--s4); }
.title { font-size: 28px; margin: 0; }
.list { margin-top: var(--s4); display: flex; flex-direction: column; gap: var(--s3); }
.row { display: block; }
.card { display: flex; align-items: center; gap: var(--s4); padding: var(--s4) var(--s5);
  transition: box-shadow .15s, transform .15s; }
.row:hover .card { box-shadow: 0 6px 24px rgba(0,0,0,.1); transform: translateY(-1px); }
.meta { display: flex; flex-direction: column; gap: 4px; min-width: 96px; }
.issue { color: var(--text); font-weight: 600; }
.date { color: var(--text-secondary); font-size: 13px; }
.balls { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; flex: 1; }
.plus { color: var(--text-secondary); margin: 0 2px; }
.arrow { color: var(--text-secondary); font-size: 22px; }
.empty { text-align: center; color: var(--text-secondary); margin-top: var(--s4); }
.error { color: var(--ssq-red); background: rgba(230,57,70,.1); border-radius: 10px;
  padding: 8px 12px; font-size: 14px; margin-top: var(--s3); }
```

- [ ] **Step 3:** Commit `git add -A && git commit -m "feat(web): 重设计开奖列表页"`

---

## Task 8: 录入/编辑表单页重写

**Files:**
- Modify: `src/pages/DrawFormPage.tsx`、`src/__tests__/DrawFormPage.test.tsx`
- Create: `src/pages/DrawFormPage.module.css`

**Interfaces:**
- Consumes: `upsertDraw`(api)、`validateNumbers`/`RULES`/`Category`(validation)、`Card`、`Button`、`Segmented`、`NumberBall`。
- 保留可访问标签:期数输入 `aria-label="期数"`;号码用文本输入(空格/逗号分隔)并 `aria-label="前区/红球"`、`aria-label="后区/蓝球"`,实时把已解析的合法号码渲染为 NumberBall 预览。保存按钮文本「保存」。**测试据此更新为用 `getByLabelText`。**

- [ ] **Step 1:** 更新 `src/__tests__/DrawFormPage.test.tsx`(把 `screen.getByLabelText` 目标改为新 aria-label;断言不变)

```tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import DrawFormPage from "../pages/DrawFormPage";

vi.mock("../api", () => ({ upsertDraw: vi.fn().mockResolvedValue({}) }));
import { upsertDraw } from "../api";

function renderForm() {
  render(<MemoryRouter><DrawFormPage /></MemoryRouter>);
}

describe("DrawFormPage", () => {
  it("非法号码时报错且不提交", async () => {
    renderForm();
    fireEvent.change(screen.getByLabelText("期数"), { target: { value: "24001" } });
    fireEvent.change(screen.getByLabelText("前区/红球"), { target: { value: "1 2 3" } });
    fireEvent.change(screen.getByLabelText("后区/蓝球"), { target: { value: "16" } });
    fireEvent.click(screen.getByText("保存"));
    expect(await screen.findByRole("alert")).toBeInTheDocument();
    expect(upsertDraw).not.toHaveBeenCalled();
  });

  it("合法号码时提交", async () => {
    renderForm();
    fireEvent.change(screen.getByLabelText("期数"), { target: { value: "24001" } });
    fireEvent.change(screen.getByLabelText("前区/红球"), { target: { value: "1 2 3 4 5 6" } });
    fireEvent.change(screen.getByLabelText("后区/蓝球"), { target: { value: "16" } });
    fireEvent.click(screen.getByText("保存"));
    await vi.waitFor(() => expect(upsertDraw).toHaveBeenCalledOnce());
  });
});
```

- [ ] **Step 2:** 运行 `npx vitest run src/__tests__/DrawFormPage.test.tsx` → 现有实现仍用 `getByLabelText`(label 包裹),应仍 PASS;若重写后失败再于 Step 4 修正。

- [ ] **Step 3:** 重写 `src/pages/DrawFormPage.tsx`

```tsx
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
            onChange={(e) => setFront(e.target.value)} placeholder={`例:${Array.from({length: r.fc}, (_, i) => i + 1).join(" ")}`} />
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
```

- [ ] **Step 4:** 创建 `src/pages/DrawFormPage.module.css`

```css
.title { font-size: 28px; margin: 0 0 var(--s4); }
.section { margin-bottom: var(--s4); }
.h { margin: 0 0 var(--s4); font-size: 16px; color: var(--text-secondary); }
.field { display: flex; flex-direction: column; gap: var(--s2); margin-bottom: var(--s4); }
.label { font-size: 14px; color: var(--text-secondary); }
.input { font: inherit; padding: 10px 14px; border: 1px solid var(--border);
  border-radius: var(--radius-btn); background: var(--bg); max-width: 360px; }
.input:focus { outline: 2px solid var(--accent); border-color: transparent; }
.input:disabled { opacity: .6; }
.preview { display: flex; gap: 6px; flex-wrap: wrap; margin: -8px 0 var(--s4); }
.actions { display: flex; gap: var(--s3); }
.error { color: var(--ssq-red); background: rgba(230,57,70,.1); border-radius: 10px;
  padding: 8px 12px; font-size: 14px; margin-bottom: var(--s4); }
```

- [ ] **Step 5:** 运行 `npx vitest run src/__tests__/DrawFormPage.test.tsx` → PASS(若失败,核对 aria-label 与「保存」文本)。

- [ ] **Step 6:** Commit `git add -A && git commit -m "feat(web): 重设计录入/编辑表单页(球形号码预览)"`

---

## Task 9: 开奖详情页重写

**Files:**
- Modify: `src/pages/DrawDetailPage.tsx`
- Create: `src/pages/DrawDetailPage.module.css`

**Interfaces:**
- Consumes: `getDraw`、`Draw`(api)、`Category`、`Card`、`Button`、`Badge`、`DataField`、`NumberBall`。

- [ ] **Step 1:** 重写 `src/pages/DrawDetailPage.tsx`

```tsx
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
```

- [ ] **Step 2:** 创建 `src/pages/DrawDetailPage.module.css`

```css
.back { display: inline-block; margin-bottom: var(--s4); }
.head { display: flex; align-items: center; gap: var(--s3); margin-bottom: var(--s5); }
.title { font-size: 28px; margin: 0; }
.date { color: var(--text-secondary); margin-left: auto; }
.numbers { display: flex; justify-content: center; padding: var(--s7) var(--s4); margin-bottom: var(--s4); }
.balls { display: flex; align-items: center; gap: var(--s3); flex-wrap: wrap; justify-content: center; }
.plus { color: var(--text-secondary); font-size: 24px; }
.prizes { margin-bottom: var(--s4); }
.h { margin: 0 0 var(--s3); font-size: 16px; color: var(--text-secondary); }
.muted { color: var(--text-secondary); margin: 0; }
.actions { display: flex; gap: var(--s3); }
.error { color: var(--ssq-red); padding: var(--s5); }
.loading { color: var(--text-secondary); padding: var(--s5); }
```

- [ ] **Step 3:** Commit `git add -A && git commit -m "feat(web): 重设计开奖详情页"`

---

## Task 10: 全量校验与收尾

**Files:** 无新增(校验整体)。

- [ ] **Step 1:** 类型检查 `npx tsc -b` → 无错误。
- [ ] **Step 2:** 全量测试 `npm test` → 全绿(含 NumberBall、Segmented、DrawFormPage、validation)。
- [ ] **Step 3:** 构建 `npm run build` → 成功。
- [ ] **Step 4:** `npm run dev` 手动走查:`/` 首页 → 「进入数据管理」→ 未登录跳 `/login` → 登录后回 `/draws` → 列表/详情/录入号码球渲染正常、响应式(窄屏单列)正常。
- [ ] **Step 5:** 更新 `webservice/README.md` 前端章节(若描述了页面/路由,补充新 `/draws/*` 路由与首页)。
- [ ] **Step 6:** Commit `git add -A && git commit -m "chore(web): 前端重设计收尾(校验/构建/文档)"`

---

## Self-Review 结论

- **Spec 覆盖**:信息架构(Task 4)、设计系统令牌(Task 2)、6 组件(Task 3)、5 页面(Task 5-9)、Claude Design 原型(Task 1)、技术落地(全)、验证(Task 10)均有对应任务。
- **占位扫描**:无 TBD/TODO;CTA「敬请期待」与截图占位是设计意图,非计划占位。
- **类型一致**:`BallType` 四值、`ballTypes()` 辅助、`Segmented` 的 `role="tab"`/`aria-selected`、各 page import 的组件名在 Task 3 统一定义,前后一致。
