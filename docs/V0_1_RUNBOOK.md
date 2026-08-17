# SubTerrat v0.1 可執行流程

## 這一版會產生什麼

v0.1 會在 BigQuery 產生兩個不使用見鼠資料擬合的結構性熱點排序：

- `food_market_only`
- `sewer_system_type_only`

輸出是 `score`、`rank` 與 Top-area flag，不是鼠患機率。廢棄建築目前只有範圍有限的市有未利用建物地址點，因此只顯示 overlay，不進 citywide ranking。

## 前置條件

- Google Cloud project：`devjam26aug17tpe-1270`
- BigQuery location：`asia-east1`
- [`uv`](https://docs.astral.sh/uv/)（管理 Python 版本與依賴；`pyproject.toml` 宣告 `requires-python = ">=3.11"`，`.python-version` 釘選本機開發用 3.12）
- 已存在下列表格：
  - `subterrat_raw.taipei_s2_l15_grid_raw`
  - `subterrat_curated.food_site_candidate_geo`
  - `subterrat_curated.sewer_access_point_candidate_geo`
  - `subterrat_curated.unused_public_building_candidate`
  - `subterrat_curated.unused_public_building_address_point_candidate_geo`

這個 repository 目前包含網格生成、地址點 join、特徵／排名／freeze／地圖 payload SQL；公開資料的完整 fetch-to-load ingestion 尚未收斂成 repository-owned pipeline。

## 本機驗證

```bash
uv sync --group dev
PYTHONPATH=. uv run python -m unittest discover -s tests -v
```

`uv sync` 會依 `.python-version` 自動下載/使用 Python 3.12（不需要系統已裝該版本），並依 `uv.lock` 安裝所有 pinned 依賴到 `.venv`；不需要另外手動建立 venv 或跑 `pip install`。

## 建立臺北 S2 Level 15 網格

```bash
PYTHONPATH=. uv run python scripts/build_taipei_s2_grid.py \
  --output artifacts/taipei_s2_l15.ndjson \
  --manifest artifacts/taipei_s2_l15.manifest.json
```

將 NDJSON 以明確 schema 載入 `subterrat_raw.taipei_s2_l15_grid_raw` 後，依序執行：

```text
sql/structural/01_materialize_analysis_cells.sql
sql/structural/02_materialize_cell_features.sql
sql/structural/03_layerwise_score_candidates.sql
sql/structural/04_candidate_quality.sql
sql/structural/05_layerwise_score_quality.sql
```

`04` 與 `05` 是人工檢查輸出。確認 row count、coverage、snapshot 與 score semantics 後，才執行 freeze：

```bash
bq --project_id=devjam26aug17tpe-1270 --location=asia-east1 query \
  --use_legacy_sql=false \
  --parameter=git_head::"$(git rev-parse HEAD)" \
  --parameter=repository_state::COMMITTED_SOURCE \
  < sql/structural/06_freeze_layer_scores_t0.sql
```

接著建立 Google Maps 可讀的聚合 cell payload：

```bash
bq --project_id=devjam26aug17tpe-1270 --location=asia-east1 query \
  --use_legacy_sql=false \
  < sql/structural/07_materialize_map_payload.sql
```

地圖資料表為：

```text
devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0
```

## 驗證邊界

`scripts/render_rat_radar_retrospective_sql.py` 只可在 T0 freeze 後使用。它會從本機 CSV 產生 validation-only SQL，不會把說明、照片、地址或原始座標寫入 BigQuery。既有通報結果一律標記為 `DEVELOPMENT_EXPOSED_RETROSPECTIVE`，不能宣稱為未來泛化或現場 Ground Truth。

## FastAPI service（`services/hotspot_api/`）

實作 [GitHub issue #4](https://github.com/Subterrat/subterrat/issues/4)：部署在 Cloud Run 的唯讀 FastAPI，直接查詢已 materialize 的
`devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`（見上面「建立臺北 S2 Level 15 網格」段落），讓 Flutter／Google Maps
不需要 BigQuery credential 就能讀熱點網格。這一版只服務既有 deterministic hotspot ranking，不在 request time 重算模型。

Public read-only endpoints（`services.hotspot_api.public_app:app`）：

```text
GET /healthz
GET /readyz
GET /api/v1/model-capabilities
GET /api/v1/map/bootstrap
GET /api/v1/releases/current
GET /api/v1/releases/{release_id}/cells?bbox=west,south,east,north&limit=500
GET /api/v1/releases/{release_id}/cells/{cell_id}
```

Issue #4 只要求唯讀 API；`docs/API_CONTRACT.md` 第 6 節描述的 internal `/internal/v1/prediction-runs` command API 不在這個 service 的範圍內。

`map_hotspot_cells_t0` 目前只有兩組（food／sewer）ranked layer，沒有三組合併的 `structural_score`／`rank_percentile`／`top_k`，也沒有 `target_window`（這是 development-exposed retrospective freeze，不是 official_t0 run）。回應裡這些欄位固定回傳 `null`，不得虛構；`raw_layer_fields` 則原樣帶出 `food_score`、`sewer_score`、`sewer_coverage_state`、`unused_public_building_address_point_count`、`freeze_id`、`model_kind`、`score_semantics`、`evidence_state` 等 issue #4 要求的欄位。

### Runtime 設定

```text
GOOGLE_CLOUD_PROJECT=devjam26aug17tpe-1270
BQ_LOCATION=asia-east1
BQ_DATASET=subterrat_predictions
BQ_TABLE=map_hotspot_cells_t0
RELEASE_ID=t0-layerwise-development-20260817-v2
MAX_FEATURES_PER_REQUEST=1500
```

`RELEASE_ID` 決定 `/readyz`、`/releases/current`、`/releases/{release_id}/cells*` 服務哪一個 `freeze_id`；換 freeze 時只需要改這個環境變數，不必改程式碼。

### 安裝與本機執行

依賴已與資料管線腳本共用同一個 `pyproject.toml`／`uv.lock`（`dev` group 額外含 `httpx`，供 FastAPI `TestClient` 使用）：

```bash
uv sync --group dev
PYTHONPATH=. uv run python -m unittest discover -s tests -v
```

```bash
PYTHONPATH=. uv run uvicorn services.hotspot_api.public_app:app --reload --port 8080
```

`/healthz` 與 `/api/v1/model-capabilities` 不需要 GCP 憑證。`/readyz`、`/releases/current`、`/releases/{release_id}/cells*` 會實際查詢
`map_hotspot_cells_t0`，本機測試前先 `gcloud auth application-default login`；Cloud Run 上則由 issue #4 描述的專用 runtime service
account（`subterrat-hotspot-api@devjam26aug17tpe-1270.iam.gserviceaccount.com`，只有 `subterrat_predictions` dataset 的
`bigquery.dataViewer`）提供權限。Dockerfile／Cloud Run 部署設定與 Flutter 一起處理，不在本次變更範圍內。
