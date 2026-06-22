import { describe, it, expect } from "vitest";
import { validateNumbers } from "../validation";

describe("validateNumbers", () => {
  it("ssq valid -> null", () => {
    expect(validateNumbers("ssq", [1, 2, 3, 4, 5, 6], [16])).toBeNull();
  });
  it("dlt valid -> null", () => {
    expect(validateNumbers("dlt", [1, 2, 3, 4, 35], [1, 12])).toBeNull();
  });
  it("ssq wrong count -> error", () => {
    expect(validateNumbers("ssq", [1, 2, 3], [16])).toContain("6");
  });
  it("ssq out of range -> error", () => {
    expect(validateNumbers("ssq", [1, 2, 3, 4, 5, 34], [16])).toContain("33");
  });
  it("ssq duplicate -> error", () => {
    expect(validateNumbers("ssq", [1, 2, 3, 4, 5, 5], [16])).toContain("重复");
  });
});
