# SubTerrat sewer v0.2 BigQuery candidate runbook

## 證據邊界

本流程只建立 outcome-free sewer metric candidates。它不讀取 Rat Radar、不覆寫
v0.1 freeze、不建立五項 composite，也不產生鼠患機率。既有 889 筆通報不得用於
決定欄位、清理門檻、權重、Top-K 或模型版本。

## 前置條件

- Google Cloud project：`devjam26aug17tpe-1270`
- BigQuery location：`asia-east1`
- Python 3.11+，並已安裝 `requirements-dev.txt`
- v0.1 的 `analysis_cells`、`cell_features_t0_candidate` 與
  `sewer_access_point_candidate_geo` 已存在
- 執行者具有目標 datasets 的 BigQuery Job User／Data Editor 權限

## 1. 取得兩個官方 XML shard

來源資料集：`臺北市公共管線圖資_污水系統管線`。兩個 shard 必須一起處理。

```bash
mkdir -p artifacts/sewer-v0.2/source
curl -fL \
  'https://data.taipei/api/dataset/9b25821a-c0d0-438d-a027-4a09f4640813/resource/7d82d9c9-8d89-4058-b845-f86698aee70f/download' \
  -o artifacts/sewer-v0.2/source/A8040101_11502_1.xml
curl -fL \
  'https://data.taipei/api/dataset/9b25821a-c0d0-438d-a027-4a09f4640813/resource/bb299d68-e7e8-46c6-b187-5ff04c6ed00c/download' \
  -o artifacts/sewer-v0.2/source/A8040101_11502_2.xml
```

## 2. 匯出 BigQuery NDJSON

```bash
PYTHONPATH=. .venv/bin/python scripts/export_taipei_sanitary_pipe_bq.py \
  artifacts/sewer-v0.2/source/A8040101_11502_1.xml \
  artifacts/sewer-v0.2/source/A8040101_11502_2.xml \
  --resource-id 7d82d9c9-8d89-4058-b845-f86698aee70f \
  --resource-id bb299d68-e7e8-46c6-b187-5ff04c6ed00c \
  --snapshot-date 2026-02-23 \
  --output artifacts/sewer-v0.2/sanitary_pipe_v0_2.ndjson \
  --manifest artifacts/sewer-v0.2/sanitary_pipe_v0_2.manifest.json
```

先檢查 manifest 的 `record_count`、`unique_segment_ids`、檔案 SHA-256 與
`quality_flag_counts`。`outcome_data_read` 必須為 `false`。

## 3. 建立 canonical raw table 並載入 staging

```bash
bq --project_id=devjam26aug17tpe-1270 --location=asia-east1 query \
  --use_legacy_sql=false \
  < sql/structural/08_create_sewer_pipe_v0_2_raw.sql

bq --project_id=devjam26aug17tpe-1270 --location=asia-east1 load \
  --replace \
  --source_format=NEWLINE_DELIMITED_JSON \
  --schema=contracts/bigquery_sanitary_pipe_v0_2_schema.json \
  subterrat_raw.sanitary_pipe_segment_v0_2_load_stage \
  artifacts/sewer-v0.2/sanitary_pipe_v0_2.ndjson
```

staging 可以覆寫；canonical raw table 只透過下一步的 immutable MERGE 新增。
相同 snapshot／segment 的內容若改變，SQL 會 fail closed。

## 4. Merge、curate、materialize 與排名

```bash
PIPE_SNAPSHOT_ID="$(
  .venv/bin/python -c \
    'import json; print(json.load(open("artifacts/sewer-v0.2/sanitary_pipe_v0_2.manifest.json"))["source_snapshot_id"])'
)"

bq --project_id=devjam26aug17tpe-1270 --location=asia-east1 query \
  --use_legacy_sql=false \
  --parameter=source_snapshot_id::"${PIPE_SNAPSHOT_ID}" \
  < sql/structural/09_merge_and_curate_sewer_pipe_v0_2.sql

for sql_file in \
  sql/structural/10_materialize_sewer_metrics_v0_2.sql \
  sql/structural/11_rank_sewer_metrics_v0_2.sql \
  sql/structural/12_sewer_metrics_v0_2_quality.sql
do
  bq --project_id=devjam26aug17tpe-1270 --location=asia-east1 query \
    --use_legacy_sql=false < "${sql_file}"
done
```

## 5. 檢查輸出

本流程應建立：

- `subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
- `subterrat_features.sewer_metrics_v0_2_candidate`
- `subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
- `subterrat_curated.sanitary_pipe_v0_2_quality_candidate`
- `subterrat_predictions.sewer_metric_quality_v0_2_candidate`

必須確認：

- cell metrics 為 3,420 rows，cell 唯一
- rankings 為 17,100 rows，即 3,420 cells × 5 metrics
- 缺值保持 `NULL`，沒有動態補零或重配權重
- blocked／conditional metrics 只有 `diagnostic_percentile`，`metric_score` 必須為 `NULL`
- `score_semantics=BLOCKED_METRICS_HAVE_DIAGNOSTIC_PERCENTILE_NOT_MODEL_SCORE`
- `evidence_state=OUTCOME_FREE_NOT_FROZEN`
- `composite_allowed_now=false`
- depth、install date、geometry、coverage 與 authority gates 仍如實顯示 blocked／conditional

在 authority review 與同範圍 coverage gate 通過前，不得建立
`sewer_paper_composite_v0_2`、freeze 或執行 outcome validation。
