import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import App from "./App";


afterEach(() => vi.restoreAllMocks());

describe("Hotspot Lab", () => {
  it("keeps scenario limitations visible while rendering an empty response", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          type: "FeatureCollection",
          scenario_id: "v0_3_equal_group_internal_simulation_r150",
          release_state: "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY",
          features: [],
          next_page_token: null,
          truncated: false,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

    render(<App />);
    expect(screen.getByText("Ordinal simulation index—not probability.")).toBeVisible();
    expect(screen.getByText("Specification pending lock")).toBeVisible();
    expect(screen.getByText("Operational use prohibited")).toBeVisible();
    await waitFor(() => {
      expect(screen.getByText("API 沒有回傳可顯示的 cells。")).toBeVisible();
    });
    expect(screen.getByText("預註冊權重（唯讀）")).toBeVisible();
  });
});
