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
