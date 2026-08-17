import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { LabCellFeature } from "./types";

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
  const heatLayerInstance = { addTo: vi.fn(), removeFrom: vi.fn() };
  tileLayerInstance.addTo.mockReturnValue(tileLayerInstance);
  geoJsonLayerInstance.addTo.mockReturnValue(geoJsonLayerInstance);
  heatLayerInstance.addTo.mockReturnValue(heatLayerInstance);
  return {
    mapInstance,
    tileLayerInstance,
    geoJsonLayerInstance,
    heatLayerInstance,
    api: {
      latLngBounds: vi.fn(() => ({ kind: "bounds" })),
      map: vi.fn(() => mapInstance),
      tileLayer: vi.fn((_url: string, _options: unknown) => tileLayerInstance),
      canvas: vi.fn(() => ({ kind: "canvas" })),
      geoJSON: vi.fn((_data: unknown, _options: any) => geoJsonLayerInstance),
      heatLayer: vi.fn((_points: unknown, _options: unknown) => heatLayerInstance),
    },
  };
});

vi.mock("leaflet", () => ({ default: leafletMock.api }));
vi.mock("leaflet.heat", () => ({}));

import { HotspotMap } from "./HotspotMap";


const feature = {
  type: "Feature",
  id: "1",
  geometry: {
    type: "Polygon",
    coordinates: [
      [
        [121.5, 25],
        [121.51, 25],
        [121.51, 25.01],
        [121.5, 25.01],
        [121.5, 25],
      ],
    ],
  },
  properties: {
    cell_id: "1",
    centroid_longitude: 121.505,
    centroid_latitude: 25.005,
    scenario_id: "v0_3_equal_group_internal_simulation_r150",
    release_state: "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY",
    score_semantics: "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY",
    specification_state: "LOCKED",
    use_state: "INTERNAL_SIMULATION_ONLY",
    evidence_state: "NO_TRUSTED_RESULT",
    operational_use: "PROHIBITED",
    calibrated_probability: null,
    scenario_state: "BLOCKED_INTERNAL_SIMULATION",
    rank_within_scoreable_support: 0.8,
    preregistered_selected_scenario_area: true,
    scores: {
      food_market_v0_1: 0.7,
      sewer_system_type_v0_1: 0.1,
      sewer_system_type_v0_2: 0.1,
      surface_elevation_v0_2: 0.5,
      connected_pipe_diameter_v0_2: 0.6,
      connected_pipe_depth_v0_2: 0.7,
      connected_pipe_age_v0_2: 0.8,
      sewer_attribute_index_v0_2: 0.54,
      approved_rebuilding_admin_site_buffer_0m: 0.2,
      approved_rebuilding_admin_site_buffer_150m: 0.4,
      approved_rebuilding_admin_site_buffer_300m: 0.5,
      v0_3_equal_group_internal_simulation_r150: 0.55,
    },
    limitation_codes: ["NO_TRUSTED_RESULT"],
  },
} satisfies LabCellFeature;

describe("HotspotMap", () => {
  it("adds an attributed OSM basemap and interactive aggregate cells", () => {
    const onSelectCell = vi.fn();
    render(
      <HotspotMap
        features={[feature]}
        layer="v0_3_equal_group_internal_simulation_r150"
        displayMode="heat"
        selectedCellId={feature.id}
        onSelectCell={onSelectCell}
      />,
    );

    expect(
      screen.getByRole("region", {
        name: "臺北市 OpenStreetMap 底圖與 metric 空間比較圖",
      }),
    ).toBeVisible();
    expect(leafletMock.api.tileLayer).toHaveBeenCalledWith(
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
      expect.objectContaining({
        attribution: expect.stringContaining("OpenStreetMap contributors"),
        updateWhenIdle: true,
      }),
    );
    expect(leafletMock.api.heatLayer).toHaveBeenCalledWith(
      [[25.005, 121.505, 0.55]],
      expect.objectContaining({ radius: 34, blur: 28, max: 1, maxZoom: 11 }),
    );

    const geoJsonOptions = leafletMock.api.geoJSON.mock.calls[0][1];
    expect(geoJsonOptions.style(feature)).toEqual(
      expect.objectContaining({ color: "#101820", fillOpacity: 0 }),
    );

    const eventHandlers: Record<string, () => void> = {};
    const leafletLayer = {
      bindTooltip: vi.fn(),
      on: vi.fn((event: string, handler: () => void) => {
        eventHandlers[event] = handler;
      }),
    };
    geoJsonOptions.onEachFeature(feature, leafletLayer);
    eventHandlers.click();
    expect(onSelectCell).toHaveBeenCalledWith(feature);
  });
});
