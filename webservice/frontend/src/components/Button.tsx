import type { ButtonHTMLAttributes } from "react";
import styles from "./Button.module.css";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "text" };

export default function Button({ variant = "primary", className = "", ...rest }: Props) {
  return <button className={`${styles.btn} ${styles[variant]} ${className}`} {...rest} />;
}
