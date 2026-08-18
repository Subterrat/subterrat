# SubTerrat

**鼠害熱點地圖模型**的結構性排序研究，以及對應的地圖介面。

用三組環境資料把臺北市切成格子並排出優先順序，回答的是「如何派遣有限人力」，不是「哪裡有幾隻老鼠」。

---

## 專案目標

臺北市目前的鼠患處理都是被動的：有人通報，才派人處理。由於人力不足，派遣原因常出於民眾投訴，而非鼠患真正棘手的區域。

SubTerrat 用三組跟鼠類生態相關的環境條件，對每個網格算出一個**結構性分數**並排序，讓巡檢資源可以往排序前段集中。

| 特徵組 | 權重 | 為什麼相關 |
| --- | --- | --- |
| 餐飲與傳統市場密度 | 1/3 | 食物來源 |
| 地下水道環境 | 1/3 | 棲息與移動空間 |
| 廢棄建築 | 1/3 | 缺乏管理的藏匿處 |

權重來自已發表的都市鼠類研究，**不是用本地資料擬合出來的**。

---

## 架構與規則

> **見鼠雷達的通報原始訓練資料僅能作為封存後驗證用，不能當特徵、標籤、調權重、選模型、訓練或校準的依據。**

`contracts/structural_score_v0_1.json` 把這條寫成機器可讀的契約：

```json
"outcome_policy": {
  "rat_radar_role": "VALIDATION_ONLY_AFTER_T0_FREEZE",
  "forbidden_uses": ["feature", "label", "weight_tuning",
                     "model_selection", "training", "calibration"]
}
```

而 `sql/validation/11_rat_radar_layerwise_post_freeze_only.sql` 用資料庫層級的 `ASSERT` 強制執行——**未完成封存，驗證 SQL 跑不動**。

原因：如果先看答案再調分數，再拿同一批答案證明分數準，那什麼都沒證明。所以流程必須是「先封存、再觀察」。

---

## 目前狀態

| 項目 | 狀態 |
| --- | --- |
| 證據政策 | `NO_TRUSTED_RESULT` — 尚無任何自動化 Sensor 產生的驗證收據 |
| 模型類型 | `DETERMINISTIC_HOTSPOT_RANKING`，`NO_SUPERVISED_TRAINING` |
| 分析單位 | S2 Level 15 網格，邊界取自政府開放資料 `COUNTY_MOI_1140318` |
| 圈選規則 | 合格面積的前 10%，同分全收並回報實際面積佔比 |
| 對照基準 | 隨機面積期望值，以及 `food_market_only` 單層變體 |

三個單層變體：

| 變體 | 來源欄位 | 狀態 |
| --- | --- | --- |
| `food_market_only` | `food_market_sites_per_km2` | 暫定可用 |
| `sewer_system_type_only` | `sanitary_system_record_share` | 暫定可用 |
| `abandoned_building_only` | 市有未利用建物地址點 | **僅 overlay，尚未涵蓋全市** |

缺資料的層不會補值，而是回報 `PUBLISH_BLOCKED_STATUS_NOT_IMPUTED_SCORE`——**缺資料不等於低風險**。

---

## 輸出

只有 `structural_score`、`rank`、`top_area_flag` 三種。

禁止出現 `rat_probability`、`rat_presence_probability`、`disease_risk_probability`。

也就是說：

| 可以說 | 不可以說 |
| --- | --- |
| 這一格的結構性分數排在前 10% | 這裡有 N% 機率有鼠患 |
| 三組環境條件形成的排序 | 這裡有幾隻老鼠 |
| 供環境檢視參考的優先順序 | 應該在這裡投多少藥 |

`calibrated_probability` 永遠是 `null`，直到取得臺北在地的 E2／E3 現場標籤並完成校準為止。

---

## Repository 結構

