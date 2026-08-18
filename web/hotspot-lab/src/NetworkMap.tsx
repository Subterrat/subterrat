import { useEffect, useRef } from "react";
import type { Feature, FeatureCollection, Geometry } from "geojson";
import L from "leaflet";

import type { NetworkCell, NetworkLink } from "./types";


type Props = {
  cells: NetworkCell[];
  links: NetworkLink[];
  showLinks: boolean;
  selectedCellId: string | null;
  onSelectCell(cell: NetworkCell): void;
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

export function networkStateColor(value: number): string {
  if (value <= 0.2) return "#edf4fb";
  if (value <= 0.4) return "#c7ddec";
  if (value <= 0.6) return "#8fb5d5";
  if (value <= 0.8) return "#4f89bb";
  return "#205b91";
}

function toFeature(cell: NetworkCell): Feature<Geometry> {
  return {
    type: "Feature",
    id: cell.cell_id,
    geometry: JSON.parse(cell.eligible_geojson) as Geometry,
    properties: {},
  };
}

export function NetworkMap({
  cells,
  links,
  showLinks,
  selectedCellId,
  onSelectCell,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const baseCellsRef = useRef<L.GeoJSON | null>(null);
  const hatchCellsRef = useRef<L.GeoJSON | null>(null);
  const linkLayerRef = useRef<L.LayerGroup | null>(null);
  const fittedRef = useRef(false);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = L.map(containerRef.current, {
      attributionControl: true,
      preferCanvas: false,
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
        : new ResizeObserver(() => map.invalidateSize({ pan: false }));
    resizeObserver?.observe(containerRef.current);
    return () => {
      resizeObserver?.disconnect();
      baseCellsRef.current = null;
      hatchCellsRef.current = null;
      linkLayerRef.current = null;
      mapRef.current = null;
      map.remove();
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    baseCellsRef.current?.removeFrom(map);
    hatchCellsRef.current?.removeFrom(map);
    linkLayerRef.current?.removeFrom(map);
    if (!cells.length) return;

    const cellsById = new Map(cells.map((cell) => [cell.cell_id, cell]));
    const collection: FeatureCollection = {
      type: "FeatureCollection",
      features: cells.map(toFeature),
    };
    const baseCells = L.geoJSON(collection, {
      style: (feature) => {
        const cell = cellsById.get(String(feature?.id));
        if (!cell) return { opacity: 0, fillOpacity: 0 };
        const selected = cell.cell_id === selectedCellId;
        return {
          color: selected ? "#111820" : "#ffffff",
          weight: selected ? 3 : 0.8,
          opacity: 1,
          fillColor: networkStateColor(
            Number(cell.relative_synthetic_network_state),
          ),
          fillOpacity: 0.64,
        };
      },
      onEachFeature: (feature, layer) => {
        const cell = cellsById.get(String(feature.id));
        if (!cell) return;
        layer.bindTooltip(
          `Cell ${cell.cell_id} · abstract state ${cell.relative_synthetic_network_state}`,
          { sticky: true },
        );
        layer.on("click", () => onSelectCell(cell));
      },
    }).addTo(map);
    baseCellsRef.current = baseCells;

    const unsupported: FeatureCollection = {
      type: "FeatureCollection",
      features: cells
        .filter((cell) => cell.cell_support_state !== "METRIC_SEWER_SUPPORTED")
        .map(toFeature),
    };
    hatchCellsRef.current = L.geoJSON(unsupported, {
      interactive: false,
      style: {
        className: "network-support-hatch",
        color: "transparent",
        weight: 0,
        fill: true,
        fillColor: "transparent",
        fillOpacity: 0.52,
      },
    }).addTo(map);

    const linkGroup = L.layerGroup();
    if (showLinks) {
      links.forEach((link) => {
        const from = link.schematic_from_centroid;
        const to = link.schematic_to_centroid;
        L.polyline(
          [
            [Number(from.latitude), Number(from.longitude)],
            [Number(to.latitude), Number(to.longitude)],
          ],
          {
            color:
              link.link_class === "SYNTHETIC_SEWER_LINK"
                ? "#284c70"
                : "#9b6a24",
            weight: 1.2,
            opacity: 0.55,
            dashArray:
              link.link_class === "GENERIC_CELL_ADJACENCY" ? "5 4" : undefined,
          },
        )
          .bindTooltip("Schematic aggregated cell link—not pipe alignment")
          .addTo(linkGroup);
      });
    }
    linkGroup.addTo(map);
    linkLayerRef.current = linkGroup;

    if (!fittedRef.current && baseCells.getBounds().isValid()) {
      map.fitBounds(baseCells.getBounds(), { maxZoom: 14, padding: [18, 18] });
      fittedRef.current = true;
    }
  }, [cells, links, onSelectCell, selectedCellId, showLinks]);

  return (
    <>
      <svg className="network-hatch-defs" aria-hidden="true">
        <defs>
          <pattern
            id="network-support-hatch"
            width="8"
            height="8"
            patternUnits="userSpaceOnUse"
            patternTransform="rotate(45)"
          >
            <line x1="0" y1="0" x2="0" y2="8" stroke="#263849" strokeWidth="2" />
          </pattern>
        </defs>
      </svg>
      <div
        ref={containerRef}
        className="hotspot-map"
        role="region"
        aria-label="臺北市 OpenStreetMap 底圖與 internal synthetic network redistribution discrete cell choropleth"
      />
    </>
  );
}
