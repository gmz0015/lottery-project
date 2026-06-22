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
