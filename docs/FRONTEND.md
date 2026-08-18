# SubTerrat Flutter Web

臺北結構性見鼠通報熱點排序的地圖介面。目前只建置 Web target。

## 執行模式與證據邊界

| 模式 | 觸發方式 | 資料來源 | 可支持的主張 |
| --- | --- | --- | --- |
| Synthetic demo | `API_BASE` 留空 | `lib/api.dart` 固定種子的示範格子與通報 | 只供 UI 開發／展示；不是臺北資料、模型結果或 validation evidence |
| API-backed map | 設定 `API_BASE` | `services/hotspot_api` 唯讀 map endpoints | 只支持該 API／release 實際回傳的聚合 cell 與 limitation fields |

`lib/sim.dart` 是未經臺北資料校準的 UI scenario prototype。正式 capability contract 將 `scenario_simulation` 標為 `NOT_SUPPORTED`；其曲線、族群數、投餌週期與回訪時間不得描述成模型預測、成效估計、投餌建議或派工依據。

## 設定 Maps 金鑰

金鑰走 `.env`（`flutter_dotenv`），不寫死在 `web/index.html`。`lib/maps_bootstrap.dart` 會在 `main()` 讀到金鑰後才動態插入 Google Maps `<script>`。

```bash
cp .env.example .env
# 編輯 .env，把 YOUR_MAPS_API_KEY 換成實際金鑰
```

`.env` 已被 `.gitignore` 排除；只有 `.env.example` 進版控。沒有 `.env` 或仍是 placeholder 時，介面可以啟動，但不會顯示 Google 地圖。

Web Maps key 必須在 Google Cloud Console 同時限制：

| 限制 | 設定 |
| --- | --- |
| Application restrictions | HTTP referrers，只加入本機與核准網域 |
| API restrictions | Maps JavaScript API |

瀏覽器 key 會出現在 client bundle；保護依賴 referrer 與 API restrictions，不依賴保密。

## 本機執行

Synthetic demo：

```bash
flutter pub get
flutter run -d chrome
```

API-backed map：

```bash
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

另開一個 terminal 啟動 FastAPI：

```bash
uv sync --group dev
PYTHONPATH=. uv run uvicorn services.hotspot_api.public_app:app --reload --port 8080
```

API-backed 模式還需要 FastAPI 能讀取設定的 BigQuery serving table；這是 runtime dependency，不由 Flutter test 證明。

## 實際 API 範圍

FastAPI 目前實作七個唯讀 endpoints；Flutter map path 直接使用其中兩個：

| Endpoint | FastAPI | Flutter 目前使用 |
| --- | --- | --- |
| `GET /healthz` | 已實作 | 否 |
| `GET /readyz` | 已實作 | 否 |
| `GET /api/v1/model-capabilities` | 已實作 | 否 |
| `GET /api/v1/map/bootstrap` | 已實作 | 是 |
| `GET /api/v1/releases/current` | 已實作 | 否；bootstrap 已帶 `current_release_id` |
| `GET /api/v1/releases/{release_id}/cells` | 已實作 | 是 |
| `GET /api/v1/releases/{release_id}/cells/{cell_id}` | 已實作 | 否 |

`GET /api/observed` 不在 public API contract，也沒有 FastAPI route。Synthetic demo 會產生固定種子的示範通報；API-backed 模式下，該 endpoint 回傳非 200 時會顯示空資料。Citizen-report model／送出 UI 已從最新 `main` 移除，文件不得再列出 `POST /api/reports` 或暗示通報會送達政府、見鼠雷達或任何 provider。

`map_hotspot_cells_t0` 目前沒有三組完整的 `structural_score`。API 因此回傳 `structural_score=null`；UI 的 `RiskCell.rankScore` 只是可得 component 的顯示排序，不是正式三組 composite，也不是 validated risk score。

## Cloud Run frontend artifact

Repository 內有 `deploy/frontend.Dockerfile`、Nginx template 與 Cloud Build 設定。這些檔案只證明可建置的 deployment artifact 存在，不證明 Cloud Build 成功、Cloud Run 已部署、公開 URL 可用或 production journey 通過。

目前 frontend container build 沒有傳入 `API_BASE`，因此建出的 Web bundle 固定使用 synthetic demo。既有 implementation plan 同時要求 hotspot API 維持 private；匿名瀏覽器不能直接把這個 private API 當公開 backend。若要讓 Cloud Run frontend 讀 real API，必須先決定並驗證下列其中一種架構：

- 人工核准的 sanitized API 對瀏覽器公開，搭配精確 CORS 與 read-only IAM/data scope；或
- 由同源 server-side proxy／BFF 取得 private API 身分，瀏覽器不持有 GCP credential。

在這項決策完成前，不應把目前 frontend deployment artifact 描述為 real-data production deployment。

## 主要檔案

| 檔案 | 內容 |
| --- | --- |
| `lib/main.dart` | 入口、`API_BASE` 與 Maps bootstrap |
| `lib/maps_bootstrap.dart` | 動態插入 Google Maps JavaScript SDK |
| `lib/theme.dart` | 色票、字級與底圖樣式 |
| `lib/models.dart` | API／demo 共用資料模型 |
| `lib/sim.dart` | 未校準 UI scenario prototype，不是正式 model capability |
| `lib/api.dart` | FastAPI client、synthetic demo 與本機通報行為 |
| `lib/home_page.dart` | 主畫面與互動 |
| `deploy/` | Frontend container／Cloud Build artifacts |

## 尚待決定或完成

- 確認 Cloud Run frontend 的 real API authentication／same-origin 架構。
- 把 synthetic demo 與 API-backed 畫面做不可混淆的持續標示。
- 決定是否保留 `lib/sim.dart`；若保留，需有獨立的 scenario contract、參數來源與 UX boundary，且不能作為現場行動建議。
- 將 brand mark、圖檔與色碼收斂成同一份 design authority。
- `observed` 若要產品化，需另立資料授權、privacy、status 與 feedback-contamination contract；不能直接補一支 endpoint 就視為完成。
