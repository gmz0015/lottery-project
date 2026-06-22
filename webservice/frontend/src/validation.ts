export type Category = "ssq" | "dlt";

export const RULES: Record<Category, { fc: number; fmax: number; bc: number; bmax: number }> = {
  ssq: { fc: 6, fmax: 33, bc: 1, bmax: 16 },
  dlt: { fc: 5, fmax: 35, bc: 2, bmax: 12 },
};

function check(name: string, nums: number[], count: number, max: number): string | null {
  if (nums.length !== count) return `${name}必须为 ${count} 个号码`;
  if (new Set(nums).size !== nums.length) return `${name}不能重复`;
  for (const n of nums) {
    if (!Number.isInteger(n) || n < 1 || n > max) return `${name}范围应为 1-${max}`;
  }
  return null;
}

export function validateNumbers(category: Category, front: number[], back: number[]): string | null {
  const r = RULES[category];
  if (!r) return `未知彩种: ${category}`;
  return check("前区/红球", front, r.fc, r.fmax) ?? check("后区/蓝球", back, r.bc, r.bmax);
}
