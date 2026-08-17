import { useEffect, useMemo, useState } from "react";

import { fetchNetworkCells, fetchNetworkLinks } from "./api";
import { NetworkMap } from "./NetworkMap";
import type {
  NetworkCell,
  NetworkCellsResponse,
  NetworkLink,
  NetworkScenarioId,
} from "./types";


const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL?.trim() || "http://127.0.0.1:8080";

type Props = {
  onBack(): void;
};

const SCENARIOS: { value: NetworkScenarioId; label: string }[] = [
  {
    value: "n0_uniform_sewer_link_comparator",
    label: "N0 · uniform sewer-link comparator",
  },
  {
    value: "n1_metric_weighted_sewer_links",
    label: "N1 · metric-weighted sewer links",
  },
  {
    value: "n2_generic_cell_adjacency_sensitivity",
    label: "N2 · generic adjacency sensitivity",
  },
];

export function NetworkLab({ onBack }: Props) {
  const [scenario, setScenario] = useState<NetworkScenarioId>(
    "n1_metric_weighted_sewer_links",
  );
  const [iteration, setIteration] = useState(0);
  const [payload, setPayload] = useState<NetworkCellsResponse | null>(null);
  const [links, setLinks] = useState<NetworkLink[]>([]);
  const [showLinks, setShowLinks] = useState(false);
  const [selectedCellId, setSelectedCellId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    fetchNetworkCells(API_BASE_URL, scenario, iteration, controller.signal)
      .then((response) => {
        setPayload(response);
        setSelectedCellId((current) => current ?? response.cells[0]?.cell_id ?? null);
        setError(null);
      })
      .catch((reason: unknown) => {
        if (reason instanceof DOMException && reason.name === "AbortError") return;
        setError(reason instanceof Error ? reason.message : "無法載入 network cells");
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [iteration, scenario]);

  useEffect(() => {
    if (!showLinks) {
      setLinks([]);
      return;
    }
    const controller = new AbortController();
    fetchNetworkLinks(API_BASE_URL, scenario, controller.signal)
      .then((response) => {
        setLinks(response.links);
        setError(null);
      })
      .catch((reason: unknown) => {
        if (reason instanceof DOMException && reason.name === "AbortError") return;
        setError(reason instanceof Error ? reason.message : "無法載入 schematic links");
      });
    return () => controller.abort();
  }, [scenario, showLinks]);

  const cells = payload?.cells ?? [];
  const selectedCell: NetworkCell | null =
    cells.find((cell) => cell.cell_id === selectedCellId) ?? null;
  const supportCounts = useMemo(() => {
    const counts = new Map<string, number>();
    cells.forEach((cell) =>
      counts.set(
        cell.cell_support_state,
        (counts.get(cell.cell_support_state) ?? 0) + 1,
      ),
    );
    return counts;
  }, [cells]);

  return (
    <main className="app-shell network-lab">
      <header className="page-header">
        <div>
          <button type="button" className="text-button" onClick={onBack}>
            ← 返回 spatial comparison
          </button>
          <p className="eyebrow">SubTerrat · Internal method challenger</p>
          <h1>Network redistribution challenger</h1>
          <p className="lede">
            Frozen food seed 在 coarse cell-link graph 上的 deterministic synthetic redistribution。
          </p>
        </div>
        <div className="status-stack" aria-label="研究狀態">
          <span className="status-chip">Internal synthetic redistribution</span>
          <span className="status-chip status-chip--muted">NO_TRUSTED_RESULT</span>
          <span className="status-chip status-chip--muted">Operational use prohibited</span>
        </div>
      </header>

      <section className="warning network-warning" aria-label="限制說明">
        <strong>Not a calibrated rat-presence probability.</strong>
        <span>
          Abstract iteration—no time mapping；not a sewer-flow or movement map；不是 forecast、risk 或行動建議。
        </span>
      </section>

      <div className="workspace">
        <aside className="control-panel">
          <section>
            <label className="select-label" htmlFor="network-scenario">
              Locked scenario
            </label>
            <select
              id="network-scenario"
              value={scenario}
              onChange={(event) => setScenario(event.target.value as NetworkScenarioId)}
            >
              {SCENARIOS.map((item) => (
                <option key={item.value} value={item.value}>{item.label}</option>
              ))}
            </select>
          </section>

          <section>
            <label className="select-label" htmlFor="abstract-iteration">
              Abstract iteration: {iteration}
            </label>
            <input
              id="abstract-iteration"
              type="range"
              min="0"
              max="8"
              step="1"
              value={iteration}
              onChange={(event) => setIteration(Number(event.target.value))}
            />
            <p className="caveat">Manual only；iteration 8 不是 final 或 convergence。</p>
          </section>

          <section>
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={showLinks}
                onChange={(event) => setShowLinks(event.target.checked)}
              />
              顯示 schematic aggregated cell links（預設關閉）
            </label>
            <p className="caveat">Centroid-to-centroid only—not pipe alignment.</p>
          </section>

          <section>
            <p className="section-label">固定色階</p>
            <div className="network-legend" aria-hidden="true">
              {["#edf4fb", "#c7ddec", "#8fb5d5", "#4f89bb", "#205b91"].map(
                (color) => <span key={color} style={{ background: color }} />,
              )}
            </div>
            <div className="legend-labels"><span>0</span><span>1</span></div>
            <div className="legend-key">
              <span className="network-hatch-swatch" />
              <span>Hatch：support limitation；底色 state 不變</span>
            </div>
          </section>

          <section className="summary-grid" aria-label="support 摘要">
            <div><span>Cells</span><strong>{cells.length.toLocaleString()}</strong></div>
            <div>
              <span>Metric sewer</span>
              <strong>{(supportCounts.get("METRIC_SEWER_SUPPORTED") ?? 0).toLocaleString()}</strong>
            </div>
            <div><span>Visible links</span><strong>{links.length.toLocaleString()}</strong></div>
          </section>
        </aside>

        <section className="map-panel" aria-live="polite">
          {loading && <div className="state-card">載入 canonical network cells…</div>}
          {error && <div className="state-card state-card--error"><strong>無法載入 challenger</strong><span>{error}</span></div>}
          {!loading && !error && cells.length > 0 && (
            <NetworkMap
              cells={cells}
              links={links}
              showLinks={showLinks}
              selectedCellId={selectedCellId}
              onSelectCell={(cell) => setSelectedCellId(cell.cell_id)}
            />
          )}
        </section>

        <aside className="detail-panel">
          <p className="section-label">Cell inspection</p>
          {selectedCell ? (
            <>
              <h2>{selectedCell.cell_id}</h2>
              <dl>
                <div><dt>Relative synthetic state</dt><dd>{selectedCell.relative_synthetic_network_state}</dd></div>
                <div><dt>Support</dt><dd>{selectedCell.cell_support_state}</dd></div>
                <div><dt>Sewer neighbors</dt><dd>{selectedCell.eligible_sewer_neighbor_count}</dd></div>
                <div><dt>Generic neighbors</dt><dd>{selectedCell.eligible_generic_neighbor_count}</dd></div>
                <div><dt>Self-only row</dt><dd>{selectedCell.self_only_transition_row ? "是" : "否"}</dd></div>
              </dl>
              <ul className="limitations">
                {selectedCell.cell_limitation_codes.map((code) => <li key={code}>{code}</li>)}
              </ul>
            </>
          ) : <p className="muted">選擇一個 cell 查看 support。</p>}
        </aside>
      </div>
    </main>
  );
}
