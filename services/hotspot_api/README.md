# SubTerrat Hotspot API container

這個 container 只啟動唯讀 FastAPI transport：
`services.hotspot_api.public_app:app`。它查詢 BigQuery 已 materialize 的聚合資料，
不在 request-time 重算 score、不執行 BigQuery 寫入，也不提供 POST／PUT／PATCH／DELETE
route。

## Build

Docker build context 必須是 repository root，因為 production dependencies 由 root
`pyproject.toml` 與 `uv.lock` 鎖定：

```bash
docker build \
  --file services/hotspot_api/Dockerfile \
  --tag subterrat-hotspot-api:local \
  .
```

Dockerfile 使用 Python 3.12 slim、`uv sync --frozen --no-dev`，並以固定的非 root
UID/GID `10001:10001` 啟動。Cloud Run 會注入 `PORT`；未注入時預設為 `8080`。

Repository root 的 `.dockerignore` 與 `.gcloudignore` 排除 `.git`、
`.venv`、`artifacts` 與原始 CSV，避免將無關或受限資料上傳到
Docker／Cloud Build context。

## Local smoke

```bash
docker run --rm --publish 8080:8080 subterrat-hotspot-api:local
curl --fail http://127.0.0.1:8080/healthz
```

`/healthz` 不查 BigQuery，只能證明 process 能回應。`/readyz` 會查目前 release 的
serving table；它成功也只證明指定 BigQuery aggregate release 可讀，不證明模型有效、
具有外部效度或可作營運決策。

## Cloud Run runtime contract

服務設定沿用 `services/hotspot_api/config.py`：

- `GOOGLE_CLOUD_PROJECT`
- `BQ_LOCATION`（目前資料位於 `asia-east1`）
- `BQ_DATASET`、`BQ_TABLE`、`RELEASE_ID`
- `BQ_V03_TABLE`、`BQ_V03_EVALUATION_TABLE`
- `BQ_SIMULATIONS_DATASET` 與四個 `BQ_NETWORK_*_TABLE`
- `LAB_V03_ENABLED`（預設關閉；只在核准的 internal research service 開啟）
- `MAX_FEATURES_PER_REQUEST`
- `PUBLIC_CORS_ORIGINS`

Container 不包含 service-account key。Cloud Run 應以專用 service identity 取得最小
BigQuery query/read 權限，且不得取得 `subterrat_t1_vault`、raw 精確通報、精確地下設施
或 BigQuery write 權限。IAM 必須另外由部署 owner 設定與驗證；本目錄不修改 IAM。

目前 API 所有 application routes 都是 GET。這是程式層的唯讀邊界；BigQuery 的實際
唯讀保證仍必須由 service identity 的 IAM 權限落實。
