import { useEffect, useMemo, useState } from "react";

import { fetchAllLabCells, fetchPreviewLabCells } from "./api";
import { formatScore } from "./color";
import { HotspotMap } from "./HotspotMap";
import { NetworkLab } from "./NetworkLab";
import type { MapDisplayMode } from "./HotspotMap";
import { DEFAULT_LAYER, LAYERS } from "./layers";
import type { LabCellFeature, ScoreKey } from "./types";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL?.trim() || "http://127.0.0.1:8080";
const PREVIEW_DATA_URL = import.meta.env.VITE_PREVIEW_DATA_URL?.trim() || "";

export default function App() {
  const [researchView, setResearchView] = useState<"comparison" | "network">(
    "comparison",
  );
  const [features, setFeatures] = useState<LabCellFeature[]>([]);
  const [layer, setLayer] = useState<ScoreKey>(DEFAULT_LAYER);
  const [displayMode, setDisplayMode] = useState<MapDisplayMode>("heat");
  const [selectedCellId, setSelectedCellId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    const request = PREVIEW_DATA_URL
      ? fetchPreviewLabCells(PREVIEW_DATA_URL, controller.signal)
      : fetchAllLabCells(API_BASE_URL, controller.signal);
    request
      .then((cells) => {
        setFeatures(cells);
        const initialCell =
          cells.reduce<LabCellFeature | undefined>((highest, cell) => {
            const score = cell.properties.scores[DEFAULT_LAYER];
            if (score === null) return highest;
            const highestScore =
              highest?.properties.scores[DEFAULT_LAYER] ?? null;
            return highestScore === null || score > highestScore
              ? cell
              : highest;
          }, undefined) ?? cells[0];
        setSelectedCellId(initialCell?.id ?? null);
        setError(null);
      })
      .catch((reason: unknown) => {
        if (reason instanceof DOMException && reason.name === "AbortError") return;
        setError(
          reason instanceof Error
            ? reason.message
            : "無法載入 internal-simulation data",
        );
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, []);

  const selectedLayer = LAYERS.find((item) => item.key === layer) ?? LAYERS[0];
  const selectedCell =
    features.find((feature) => feature.id === selectedCellId) ?? null;
  const scoredCount = useMemo(
    () => features.filter((feature) => feature.properties.scores[layer] !== null).length,
    [features, layer],
  );
  const totalCellCount = features[0]?.properties.total_cell_count ?? features.length;
  const coverage = totalCellCount ? scoredCount / totalCellCount : 0;
  const scoreableCityAreaShare =
    features[0]?.properties.scoreable_city_area_share ?? null;
  const previewSourceJobId = features[0]?.properties.preview_source_job_id ?? null;
  const specificationLabel =
    features[0]?.properties.specification_state === "LOCKED"
      ? "Specification locked"
      : "Specification pending lock";

  if (researchView === "network") {
    return <NetworkLab onBack={() => setResearchView("comparison")} />;
  }

  return (
    <main className="app-shell">
      <header className="page-header">
        <div>
          <p className="eyebrow">SubTerrat · Research interface</p>
          <h1>Spatial Comparison Lab</h1>
          <p className="lede">
            比較餐飲、sewer attributes 與核定重建行政資料 proxy。
          </p>
          <button
            type="button"
            className="challenger-button"
            onClick={() => setResearchView("network")}
          >
            開啟 Network redistribution challenger
          </button>
        </div>
        <div className="status-stack" aria-label="研究狀態">
          <span className="status-chip">{specificationLabel}</span>
          {previewSourceJobId && (
            <span className="status-chip">Read-only BigQuery preview</span>
          )}
          <span className="status-chip">Internal simulation only</span>
          <span className="status-chip status-chip--muted">Evidence untrusted</span>
          <span className="status-chip status-chip--muted">
            Operational use prohibited
          </span>
        </div>
      </header>

      <section className="warning" aria-label="限制說明">
        <strong>Ordinal simulation index—not probability.</strong>
        <span>
          Evidence untrusted（NO_TRUSTED_RESULT）；不支援派工、投藥、風險宣告或 component attribution。
        </span>
        {previewSourceJobId && <small>Source job：{previewSourceJobId}</small>}
      </section>

      <div className="workspace">
        <aside className="control-panel">
          <section>
            <p className="section-label">顯示圖層</p>
            <label className="select-label" htmlFor="layer-select">
              Score / diagnostic
            </label>
            <select
              id="layer-select"
              value={layer}
              onChange={(event) => setLayer(event.target.value as ScoreKey)}
            >
              {LAYERS.map((item) => (
                <option key={item.key} value={item.key}>
                  {item.shortLabel}
                </option>
              ))}
            </select>
            <label className="select-label map-mode-label" htmlFor="map-mode-select">
              Map rendering
            </label>
            <select
              id="map-mode-select"
              value={displayMode}
              onChange={(event) =>
                setDisplayMode(event.target.value as MapDisplayMode)
              }
            >
              <option value="heat">Metric heat surface（預設）</option>
              <option value="cells">Cell audit grid</option>
            </select>
            <h2>{selectedLayer.label}</h2>
            <p className="caveat">{selectedLayer.caveat}</p>
            {displayMode === "heat" && (
              <p className="caveat render-boundary">
                34 px kernel 僅作 visual smoothing；不是生物擴散、時間推演或新 model output。
              </p>
            )}
          </section>

          <section className="summary-grid" aria-label="圖層摘要">
            <div>
              <span>Cells</span>
              <strong>{totalCellCount.toLocaleString()}</strong>
            </div>
            <div>
              <span>Scored</span>
              <strong>{scoredCount.toLocaleString()}</strong>
            </div>
            <div>
              <span>Cell coverage</span>
              <strong>{(coverage * 100).toFixed(1)}%</strong>
            </div>
            {scoreableCityAreaShare !== null && (
              <div>
                <span>Scored area</span>
                <strong>{(scoreableCityAreaShare * 100).toFixed(1)}%</strong>
              </div>
            )}
          </section>

          <section>
            <p className="section-label">色階</p>
            <div className="legend-bar" aria-hidden="true" />
            <div className="legend-labels">
              <span>0 · 較低</span>
              <span>1 · 較高</span>
            </div>
            {displayMode === "cells" && (
              <div className="legend-key">
                <span className="missing-swatch" />
                <span>斜線：缺值／未通過 coverage</span>
              </div>
            )}
            <div className="legend-key">
              <span className="top-swatch" />
              <span>橘框：預註冊 selected scenario area</span>
            </div>
          </section>

          <section className="weight-card">
            <p className="section-label">預註冊權重（唯讀）</p>
            <div><span>餐飲／市場</span><strong>1/3</strong></div>
            <div><span>Sewer attribute index</span><strong>1/3</strong></div>
            <div><span>都更行政 site proxy 150 m</span><strong>1/3</strong></div>
          </section>
        </aside>

        <section className="map-panel" aria-live="polite">
          {loading && <div className="state-card">正在載入 BigQuery internal-simulation cells…</div>}
          {error && (
            <div className="state-card state-card--error">
              <strong>無法載入研究圖層</strong>
              <span>{error}</span>
              <small>
                {PREVIEW_DATA_URL
                  ? "請確認 VITE_PREVIEW_DATA_URL 指向有效的 read-only preview fixture。"
                  : "請確認 API 已設定 LAB_V03_ENABLED=true，並允許 http://127.0.0.1:5173。"}
              </small>
            </div>
          )}
          {!loading && !error && features.length === 0 && (
            <div className="state-card">API 沒有回傳可顯示的 cells。</div>
          )}
          {!loading && !error && features.length > 0 && (
            <HotspotMap
              features={features}
              layer={layer}
              displayMode={displayMode}
              selectedCellId={selectedCellId}
              onSelectCell={(feature) => setSelectedCellId(feature.id)}
            />
          )}
        </section>

        <aside className="detail-panel">
          <p className="section-label">Cell inspection</p>
          {selectedCell ? (
            <>
              <h2>{selectedCell.id}</h2>
              <dl>
                <div>
                  <dt>目前圖層</dt>
                  <dd>{formatScore(selectedCell.properties.scores[layer])}</dd>
                </div>
                <div>
                  <dt>Rank within scoreable support</dt>
                  <dd>
                    {formatScore(
                      selectedCell.properties.rank_within_scoreable_support,
                    )}
                  </dd>
                </div>
                <div>
                  <dt>Preregistered selected scenario area</dt>
                  <dd>
                    {selectedCell.properties.preregistered_selected_scenario_area
                      ? "是"
                      : "否"}
                  </dd>
                </div>
                <div>
                  <dt>Evidence</dt>
                  <dd>{selectedCell.properties.evidence_state}</dd>
                </div>
              </dl>
              <p className="section-label detail-label">三組 components</p>
              <dl>
                <div>
                  <dt>餐飲</dt>
                  <dd>{formatScore(selectedCell.properties.scores.food_market_v0_1)}</dd>
                </div>
                <div>
                  <dt>下水道加強版</dt>
                  <dd>
                    {formatScore(
                      selectedCell.properties.scores.sewer_attribute_index_v0_2,
                    )}
                  </dd>
                </div>
                <div>
                  <dt>都更行政 site proxy 150 m</dt>
                  <dd>
                    {formatScore(
                      selectedCell.properties.scores
                        .approved_rebuilding_admin_site_buffer_150m,
                    )}
                  </dd>
                </div>
              </dl>
              <ul className="limitations">
                {selectedCell.properties.limitation_codes.map((code) => (
                  <li key={code}>{code}</li>
                ))}
              </ul>
            </>
          ) : (
            <p className="muted">選擇一個 cell 查看 components 與限制。</p>
          )}
        </aside>
      </div>
    </main>
  );
}
