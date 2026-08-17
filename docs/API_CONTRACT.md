# SubTerrat API Contract v0.1

> Contract-first specification for the Flutter map and the frozen prediction pipeline.

## 1. 狀態與權威

- Contract version：`0.1.0`
- OpenAPI projection：`docs/openapi-v1.yaml`
- Implementation status：`SPECIFICATION_ONLY`
- Runtime evidence：`NO_TRUSTED_RESULT`

本文件描述預定的 FastAPI transport contract，不代表 endpoint、模型、資料管線或 GCP deployment 已存在。語意衝突時依序以 `docs/BELIEF.md`、`docs/HARNESS_ARCHITECTURE.md`、本文件、OpenAPI projection 為準。

## 2. 已確認的模型輸出

v0.1 模型是 T0 deterministic spatial ranking，不是 fitted daily time-series model：

```text
Food(cell)      = mean(rank_percentile(food features))
Sewer(cell)     = mean(rank_percentile(sewer features))
Abandoned(cell) = mean(rank_percentile(abandoned-building features))

MainScore(cell) = (Food(cell) + Sewer(cell) + Abandoned(cell)) / 3
Baseline(cell)  = Food(cell)
```

每次 prediction run 對每個 S2 Level 15 cell 產生：

| 類型 | 欄位 | 語意 |
| --- | --- | --- |
| 識別與時間 | `prediction_run_id`、`cell_id`、`issued_at`、`as_of`、`target_window` | 說明何時產生、最多看見何時資料，以及要評估的未來觀測窗 |
| 主分數 | `structural_score`、`rank_percentile`、`main_rank` | 結構性民眾見鼠通報熱點排序，不是鼠類存在機率 |
| 組成 | `food_score`、`sewer_score`、`abandoned_score` | 三組通過 data gate 的 component scores |
| 比較 | `food_only_rank`、三個固定 ablation ranks | 不重新擬合的 baseline／ablation |
| Top-K | `top_05`、`top_10`、`top_20` | 依 eligible area 預先登錄的排名區間 |
| 品質 | `coverage_state`、`freshness`、`limitation_codes` | 缺資料不自動解讀成低分 |
| 版本 | `feature_snapshot_id`、`model_version`、`model_digest`、`freeze_id` | 可重算與 audit chain |

固定限制：

- `calibrated_probability` 永遠為 `null`。
- 不輸出 `rat_presence`、`abundance`、疾病風險或投藥建議。
- T1 `Approved Rat` 通報是 evaluation outcome，不回寫成同一 T0 run 的 feature。
- Forecast history 是多次 `issued_at` 的 prediction vintages，不是虛構的每日分數。

## 3. Capability matrix

| Capability | v0.1 contract | 備註 |
| --- | --- | --- |
| Spatial ranking | `PLANNED` | 每個 frozen run／cell 一筆 |
| Forecast window | `PLANNED` | 必填 `as_of`、`target_window.start/end` |
| Forecast vintage history | `PLANNED` | 跨 run 查詢同一 cell |
| Food-only baseline | `PLANNED` | 固定 comparator |
| Three fixed ablations | `PLANNED` | Without Food／Sewer／Abandoned |
| Aggregated released outcome | `CONDITIONAL` | T1 關窗、finalization、人工核准後才可公開 |
| Daily model forecast | `NOT_SUPPORTED` | 現有特徵與規則沒有日尺度 dynamics |
| Scenario simulation | `NOT_SUPPORTED` | 尚無 scenario model；不得製造模擬曲線 |
| Calibrated probability | `NOT_SUPPORTED` | 缺臺北 E2／E3 正負標籤與 calibration |
| Live per-coordinate inference | `NOT_SUPPORTED` | 只讀 frozen S2 serving layer |

`GET /api/v1/model-capabilities` 必須把上述狀態回傳給 Flutter；未實作能力不得由 UI 自行推測。

## 4. 時間資料契約

正確 grain 是：

```text
(prediction_run_id, cell_id, target_start, target_end)
```

必要時間欄位：

- `issued_at`：結果真正產生時間。
- `as_of`：本次模型允許看到的最新 Evidence 時間；必須小於或等於 `issued_at`。
- `target_window.start`：未來觀測窗起點；official T0 必須大於 `as_of`。
- `target_window.end`：未來觀測窗終點。
- `t0_cutoff`：freeze protocol 鎖定的 T0 cutoff。

目前不得把一筆 window score 展開成每日重複值。若未來有可信 time-varying features 與 transition rule，需另立 API major/minor revision、Model card、scenario schema 與 validation plan，才能開 simulation series。

## 5. Public read API

所有 public endpoint 只能讀取經人工核准的 sanitized release；public service identity 不得讀 `t1_vault`、raw reports 或精確地下設施。

| Method | Path | 用途 |
| --- | --- | --- |
| `GET` | `/api/v1/model-capabilities` | 回傳模型實際支援與不支援的輸出能力 |
| `GET` | `/api/v1/map/bootstrap` | Flutter 啟動資料：目前 release、臺北 bounds、layers、legend、claim boundary |
| `GET` | `/api/v1/releases/current` | 指向目前獲准公開的 immutable release |
| `GET` | `/api/v1/releases/{release_id}` | 版本、freeze、target window、digest、來源日期與限制 |
| `GET` | `/api/v1/releases/{release_id}/cells` | 依 `bbox` 取得 GeoJSON S2 cells；一次最多 1,500 features |
| `GET` | `/api/v1/releases/{release_id}/cells/{cell_id}` | Flutter 點擊 cell 時取得詳細 component、coverage 與限制 |
| `GET` | `/api/v1/cells/{cell_id}/forecast-history` | 取得同一 cell 的 prediction vintages；不是 daily forecast |
| `GET` | `/api/v1/releases/{release_id}/stats` | 已公開的行政區／全市聚合摘要 |
| `GET` | `/healthz` | 程序存活；不證明資料或模型有效 |
| `GET` | `/readyz` | 可讀目前 public release；不證明預測有效 |

