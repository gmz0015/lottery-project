import styles from "./Badge.module.css";

const CATEGORY = {
  ssq: { label: "双色球", tone: "red" },
  dlt: { label: "大乐透", tone: "gold" },
} as const;

type Tone = "red" | "gold" | "green" | "gray";

export default function Badge(
  props: { category: "ssq" | "dlt" } | { label: string; tone: Tone },
) {
  const { label, tone } = "category" in props ? CATEGORY[props.category] : props;
  return <span className={`${styles.badge} ${styles[tone]}`}>{label}</span>;
}
