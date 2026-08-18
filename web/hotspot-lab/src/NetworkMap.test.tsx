import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { NetworkCell, NetworkLink } from "./types";

const leafletMock = vi.hoisted(() => {
  const mapInstance = {
    fitBounds: vi.fn(),
    invalidateSize: vi.fn(),
    remove: vi.fn(),
  };
  const tileLayerInstance = { addTo: vi.fn() };
  const geoJsonLayerInstance = {
    addTo: vi.fn(),
    removeFrom: vi.fn(),
    getBounds: vi.fn(() => ({ isValid: () => true })),
  };
  const linkGroup = { addTo: vi.fn(), removeFrom: vi.fn() };
  const polyline = {
    bindTooltip: vi.fn(),
    addTo: vi.fn(),
  };
  tileLayerInstance.addTo.mockReturnValue(tileLayerInstance);
  geoJsonLayerInstance.addTo.mockReturnValue(geoJsonLayerInstance);
  linkGroup.addTo.mockReturnValue(linkGroup);
  polyline.bindTooltip.mockReturnValue(polyline);
  polyline.addTo.mockReturnValue(polyline);
  return {
    geoJsonLayerInstance,
    linkGroup,
    polyline,
    api: {
      latLngBounds: vi.fn(() => ({ kind: "bounds" })),
      map: vi.fn(() => mapInstance),
      tileLayer: vi.fn(() => tileLayerInstance),
      geoJSON: vi.fn((_data: unknown, _options: any) => geoJsonLayerInstance),
      layerGroup: vi.fn(() => linkGroup),
      polyline: vi.fn((_points: unknown, _options: unknown) => polyline),
    },
  };
});

vi.mock("leaflet", () => ({ default: leafletMock.api }));

import { NetworkMap, networkStateColor } from "./NetworkMap";


const cell: NetworkCell = {
  cell_id: "1",
  eligible_geojson:
    '{"type":"Polygon","coordinates":[[[121.5,25],[121.51,25],[121.51,25.01],[121.5,25.01],[121.5,25]]]}',
  relative_synthetic_network_state: "0.600000000000",
  sewer_attribute_available: false,
  eligible_sewer_neighbor_count: 0,
  eligible_generic_neighbor_count: 3,
  self_only_transition_row: false,
  cell_support_state: "GENERIC_ADJACENCY_ONLY",
  cell_limitation_codes: [
    "CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY",
    "GENERIC_ADJACENCY_ONLY_SUPPORT",
  ],
};

const link: NetworkLink = {
  from_cell_id: "1",
  to_cell_id: "2",
  link_class: "GENERIC_CELL_ADJACENCY",
  active_in_scenario: true,
  metric_eligible: null,
  schematic_from_centroid: { longitude: "121.5000000", latitude: "25.0000000" },
  schematic_to_centroid: { longitude: "121.5100000", latitude: "25.0100000" },
  link_limitation_codes: [
    "GENERIC_ADJACENCY_BARRIERS_NOT_MODELED",
    "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
  ],
};

describe("NetworkMap", () => {
  it("uses a discrete cell fill plus a separate support hatch overlay", () => {
    render(
      <NetworkMap
        cells={[cell]}
        links={[]}
        showLinks={false}
        selectedCellId={cell.cell_id}
        onSelectCell={vi.fn()}
      />,
    );
    expect(
      screen.getByRole("region", {
        name: /internal synthetic network redistribution discrete cell choropleth/,
      }),
    ).toBeVisible();
    expect(leafletMock.api.geoJSON).toHaveBeenCalledTimes(2);
    const baseOptions = leafletMock.api.geoJSON.mock.calls[0][1];
    expect(baseOptions.style({ id: "1" })).toEqual(
      expect.objectContaining({
        fillColor: networkStateColor(0.6),
        fillOpacity: 0.64,
      }),
    );
    const hatchOptions = leafletMock.api.geoJSON.mock.calls[1][1];
    expect(hatchOptions.style).toEqual(
      expect.objectContaining({ className: "network-support-hatch" }),
    );
    expect(leafletMock.api.polyline).not.toHaveBeenCalled();
  });

  it("keeps schematic links opt-in and labels them as not pipe alignment", () => {
    render(
      <NetworkMap
        cells={[cell]}
        links={[link]}
        showLinks
        selectedCellId={null}
        onSelectCell={vi.fn()}
      />,
    );
    expect(leafletMock.api.polyline).toHaveBeenCalledWith(
      [[25, 121.5], [25.01, 121.51]],
      expect.objectContaining({ dashArray: "5 4" }),
    );
    expect(leafletMock.polyline.bindTooltip).toHaveBeenCalledWith(
      "Schematic aggregated cell link—not pipe alignment",
    );
  });
});
