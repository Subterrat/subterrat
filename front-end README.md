# SubTerrat 前端

臺北見鼠通報熱點預測的地圖介面。Flutter，目前只建 web 平台。

## 先設定 Maps 金鑰

金鑰走 `.env`（`flutter_dotenv`），不寫死在 `web/index.html` 裡——`lib/maps_bootstrap.dart` 會在 `main()` 讀到金鑰後才動態插入 Google Maps 的 `<script>` 標籤，所以 `web/index.html` 本身完全不含任何金鑰或佔位字串。

```bash
cp .env.example .env
# 編輯 .env，把 YOUR_MAPS_API_KEY 換成實際金鑰
```

`.env` 已經在 `.gitignore`（連同 `.env.*`），`.env.example` 才是進版控的範本，改 `.env` 不會被 git 追蹤到。沒有 `.env` 或金鑰還是佔位字串時，`main()` 會直接跳過插入 script，介面照樣跑得起來，只是地圖不會出現。

金鑰在 Google Cloud Console 設兩層限制：

| 限制 | 設成 |
| --- | --- |
| Application restrictions | HTTP referrers，加 `http://localhost:*/*` 與正式網域 |
| API restrictions | 只勾 Maps JavaScript API |

Web 版的 Maps 金鑰一定會出現在瀏覽器裡，這是它的運作方式，藏不住。**保護靠限制，不是靠保密。**

## 執行

```bash
flutter pub get
flutter run -d chrome
```

後端還沒好時會用本機產生的示範資料，可以直接把整個介面跑起來。要接後端：

```bash
flutter run -d chrome --dart-define=API_BASE=https://your-service.run.app
```

`API_BASE` 指向 `services/hotspot_api`（同 GCP project 下讀 BigQuery 的 FastAPI 服務）。部署到 Cloud Run 時記得設 `PUBLIC_CORS_ORIGINS` 環境變數（見該服務的 `config.py`），包含這個前端實際會跑的網域，不設的話瀏覽器會整個擋掉跨網域請求。

## 後端端點

契約定義在 `docs/API_CONTRACT.md`；下面是 `services/hotspot_api` 目前**實際有實作**、`lib/api.dart` 會呼叫的部分：

| 端點 | 用途 |
| --- | --- |
| `GET /api/v1/map/bootstrap` | 目前 release id、臺北市 bbox、圖層可用性 |
| `GET /api/v1/releases/current` | 指向目前公開的 release |
| `GET /api/v1/releases/{release_id}/cells?bbox=...` | 網格與分數，GeoJSON、依 bbox 分頁 |

`GET /api/observed`（見鼠雷達通報）與 `POST /api/reports`（民眾通報）**在後端完全沒有對應端點**，不是還沒接上而是還沒被實作，`lib/api.dart` 目前對這兩塊固定回傳本機/空資料，等後端補上再串。

回傳格式見 `lib/models.dart` 的 `RiskCell.fromGeoJsonFeature`。有一點目前串接上要注意：`structural_score` 現在**一律是 `null`**——`MainScore` 要 food／sewer／abandoned 三組分項都到位才能合成，但「廢棄建築」還沒有 citywide 排名資料，後端不會為了湊一個總分而造假。畫面上排序與地圖上色改用 `RiskCell.rankScore`（可得分項的平均值），不是通過驗證的綜合分數。

## 檔案結構

| 檔案 | 內容 |
| --- | --- |
| `lib/main.dart` | 進入點，讀 `API_BASE`，載入 `.env` 並注入 Maps script |
| `lib/maps_bootstrap.dart` | 動態插入 Google Maps JS SDK `<script>`，金鑰來自 `.env` |
| `lib/theme.dart` | 色票、字級、熱點色階、去飽和底圖樣式 |
| `lib/models.dart` | 資料模型與列舉 |
| `lib/sim.dart` | 鼠群族群機制模型 |
| `lib/api.dart` | API 用戶端與示範資料 |
| `lib/home_page.dart` | 主畫面 |

## 幾個實作上的重點

**熱點的透明度也跟著數值走**，不只是顏色深淺。只改顏色的話每格同樣濃，看起來會是方格拼貼而不是熱點圖。低於門檻的格子整格不畫。

**圓形不確定範圍用結構性分數決定，不是當下熱度。** 圈選代表「事先指出的地方」，播放時間軸時它不該移動。

**觀測通報的密度模式用紫色不是紅色。** 預測範圍是橘色，紅橘同屬暖色，疊在一起時重疊區會糊掉，而那正是要看清楚的地方。

**底圖一定要套 `kMutedMapStyle`。** 沒有它的話 Google 地圖水域的藍會跟介面主色混在一起。

**格子數上限 380。** `google_maps_flutter` 畫太多 Polygon 會掉幀。

## 待辦

- logo 色碼與圖檔目前是佔位值（`Palette.brand` / `_BrandMark`）
- Figma 的主色還是綠色 `#126D50`，需與這裡的深藍同步
- 字級：Figma 原稿最小 7px，這裡拉到 11px 起跳（7px 投影看不見），Figma 需跟著調
- 「廢棄建築」還沒有 citywide 排名資料，`structural_score` 因此一律是 `null`（見上方「後端端點」）；等這組資料到位後才有真正的綜合結構分數
- `GET /api/observed`、`POST /api/reports` 後端還沒實作，前端目前分別固定回退到示範資料／本機佇列