### 5.1 Cell query

```http
GET /api/v1/releases/{release_id}/cells
    ?bbox=121.48,25.01,121.58,25.10
    &layers=structural_score,data_coverage
    &limit=1500
```

- `bbox` 必填，格式固定為 `west,south,east,north`，座標系統為 WGS84。
- GeoJSON coordinate order 固定為 longitude、latitude。
- `cell_id` 一律是 string，避免 S2 64-bit ID 精度損失。
- Response 必須帶 `release_id`、`prediction_run_id`、`target_window` 與 `next_page_token`。
- `approved_report_count` layer 只有在 T1 已公開且通過 suppression policy 時可用。

### 5.2 Forecast history

```http
GET /api/v1/cells/{cell_id}/forecast-history?from=2026-09-01T00:00:00Z
```

Response 的 `series_kind` 固定為 `forecast_vintages`，`daily_time_series=false`。每個 entry 必須保留自己的 `prediction_run_id`、`issued_at`、`as_of`、target window、model version 與 score。

## 6. Internal command API

Internal endpoint 必須使用 Cloud Run IAM／OIDC，且與 public service 分離。

| Method | Path | 用途 |
| --- | --- | --- |
| `POST` | `/internal/v1/prediction-runs` | 建立 authorized batch prediction run，回傳 `202 Accepted` |
| `GET` | `/internal/v1/prediction-runs/{prediction_run_id}` | 查詢 queued／running／completed／failed／frozen 狀態 |

建立 run 時只允許：

```json
{
  "run_kind": "official_t0",
  "feature_snapshot_id": "feature-snapshot:...",
  "model_version": "deterministic-prior-v1",
  "as_of": "2026-08-31T23:59:59Z",
  "target_window": {
    "start": "2026-09-02T00:00:00Z",
    "end": "2026-10-27T23:59:59Z"
  },
  "idempotency_key": "..."
}
```

- Official run 不接受自訂權重、任意 feature 或 T1 outcome override。
- FastAPI 只驗證、建立 run 並啟動 batch job；不得在 map request 中重新計分。
- 同一 `idempotency_key` 與相同 request digest 必須回傳同一 run。
- Freeze 與 publish 是另外的人工核准 milestone；prediction completion 不等於 release。

## 7. 明確不開放的接口

v0.1 不得定義或實作：

```text
GET  /predict?lat=...&lng=...
GET  /rat-probability
GET  /raw-reports
GET  /sewer-network
POST /simulation-runs
POST /retrain
POST /dispatch
POST /bait-recommendations
```

Simulation endpoint 延後的原因不是 FastAPI 做不到，而是目前沒有被定義、可重算及可驗證的動態 scenario model。

## 8. Storage mapping

| API resource | BigQuery／artifact source | 邊界 |
| --- | --- | --- |
| Prediction run | `predictions.prediction_runs` | append-only metadata；partition by `DATE(issued_at)` |
| Cell window score | `predictions.cell_window_scores` | key=`run + cell + target window`；cluster by cell／model version |
| Release | `predictions.freeze_manifest`＋public release manifest | freeze 不自動等於 published release |
| Forecast history | `cell_window_scores` across published runs | 不補每日值 |
| Outcome status history | `t1_vault.report_status_events` | restricted；public API 無權讀 |
| Released outcome aggregate | human-approved sanitized serving table | 小樣本依 disclosure policy suppression |

現有 `predictions.cell_scores_t0` 可作第一個實作名稱；一旦支援多個 target windows，canonical grain 應升級為 `cell_window_scores`，不得只以 `v1` 或覆寫舊列表示版本。

## 9. Caching、pagination 與 errors

- Immutable release resources：`Cache-Control: public, max-age=31536000, immutable`。
- `/releases/current` 與 `/map/bootstrap`：短 TTL，不能使用 immutable cache。
- Release／cell response 的 `ETag` 應綁定 frozen map digest。
- 超過 `limit` 時使用 opaque `next_page_token`，不得靜默截斷。
- Error response 採 `application/problem+json`，至少包含 `type`、`title`、`status`、`code`、`detail`、`request_id`。

必要 error codes：

```text
NO_PUBLISHED_RELEASE
RELEASE_NOT_FOUND
CELL_NOT_FOUND
PREDICTION_RUN_NOT_FOUND
INVALID_BBOX
INVALID_TIME_WINDOW
CAPABILITY_NOT_AVAILABLE
DATA_GATE_FAILED
STATE_CONFLICT
IDEMPOTENCY_CONFLICT
FORBIDDEN_DATA_SCOPE
```

## 10. Proof boundary

- OpenAPI parse／lint 只證明 static contract 結構。
- Schema tests 只證明指定 payload 符合欄位與型別要求。
- FastAPI endpoint tests 才能證明 local runtime behavior。
- GCP smoke tests 才能證明指定 Cloud Run／BigQuery environment behavior。
- Prospective evaluation 與 human review 才能支持指定 T1 window 的 report-hotspot 結果。
- 在 repository-owned Sensors 與相應 receipts 建立前，一律維持 `NO_TRUSTED_RESULT`。
