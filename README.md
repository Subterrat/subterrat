# SubTerrat 前端

臺北見鼠通報熱點預測的地圖介面。Flutter，目前只建 web 平台。

## 先設定 Maps 金鑰

`web/index.html` 裡的金鑰是佔位字串 `YOUR_MAPS_API_KEY`。**這個檔案要進版控，但金鑰不能進版控。**

在自己電腦上替換：

```bash
# 把 YOUR_MAPS_API_KEY 換成實際金鑰後，叫 git 不要追蹤這個檔案的變動
git update-index --skip-worktree web/index.html
```

這樣你本機有真金鑰，但 `git status` 不會顯示、也不會不小心提交。要改回追蹤用 `--no-skip-worktree`。

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

## 後端需要提供的四個端點

| 端點 | 用途 |
| --- | --- |
| `GET /api/risk?top=380` | 網格與結構性分數 |
| `GET /api/observed` | 見鼠雷達通報，用來算命中率 |
| `GET /api/provenance` | release_id、freeze_id、分數語意、證據狀態 |
| `POST /api/reports` | 民眾通報 |

回傳格式見 `lib/models.dart` 的 `fromJson`。

## 檔案結構

| 檔案 | 內容 |
| --- | --- |
| `lib/main.dart` | 進入點，讀 `API_BASE` |
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

## 字型

`assets/fonts/` 只放 DM Mono（Latin，約 100KB），用在代號與數值欄位。中文沿用系統字型，不打包 CJK 字型以免 web 首次載入變慢。

DM Mono 採 SIL Open Font License，授權全文在 `assets/fonts/OFL.txt`，散布時要一併保留。

## 待辦

- logo 色碼與圖檔目前是佔位值（`Palette.brand` / `_BrandMark`）
- Figma 的主色還是綠色 `#126D50`，需與這裡的深藍同步
- 字級：Figma 原稿最小 7px，這裡拉到 11px 起跳（7px 投影看不見），Figma 需跟著調
