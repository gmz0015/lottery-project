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
