# v0.3 Synthetic Network Redistribution：部分推演證據

## 結論先行

BigQuery 已用真實的 frozen cell、餐飲分數、v0.2 地下水道五項指標，以及一個 deterministic 管線樣本完成 iteration 0–2 的 read-only 推演。結果顯示：在目前的人工轉移規則下，餐飲 seed 可以沿樣本地下水道相鄰關係重新分配，而且總 state mass 維持約為 1。

這只證明計算流程與 redistribution mechanics 可以運作。它不是實際鼠群擴散、風險預測、機率、最終 v0.3 熱點圖或可派工結果。

## 執行證據

| 欄位 | 值 |
|---|---|
| 執行日期 | 2026-08-18 |
| BigQuery project | `devjam26aug17tpe-1270` |
| Location | `asia-east1` |
| Job ID | `bquxjob_510d8b94_1a011bcc518` |
| 完整 job reference | `devjam26aug17tpe-1270:asia-east1.bquxjob_510d8b94_1a011bcc518` |
| SQL | `sql/analysis/23_preview_network_redistribution_sample_v0_3.sql` |
| 執行模式 | read-only source tables + temporary tables |
| 永久 challenger tables | 未建立 |
| Evidence 狀態 | `NO_TRUSTED_RESULT` |
| Operational use | `PROHIBITED` |

## 輸入與取樣

- Cell universe：3,420 個 `taipei_county_1140318_s2_l15_v1` frozen cells。
- 餐飲 seed：`t0-layerwise-development-20260817-v2` 的 `food_score × eligible_area_m2`，再正規化為總和 1。
- 地下水道指標：v0.2 的五個 cell-level diagnostic percentiles：系統類型、地表高程、連接管徑、連接深度、連接管齡。
- 管線 snapshot：`979ee9ac61c536177f4ee929afb2fcf44313023f6ae6d3f0585a7ffd26ea0911`。
- 管線樣本：依 `FARM_FINGERPRINT(source_resource_id || ':' || segment_id)` 排序後，在 cell universe 內取前 5,000 個有效且啟用中的 LineString。
- Rat Radar／見鼠地圖：未使用於 seed、feature、參數或模型選擇。

本次只以餐飲作為 seed 來檢查地下水道 network redistribution。它不是已鎖定的「餐飲＋地下水道＋都更」v0.3 composite model 執行結果。

## 固定推演規則

- Cell 有可用相鄰連結時：65% self transition、35% 依地下水道 route weight 分配至相鄰 cells。
- Route weight：`0.25 + 0.75 × 兩端地下水道指標平均值`。
- 每次 recurrence：25% 重新注入原始餐飲 seed，75% 使用上一輪 transition 結果。
- 僅計算 abstract iteration 0、1、2；iteration 不代表天數或任何真實時間尺度。

## QA 結果

| 指標 | 結果 |
|---|---:|
| sampled source segments | 5,000 |
| collapsed sampled segments | 0 |
| boundary-overlap sampled segments | 0 |
| sampled binary cross-cell links | 320 |
| metric-eligible sampled links | 315 |
| cells with sampled metric links | 510 / 3,420（14.91%） |
| state mass at iteration 0 | 1.000000000000000000000013 |
| state mass at iteration 1 | 1.000000000000000000000005 |
| state mass at iteration 2 | 1.000000000000000000000002 |
| preview display scale max | 0.001631575320883920544109 |

約 `1e-23` 等級的偏差來自 BIGNUMERIC quantization；transition row-sum assertion 已通過。樣本 graph 只連到 14.91% 的 cells，因此空間覆蓋仍然稀疏。

## 可觀察的 redistribution 範例

以下是依 iteration 2 相對原始 seed 的 absolute change 排序所得結果片段：

| cell_id | lon | lat | neighbors | seed | state 2 | change |
|---|---:|---:|---:|---:|---:|---:|
| `3765759381971402752` | 121.555553 | 25.027114 | 2 | 0.001070835447 | 0.001401293841 | +0.000330458393 |
| `3765759676176662528` | 121.575530 | 24.985284 | 1 | 0 | 0.000329753532 | +0.000329753532 |
| `3765759686914080768` | 121.575530 | 24.987936 | 1 | 0.001025472596 | 0.000695719064 | -0.000329753532 |
| `3765761810775408640` | 121.564115 | 25.088739 | 1 | 0 | 0.000325655533 | +0.000325655533 |
| `3765761817217859584` | 121.564115 | 25.086088 | 1 | 0.001012728578 | 0.000687073045 | -0.000325655533 |

在這個人工規則中，原始餐飲 seed 為 0 的 cell 可以從相鄰 cell 接收 state，而 donor cell 會出現近似對應的下降。這是預期的質量重新分配行為，不代表該 cell 真實發生鼠群擴散。

## 證據邊界與下一個 gate

目前已證明：

1. 真實來源資料可以產生 deterministic sampled graph。
2. elementary-edge traversal 能建立相鄰 cell links。
3. v0.2 地下水道五項指標能參與 route weighting。
4. iteration recurrence 能執行且守恆。

目前未證明：

1. 5,000 段管線樣本可代表完整臺北地下水道網路。
2. 35% network movement、25% reinjection 或 route-weight 公式符合真實鼠群行為。
3. iteration 對應任何時間、距離或傳播速度。
4. redistribution 後的 cell 排名與 Rat Radar 有外部一致性。
5. 餐飲、地下水道與都更 composite seed 已鎖定或已完成永久 materialization。

在 parent v0.3 model lock、finalized input manifest 與 commit identity 完成前，不建立永久 challenger tables，也不把這份 preview 升格為熱點產品輸出。
