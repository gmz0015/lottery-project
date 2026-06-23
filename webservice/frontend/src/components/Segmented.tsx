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
