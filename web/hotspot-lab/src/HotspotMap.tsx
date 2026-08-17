import { useEffect, useRef } from "react";
import type {
  Feature as GeoJsonFeature,
  FeatureCollection,
  GeoJsonProperties,
  Geometry,
} from "geojson";
import L from "leaflet";
import "leaflet.heat";
import "leaflet/dist/leaflet.css";

import { scoreColor } from "./color";
import type { LabCellFeature, ScoreKey } from "./types";

export type MapDisplayMode = "heat" | "cells";

type Props = {
  features: LabCellFeature[];
  layer: ScoreKey;
  displayMode: MapDisplayMode;
  selectedCellId: string | null;
  onSelectCell(cell: LabCellFeature): void;
};

const BASEMAP_TILE_URL =
  import.meta.env.VITE_BASEMAP_TILE_URL?.trim() ||
  "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const BASEMAP_ATTRIBUTION =
  import.meta.env.VITE_BASEMAP_ATTRIBUTION?.trim() ||
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>';
const TAIPEI_FALLBACK_BOUNDS = L.latLngBounds(
  [24.95, 121.45],
  [25.22, 121.67],
);

function leafletStyle(
  feature: LabCellFeature,
  layer: ScoreKey,
  selectedCellId: string | null,
  displayMode: MapDisplayMode,
): L.PathOptions {
  const score = feature.properties.scores[layer];
  const selected = feature.id === selectedCellId;
  const selectedArea =
    feature.properties.preregistered_selected_scenario_area;

  if (displayMode === "heat") {
    return {
      color: selected ? "#101820" : selectedArea ? "#d47a16" : "transparent",
      weight: selected ? 3 : selectedArea ? 2 : 0,
      opacity: selected || selectedArea ? 1 : 0,
      fill: true,
      fillOpacity: 0,
    };
  }

  return {
    color: selected ? "#101820" : selectedArea ? "#d47a16" : "#ffffff",
    weight: selected ? 3 : selectedArea ? 2 : 0.8,
    opacity: 1,
    fillColor: score === null ? "#eef1f4" : scoreColor(score),
    fillOpacity: score === null ? 0.38 : 0.56,
    dashArray: score === null ? "5 4" : undefined,
  };
}

export function HotspotMap({
  features,
  layer,
  displayMode,
  selectedCellId,
  onSelectCell,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const cellsLayerRef = useRef<L.GeoJSON | null>(null);
  const heatLayerRef = useRef<L.HeatLayer | null>(null);
  const fittedDataRef = useRef(false);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = L.map(containerRef.current, {
      attributionControl: true,
      zoomControl: true,
      minZoom: 10,
      maxZoom: 18,
    });
    L.tileLayer(BASEMAP_TILE_URL, {
      attribution: BASEMAP_ATTRIBUTION,
      maxZoom: 19,
      updateWhenIdle: true,
    }).addTo(map);
    map.fitBounds(TAIPEI_FALLBACK_BOUNDS, { padding: [8, 8] });
    mapRef.current = map;

    const resizeObserver =
      typeof ResizeObserver === "undefined"
        ? null
        : new ResizeObserver(() => {
            map.invalidateSize({ debounceMoveend: true, pan: false });
          });
    resizeObserver?.observe(containerRef.current);

    return () => {
      resizeObserver?.disconnect();
      cellsLayerRef.current = null;
      heatLayerRef.current = null;
      mapRef.current = null;
      map.remove();
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (cellsLayerRef.current) {
      cellsLayerRef.current.removeFrom(map);
      cellsLayerRef.current = null;
    }
    if (heatLayerRef.current) {
      heatLayerRef.current.removeFrom(map);
      heatLayerRef.current = null;
    }
    if (!features.length) return;

    if (displayMode === "heat") {
      const heatPoints = features.flatMap((feature) => {
        const score = feature.properties.scores[layer];
        return score !== null && score > 0
          ? [[
              feature.properties.centroid_latitude,
              feature.properties.centroid_longitude,
              score,
            ] as L.HeatLatLngTuple]
          : [];
      });
      heatLayerRef.current = L.heatLayer(heatPoints, {
        radius: 34,
        blur: 28,
        max: 1,
        minOpacity: 0.14,
        maxZoom: 11,
        gradient: {
          0.15: "#edf4fb",
          0.4: "#b7cde6",
          0.7: "#6d9bd1",
          1: "#235f9f",
        },
      }).addTo(map);
    }

    const featuresById = new Map(features.map((feature) => [feature.id, feature]));
    const featureCollection: FeatureCollection = {
      type: "FeatureCollection",
      features: features as unknown as GeoJsonFeature<
        Geometry,
        GeoJsonProperties
      >[],
    };
    const cellsLayer = L.geoJSON(featureCollection, {
      style: (geoFeature) => {
        const feature = featuresById.get(String(geoFeature?.id));
        return feature
          ? leafletStyle(feature, layer, selectedCellId, displayMode)
          : { fillOpacity: 0, opacity: 0 };
      },
      onEachFeature: (geoFeature, leafletLayer) => {
        const feature = featuresById.get(String(geoFeature.id));
        if (!feature) return;
        const score = feature.properties.scores[layer];
        leafletLayer.bindTooltip(
          `Cell ${feature.id} · ${score === null ? "無資料" : score.toFixed(3)}`,
          { sticky: true },
        );
        leafletLayer.on("click", () => onSelectCell(feature));
      },
    }).addTo(map);
    cellsLayerRef.current = cellsLayer;

    if (!fittedDataRef.current && cellsLayer.getBounds().isValid()) {
      map.fitBounds(cellsLayer.getBounds(), { maxZoom: 14, padding: [18, 18] });
      fittedDataRef.current = true;
    }
  }, [displayMode, features, layer, onSelectCell, selectedCellId]);

  return (
    <div
      ref={containerRef}
      className="hotspot-map"
      role="region"
      aria-label="臺北市 OpenStreetMap 底圖與 metric 空間比較圖"
    />
  );
}