| 路徑 | 內容 |
| --- | --- |
| `docs/BELIEF.md` | 核心工作假設與可反證條件。**衝突時以這份為最高權威** |
| `docs/HARNESS_ARCHITECTURE.md` | Evidence／Belief／Decision／Action／Feedback 的邊界 |
| `docs/API_CONTRACT.md` | FastAPI transport contract |
| `docs/openapi-v1.yaml` | OpenAPI 投影 |
| `docs/V0_1_RUNBOOK.md` `V0_2_RUNBOOK.md` | 可執行流程 |
| `contracts/` | 機器可讀的模型與資料契約 |
| `sql/structural/` | 網格、特徵、分層評分、品質檢查、T0 封存、地圖 payload |
| `sql/validation/` | 封存後才能執行的驗證 |
| `scripts/` | 網格生成、圖資匯出、地址點 geocode、見鼠雷達回溯 SQL 產生器 |
| `services/hotspot_api/` | 公開唯讀 FastAPI 服務 |
| `lib/` `web/` `assets/` | Flutter web 地圖介面 |
| `deploy/` | Cloud Build、Dockerfile、nginx 設定 |
| `tests/` `test/` | Python 與 Dart 測試 |

閱讀順序建議：`AGENTS.md` → `docs/BELIEF.md` → `docs/HARNESS_ARCHITECTURE.md`。

---

## 執行

### 前端（Flutter web）

```bash
cp .env.example .env      # 填入 Maps API 金鑰
flutter pub get
flutter run -d chrome
```

金鑰走 `.env`（`flutter_dotenv`），由 `lib/maps_bootstrap.dart` 在 `main()` 動態插入 Google Maps script，**`web/index.html` 本身不含任何金鑰**。`.env` 已在 `.gitignore`。

沒有 `.env` 時介面照樣跑得起來，只是地圖不顯示。

接後端：

```bash
flutter run -d chrome --dart-define=API_BASE=https://your-service.run.app
```

### 後端（FastAPI）

```bash
uv sync --group dev
PYTHONPATH=. uv run python -m unittest discover -s tests -v
```

`uv` 會依 `.python-version` 自動取得 Python 3.12 並照 `uv.lock` 安裝依賴，不需要手動建 venv。

部署到 Cloud Run 時記得設 `PUBLIC_CORS_ORIGINS`，包含前端實際網域，否則瀏覽器會擋掉跨網域請求。

### 資料管線

見 `docs/V0_1_RUNBOOK.md`。需要 GCP project `devjam26aug17tpe-1270`、BigQuery location `asia-east1`，以及 `subterrat_raw` / `subterrat_curated` 底下數個既有表格。

公開資料的完整 fetch-to-load ingestion 尚未收斂成 repository-owned pipeline。

---

## 已實作的 API

契約定義在 `docs/API_CONTRACT.md`，以下是實際有實作的部分：

| 端點 | 用途 |
| --- | --- |
| `GET /api/v1/map/bootstrap` | 目前 release id、臺北市 bbox、圖層可用性、證據狀態 |
| `GET /api/v1/releases/current` | 指向目前公開的 release |
| `GET /api/v1/releases/{release_id}/cells?bbox=` | 網格與分數，GeoJSON、依 bbox 分頁 |
| `GET /api/v1/model-capabilities` | 模型實際支援與不支援的輸出能力 |
| `GET /healthz` `GET /readyz` | 存活與就緒 |

`model-capabilities` 存在的理由：**未實作的能力不得由前端自行推測**。前端要先問後端支援什麼，再決定顯示什麼。

尚未實作、但契約已定義的有 `GET /api/v1/releases/{release_id}`（回傳 freeze 與 target window）、`forecast-history`、`stats`。

---

## 驗證怎麼做

主要指標是 **Capture@K**：圈選前 10% 面積的網格，在觀測窗內捕捉到多少比例的合格通報。

必須同時跟三個事先登錄的對照組比較：

1. 隨機面積期望值
2. 人口／通報機會
3. `food_market_only` 單層變體

第三個是及格線。`docs/BELIEF.md` 的可反證條件寫著：無法穩定超越餐飲密度單一特徵時，必須降低或改寫 Belief，而不是替既有方向找理由。

第一階段沒有可信的負樣本，所以**不報 accuracy、specificity、PR-AUC 或校準機率**。

---

## 我們「沒有」要做什麼

- 預估鼠群數量或密度
- 建議餌劑種類、劑量或投放位置
- 自動派工、封堵、修繕或發布公共衛生警報
- 判定特定店家或住宅有鼠患
- 把單一民眾通報當成 Ground Truth
- 為了展示技術而拆分沒有獨立責任的多個 Agent

