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
