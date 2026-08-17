# SubTerrat v0.1 可執行流程

## 這一版會產生什麼

v0.1 會在 BigQuery 產生兩個不使用見鼠資料擬合的結構性熱點排序：

- `food_market_only`
- `sewer_system_type_only`

輸出是 `score`、`rank` 與 Top-area flag，不是鼠患機率。廢棄建築目前只有範圍有限的市有未利用建物地址點，因此只顯示 overlay，不進 citywide ranking。

## 前置條件

- Google Cloud project：`devjam26aug17tpe-1270`
- BigQuery location：`asia-east1`
- Python 3.11+
- 已存在下列表格：
  - `subterrat_raw.taipei_s2_l15_grid_raw`
  - `subterrat_curated.food_site_candidate_geo`
  - `subterrat_curated.sewer_access_point_candidate_geo`
  - `subterrat_curated.unused_public_building_candidate`
  - `subterrat_curated.unused_public_building_address_point_candidate_geo`

這個 repository 目前包含網格生成、地址點 join、特徵／排名／freeze／地圖 payload SQL；公開資料的完整 fetch-to-load ingestion 尚未收斂成 repository-owned pipeline。

## 本機驗證

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
PYTHONPATH=. .venv/bin/python -m unittest discover -s tests -v
```

## 建立臺北 S2 Level 15 網格

```bash
PYTHONPATH=. .venv/bin/python scripts/build_taipei_s2_grid.py \
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
