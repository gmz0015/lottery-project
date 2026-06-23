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
