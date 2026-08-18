# v0.3 三因子 composite：BigQuery 部分結果

## 結論先行

v0.2 把地下水道從 v0.1 的單一系統類型，擴充成五項文獻導向 attributes 後，與 v0.1 sewer 仍有中度分數關聯，但選出的高分區域已明顯改變。v0.2 sewer 和 frozen food 幾乎沒有分數一致性；它提供的是不同空間訊號，不是餐飲 layer 的替代版本。

餐飲、v0.2 sewer、都更行政 site proxy 各以 `1/3` 合成的 v0.3 read-only preview 已在 BigQuery 成功執行。不過「係數相等」不等於「對排名影響相等」：目前 composite 與餐飲、都更的關聯都高，與 sewer 的關聯較低。主要原因是 sewer component 的分布變異較小，而且 complete-case coverage 只有臺北 eligible area 的 49.28%。

## 執行證據

| 欄位 | 值 |
|---|---|
| 執行日期 | 2026-08-18 |
| Project / location | `devjam26aug17tpe-1270` / `asia-east1` |
| Job ID | `bquxjob_4f7e0a1c_1a011c80294` |
| 完整 job reference | `devjam26aug17tpe-1270:asia-east1.bquxjob_4f7e0a1c_1a011c80294` |
| SQL | `sql/analysis/24_preview_hotspot_composite_v0_3.sql` |
| 執行結果 | 12 statements，12 秒，`SUCCESS` |
| 執行模式 | read-only source tables + temporary tables |
| 永久 composite table | 未建立 |
| Evidence | `NO_TRUSTED_RESULT` |
| Operational use | `PROHIBITED` |

查詢未讀取 Rat Radar／見鼠地圖，也未用通報結果決定 feature、方向、半徑、權重或版本。

## 固定公式

```text
V03(c) = (
  FrozenFoodV01(c)
  + SewerFiveMetricCompleteCaseV02(c)
  + RenewalAdminSitePercentile150m(c)
) / 3
```

- 三組各 `1/3` 是 outcome-blinded、preregistered assumption。
- Sewer 五項各占 sewer group 的 `1/5`，因此對公式的明示係數各為 `1/15`。
- 任一 group 缺值，composite 為 `NULL`，不動態重分配權重。
- 150 m 是 cell-footprint analysis window，不是鼠群移動、施工影響或擴散半徑。

## Coverage 與分布

| Variant | Scoreable cells | Scoreable area | Mean | SD | Selected cells | Actual selected city area |
|---|---:|---:|---:|---:|---:|---:|
| Food v0.1 | 3,420 | 100.00% | 0.2668 | 0.3950 | 319 | 10.000% |
| Sewer system type v0.1 | 1,801 | 55.68% | 0.4761 | 0.2614 | 380 | 11.659% |
| Sewer five-metric v0.2 | 1,589 | 49.28% | 0.4932 | 0.1486 | 321 | 10.031% |
| Renewal admin site 150 m | 3,420 | 100.00% | 0.1441 | 0.3279 | 556 | 17.314% |
| v0.3 equal-group composite | 1,589 | 49.28% | 0.4494 | 0.2409 | 319 | 10.003% |

Renewal component 有大量 tied zero／count percentiles；依固定的 `INCLUDE_ALL_THRESHOLD_TIES` 規則，其 top-area threshold 一次納入 17.31% city area。Composite 的連續組合值減少了 threshold ties，所以較接近 10% target。

## v0.1、v0.2 與餐飲直接比較

下表的 correlation 只在兩張圖皆有分數的 common support 計算；Jaccard 以兩張圖各自的 selected eligible area 計算。

| Left map | Right map | Common cells | Score correlation | Selected-area Jaccard |
|---|---|---:|---:|---:|
| Sewer five-metric v0.2 | Sewer system type v0.1 | 1,589 | 0.6222 | 0.2613 |
| Sewer five-metric v0.2 | Food v0.1 | 1,589 | -0.0071 | 0.1113 |
| Sewer system type v0.1 | Food v0.1 | 1,801 | 0.0540 | 0.0028 |

可支持的解讀：

1. v0.2 與 v0.1 sewer 不是完全不同的訊號，但新增高程、管徑、埋深、管齡後，top-area placement 已有實質改變。
2. v0.2 sewer 和 food 在 common support 上幾乎不一起升降；selected-area overlap 也有限。
3. 這不證明 sewer 比 food 更好，只證明兩者測量的空間構念不同。

## v0.3 composite 受各 component 影響的樣子

| Composite compared with | Common cells | Score correlation | Selected-area Jaccard |
|---|---:|---:|---:|
| Renewal admin site 150 m | 1,589 | 0.8370 | 0.5778 |
| Food v0.1 | 1,589 | 0.8267 | 0.4501 |
| Sewer five-metric v0.2 | 1,589 | 0.2000 | 0.1370 |

因此目前 v0.3 雖然明示係數是等權，實際排名較接近 food 與 renewal。Sewer 的 SD 只有 0.1486，低於 food 的 0.3950 與 renewal 的 0.3279；相同係數下，它能造成的 cell-to-cell score 差異較小。這是解釋 composite 時必須揭露的模型特性，不應事後利用 Rat Radar 調權重。

## Top composite cells 範例

| cell_id | lon | lat | Food | Sewer v0.2 | Renewal 150 m | Composite |
|---|---:|---:|---:|---:|---:|---:|
| `3765758645384511488` | 121.532718 | 25.019225 | 0.9804 | 0.7757 | 0.9874 | 0.9145 |
| `3765758671154315264` | 121.529864 | 25.022549 | 0.9438 | 0.7183 | 0.9702 | 0.8775 |
| `3765759377676435456` | 121.552699 | 25.025133 | 0.9880 | 0.6568 | 0.9702 | 0.8717 |

BigQuery result 同時回傳前 50 個 cells 的 centroid、三項 components、complete-case rank、selected-area flag 與固定尺度 display value，可作部分 map payload 檢查。這些 top cells 只能稱 internal-simulation 高分 cells。

## BigQuery 地圖預覽

`sql/analysis/25_preview_hotspot_composite_map_v0_3.sql` 另產生完整 3,420 個
analysis-cell polygons 與 centroid map points；其中 1,589 筆有 complete-case
composite，1,831 筆保留 `NULL` 與 `MISSING_SEWER_COMPLETE_CASE`。final job
`devjam26aug17tpe-1270:asia-east1.bquxjob_24ad5cf9_1a011d71c37` 成功。查詢只用
temporary tables，沒有建立 serving table。React static fixture SHA-256 為
`b806fda5fdb7293972da77c6aa8e587088672a829f5f7237880f9b48556a7203`。

BigQuery Visualization 已以 `map_point` 作 geography、
`relative_preview_display_value` 作 data column，固定顯示範圍約 `0.04–1.00`，並在
Google street／OpenStreetMap basemap 上成功呈現臺北空間分布。Heat layer 只對
1,589 個 scoreable cells 使用強度；cell-audit mode 同時呈現另外 1,831 個缺少
v0.2 sewer complete-case support 的 cells，並以 missing 樣式區分，不能被解讀成
低值或零值。

## 尚未跨過的 gate

- Composite 仍受 v0.2 sewer 49.28% area coverage 限制；未評分區不能被解讀成低值。
- 都更來源的 reuse license、完整性、status taxonomy 與時間意義仍未解決。
- 等權公式是可重現假設，不是由文獻估得或經 field outcome 校準的係數。
- 尚未完成 committed specification identity、finalized manifest 與 parent lock。
- 因此不建立永久 composite／map serving table，也不執行 Rat Radar retrospective concordance。
