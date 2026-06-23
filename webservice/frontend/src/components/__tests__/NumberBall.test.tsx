import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import NumberBall from "../NumberBall";

describe("NumberBall", () => {
  it("渲染补零后的号码并带可访问标签", () => {
    render(<NumberBall value={7} type="ssq-red" />);
    const el = screen.getByLabelText("号码 7");
    expect(el).toHaveTextContent("07");
  });
});
