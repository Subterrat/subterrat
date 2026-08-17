import { afterEach, describe, expect, it, vi } from "vitest";

import { fetchAllLabCells, fetchNetworkCells, fetchNetworkLinks } from "./api";
import type { LabCellFeature, NetworkCell } from "./types";


function featurePage(
  features: LabCellFeature[],
  nextPageToken: string | null,
): Response {
  return new Response(
    JSON.stringify({
      type: "FeatureCollection",
      scenario_id: "v0_3_equal_group_internal_simulation_r150",
      release_state: "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY",
      features,
      next_page_token: nextPageToken,
      truncated: false,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}


afterEach(() => vi.restoreAllMocks());

describe("v0.3 lab API pagination", () => {
  it("loads all 3,420 Taipei cells across three bounded pages", async () => {
    const cells = Array.from(
      { length: 3420 },
      (_, index) => ({ id: String(index + 1) }) as LabCellFeature,
    );
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(featurePage(cells.slice(0, 1500), "page-2"))
      .mockResolvedValueOnce(featurePage(cells.slice(1500, 3000), "page-3"))
      .mockResolvedValueOnce(featurePage(cells.slice(3000), null));

    const result = await fetchAllLabCells("http://127.0.0.1:8080");

    expect(result).toHaveLength(3420);
    expect(new Set(result.map((cell) => cell.id)).size).toBe(3420);
    expect(fetchMock).toHaveBeenCalledTimes(3);

    const requestedUrls = fetchMock.mock.calls.map(
      ([request]) => new URL(String(request)),
    );
    expect(requestedUrls.map((url) => url.searchParams.get("limit"))).toEqual([
      "1500",
      "1500",
      "1500",
    ]);
    expect(
      requestedUrls.map((url) => url.searchParams.get("page_token")),
    ).toEqual([null, "page-2", "page-3"]);
    expect(
      requestedUrls.map((url) => url.searchParams.get("bbox")),
    ).toEqual([
      "121.45,24.95,121.67,25.22",
      "121.45,24.95,121.67,25.22",
      "121.45,24.95,121.67,25.22",
    ]);
  });

  it("requests only locked network scenario and abstract iteration inputs", async () => {
    const networkCell = {
      cell_id: "1",
      eligible_geojson: '{"type":"Polygon","coordinates":[]}',
      relative_synthetic_network_state: "0.000000000000",
      sewer_attribute_available: true,
      eligible_sewer_neighbor_count: 1,
      eligible_generic_neighbor_count: 1,
      self_only_transition_row: false,
      cell_support_state: "METRIC_SEWER_SUPPORTED",
      cell_limitation_codes: [],
    } as NetworkCell;
    const cells = Array.from({ length: 3420 }, (_, index) => ({
      ...networkCell,
      cell_id: String(index + 1),
    }));
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          kind: "NETWORK_REDISTRIBUTION_CELLS",
          metadata: {
            schema_version: "0.3.0",
            contract_hash: "0".repeat(64),
            finalized_input_manifest_hash: "0".repeat(64),
            run_id: "0".repeat(64),
            scenario_id: "n1_metric_weighted_sewer_links",
            abstract_iteration: 3,
            normalization_scope: "LOCKED_RUN_GLOBAL_ALL_SCENARIOS_AND_ITERATIONS",
            display_scale_max: "1.000000000000000000000000",
            use_state: "INTERNAL_SIMULATION_ONLY",
            evidence_state: "NO_TRUSTED_RESULT",
            operational_use: "PROHIBITED",
            global_limitation_codes: ["NO_TRUSTED_RESULT"],
          },
          cells,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

    const result = await fetchNetworkCells(
      "http://127.0.0.1:8080",
      "n1_metric_weighted_sewer_links",
      3,
    );
    expect(result.cells).toHaveLength(3420);
    const url = new URL(String(fetchMock.mock.calls[0][0]));
    expect(url.searchParams.get("scenario_id")).toBe(
      "n1_metric_weighted_sewer_links",
    );
    expect(url.searchParams.get("abstract_iteration")).toBe("3");
  });

  it("loads scenario-scoped schematic links without an iteration parameter", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          kind: "NETWORK_REDISTRIBUTION_LINKS",
          metadata: {
            schema_version: "0.3.0",
            contract_hash: "0".repeat(64),
            finalized_input_manifest_hash: "0".repeat(64),
            run_id: "0".repeat(64),
            scenario_id: "n2_generic_cell_adjacency_sensitivity",
            use_state: "INTERNAL_SIMULATION_ONLY",
            evidence_state: "NO_TRUSTED_RESULT",
            operational_use: "PROHIBITED",
            global_limitation_codes: ["NO_TRUSTED_RESULT"],
          },
          links: [],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
    await fetchNetworkLinks(
      "http://127.0.0.1:8080",
      "n2_generic_cell_adjacency_sensitivity",
    );
    const url = new URL(String(fetchMock.mock.calls[0][0]));
    expect(url.searchParams.get("scenario_id")).toBe(
      "n2_generic_cell_adjacency_sensitivity",
    );
    expect(url.searchParams.has("abstract_iteration")).toBe(false);
  });
});
