# SubTerrat v0.3：餐飲、下水道與都更行政資料 internal simulation

狀態：`GPT_PRO_REVISED_AWAITING_COMMITTED_SPECIFICATION_LOCK`

## 1. 研究問題與邊界

v0.3 不做鼠患機率或風險預測，只建立 outcome-blinded、deterministic、
ordinal 的內部空間比較：

1. v0.2 五項 sewer attribute complete-case index 與 frozen v0.1 food 的
   coverage、score agreement 與 selected-area overlap 有何差異？
2. 在餐飲、sewer attribute index、核定重建行政 site proxy 固定等權時，
   內部 comparison map 的分布如何？
3. 規格、Git revision 與資料 snapshot 全部鎖定後，既有 889 筆見鼠通報與
   各 map-as-delivered 的位置重合程度為何？

第三題只叫一次性 retrospective report-location concordance，不是 validation；
結果不得回灌特徵、方向、半徑、權重、support、normalization 或版本選擇。

固定狀態：

- `specification_state = PENDING_COMMITTED_LOCK`，commit 後才可變成 `LOCKED`
- `use_state = INTERNAL_SIMULATION_ONLY`
- `evidence_state = NO_TRUSTED_RESULT`
- `operational_use = PROHIBITED`

## 2. 文獻能支持到哪裡

- Seattle 研究支持 sanitary system、地勢、管徑、埋深、管齡等 sewer
  attributes 值得分開檢視，但不提供可直接移植到臺北的係數。
  [論文](https://doi.org/10.1007/s11252-022-01255-2)／
  [Dryad](https://doi.org/10.5061/dryad.mw6m90603)
- 荷蘭三城市研究支持餐廳與捕獲量之間的局部關聯；其 150 m context 不能
  被解讀成臺北老鼠移動或施工影響距離。
  [Urban Ecosystems](https://doi.org/10.1007/s11252-024-01513-5)
- Chicago permits 與 complaints 的研究顯示小幅關聯，也明確提醒 permit
  date 不等於施工日期，通報受可見度與意願影響。
  [Journal of Urban Ecology](https://doi.org/10.1093/jue/juab006)
- Vancouver 捕捉研究支持 parcel、建物狀況與垃圾等 habitat mechanisms；
  都市更新行政案件不能因此被當作廢棄建築或物理施工。
  [PLoS ONE](https://doi.org/10.1371/journal.pone.0097776)

因此 150 m 只叫 preregistered `cell_footprint_buffer` analysis window；都更
component 只叫 `approved_rebuilding_admin_site` proxy。

## 3. 實際資料與 QA

### 3.1 v0.2 sewer 與 food v0.1

2026-08-18 的 live BigQuery outcome-free 比較沒有讀取 Rat Radar：

| Sewer diagnostic | Scored cells | Scored area | Food score correlation | Top-area Jaccard |
| --- | ---: | ---: | ---: | ---: |
| pipe age | 1,608 | 49.78% | 0.414 | 0.211 |
| pipe depth | 1,608 | 49.78% | -0.015 | 0.080 |
| pipe diameter | 1,608 | 49.78% | -0.100 | 0.063 |
| system type | 1,801 | 55.68% | 0.054 | 0.003 |
| surface elevation | 1,761 | 54.56% | -0.353 | 0.002 |
| five-metric complete-case mean | 1,589 | 49.28% | -0.007 | 0.111 |

可支持的窄結論是：complete-case sewer index 在其 analyzed support 上，和
food 的 aspatial score agreement 很低，selected-area overlap 有限。這不證明
它是更好的構念；五項中仍有四項 gate 未通過，coverage 也只有 49.28%。

### 3.2 都更行政來源

Repository CSV 有 2,365 rows，live stage／raw／curated QA 為 2,365 unique
row identities、0 invalid coordinates、1 source snapshot：
`f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e`。

Likely provider 是財團法人都市更新研究發展基金會的
[臺北市都市更新地圖](https://www.ur.org.tw/classroom/map_view/11)，頁面嵌入 My
Maps ID `1HIJwAuZc21A7FnoPBaIWPARkF7g` 並標示 All Rights Reserved。未找到
明確 data reuse license、provider publication date、completeness statement、
field dictionary 或 status taxonomy，所以 publication gate 仍關閉。

固定 inclusion 是 250 個「已核定重建且未明示完工」source rows。`編號` 欄位
有 248 個 unique values；`北494` 與 `北521` 重複。因此 SQL 先依 normalized
`編號` 形成 248 個 administrative sites，以最低 source row 的座標作 deterministic
representative geometry，並保留 source-row count。`編號` 只視為 provider-
undocumented site key，不稱 authoritative project ID。

Pre-review row-based live profile 是 249/250 rows 可與 analysis cell geometry
匹配，1 筆北投區資料在 0/150/300 m 都落在 analysis universe 外。舊 candidate
metrics 只保留作 audit。

2026-08-18 revised SQL 15 live materialization 成功，四個 statements 與兩個
assertions 都通過。正式 internal-simulation metrics 使用 248 sites；247/248
sites 在 0/150/300 m 都可進入 analysis cells，1 site 在各 window 均未匹配。

| Cell-footprint window | Cells | Nonzero cells | Total cell matches | Max count | Invalid zero percentiles |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 m | 3,420 | 196 | 247 | 5 | 0 |
| 150 m | 3,420 | 556 | 971 | 8 | 0 |
| 300 m | 3,420 | 886 | 2,102 | 10 | 0 |

Site QA 同時確認：248 unique site keys、250 source-row total、2 個 duplicate
site keys、0 null representative geometries。這些只是 component/data-quality
evidence；composite 尚未 materialize。

## 4. 固定 transformation 與公式

```text
Food(c) = frozen v0.1 food score

SewerAttribute(c) = mean(
  system_type_percentile,
  surface_elevation_percentile,
  connected_pipe_diameter_percentile,
  connected_pipe_depth_percentile,
  connected_pipe_age_percentile
)

RenewalAdmin150(c) = percentile(
  count distinct administrative site keys within 150 m of eligible cell polygon
)

V03InternalSimulation(c) =
  (Food(c) + SewerAttribute(c) + RenewalAdmin150(c)) / 3
```

規則：

- 三組各 `1/3`，只是 preregistered assumption；每個 sewer metric 的 effective
  weight 是 `1/15`。
- Sewer 五項皆使用 BigQuery cell-weighted `PERCENT_RANK`：system type、surface
  elevation、pipe age 以 raw value ascending 排序；pipe diameter、pipe depth
  以 raw value descending 排序，使較低 raw value 得到較高 percentile，不做
  數值倒數。
- Renewal 先 count sites，再 `PERCENT_RANK`；count zero 明確指定為 percentile
  zero。zero 只表示目前 observed file scope 無 match，不是真實不存在。
- 任一 group 缺值，composite 為 `NULL`，不動態重分配權重。
- 只在 complete-case support 計算 `rank_within_scoreable_support`。
- 150 m 是 primary analysis window；0 m、300 m 是 sensitivity。空間規則固定
  為 WGS84 BigQuery `GEOGRAPHY` representative point 與 eligible cell polygon
  的 `ST_DWITHIN <= analysis_window_m`。
- Composite 永遠是 `BLOCKED_INTERNAL_SIMULATION`；不是 probability、risk、
  predicted activity、construction、disturbance 或 diffusion。

## 5. BigQuery artifacts

不覆寫 v0.1/v0.2 或 pre-review candidate metrics。新增：

1. `subterrat_curated.urban_renewal_admin_site_v0_3_internal_simulation`
2. `subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
3. `subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
4. `subterrat_predictions.hotspot_scenario_quality_v0_3_internal_simulation`
5. `subterrat_predictions.map_hotspot_cells_v0_3_internal_simulation`
6. `subterrat_predictions.hotspot_scenarios_v0_3_locked_internal_simulation`
7. `subterrat_predictions.hotspot_scenario_lock_manifest_v0_3`

SQL 16 在 composite materialization 前 fail-closed 驗證：clean committed Git
HEAD、`COMMITTED_SOURCE`、GPT Pro review receipt hash、contract hash、SQL hash、
source snapshot ID。未 commit 時不得 materialize composite。

2026-08-18 已將 SQL 16–18 的完整 CTE／joins／output schema 組成
`WHERE FALSE` read-only validation，並在 live BigQuery `asia-east1` 成功解析：

- SQL 16：`bquxjob_18c21f2c_1a0111f22d8`
- SQL 17：`bquxjob_7ef65564_1a01120c682`
- SQL 18：`bquxjob_39e77a6a_1a01124796f`

三個 jobs 均為 0 rows、0 B processed、0 B billed，destination 均為 temporary
table。這只證明 live schema compatibility；不等於 composite、quality 或 map
payload 已 materialize，也不開啟 SQL 19 lock gate。

2026-08-18 另以 `sql/analysis/24_preview_hotspot_composite_v0_3.sql` 執行
read-only temporary composite preview；job
`bquxjob_4f7e0a1c_1a011c80294` 的 12 statements 在 12 秒內成功。結果與完整
限制見 `docs/V0_3_COMPOSITE_PARTIAL_PREVIEW.md`。這仍不是永久 composite
materialization，也不改變 specification lock gate。

同日 `sql/analysis/25_preview_hotspot_composite_map_v0_3.sql` 在 final job
`bquxjob_24ad5cf9_1a011d71c37` 成功回傳完整 3,420-cell map payload：1,589 筆
complete-case composite、1,831 筆明確 missing support。BigQuery Visualization
與 React preview 均以固定 relative display scale 在 street basemap 上呈現；未評分
cells 不畫成零值。這只屬 read-only map preview。

## 6. 一次性 retrospective concordance

Lock 後才可執行，且永遠保留 889 筆作 citywide denominator。

Primary citywide map-as-delivered：

- `report_overlap_fraction`
- `report_overlap_to_area_ratio`
- `difference_in_report_overlap_vs_food_v0_1`
- `unscored_report_fraction`
- exact numerator、denominator、selected-area share、scoreable-area share

Secondary exact common support：把 v0.3 與 frozen food v0.1 都在 v0.3 exact
scoreable support 重新排名，以該 common support 的 10% eligible area 作同尺度
比較，並報 common-support denominator 與 outside-support fraction。

結果只能描述 location concordance，禁止 component attribution，也不得據此
改版。accuracy、specificity、AUC、probability 與 predictive validation 都不報。

## 7. React internal lab

`web/hotspot-lab/` 以 Leaflet 在 OpenStreetMap Standard raster tiles 上提供
兩種明確分離的 render mode：預設的 metric-weighted centroid heat surface
使用固定 34 px kernel，只作視覺平滑；cell-audit mode 顯示 authoritative
aggregate polygons、missingness 與 selected-area outline。Heat surface 不是
生物擴散、時間推演或新 model output。介面不顯示 precise admin-site
coordinates 或 Rat Radar rows。OSM attribution 必須常駐可見；只允許一般
human interactive viewport requests，不做 tile prefetch、bulk download 或
offline cache。Tile URL 與 attribution 可由環境變數一起替換。介面固定顯示：

- `Specification pending lock` 或 `Specification locked`
- `Internal simulation only`
- `Evidence untrusted`
- `Operational use prohibited`
- `rank_within_scoreable_support`
- `preregistered selected scenario area`

權重唯讀；不提供可保存 slider，也不把數值稱作 hotspot risk。

### 7.1 Network redistribution challenger（規格已核准、實作完成、尚未 materialize）

GPT Pro 最終 verdict 是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`，fatal flaws 為
`NONE`；receipt 見
`docs/V0_3_NETWORK_REDISTRIBUTION_GPT_PRO_APPROVAL.md`。核准只代表規格可受控實作，
不改變 `NO_TRUSTED_RESULT`，也不授權 retrospective validation、公開或操作用途。

實作固定稱 `DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION`：frozen food score
經 eligible-area weighting 成為 source seed；active pipe geometry 依 source vertex
order 拆 elementary edges，完整穿越 cell 才形成 coarse binary links；v0.2 complete-
case sewer attribute 只改 eligible link 內 neighbor share。都更行政 proxy 完全不進
transition。N0/N1/N2 分別是 uniform-link comparator、metric-weighted links 與 generic
shared-boundary adjacency sensitivity。

SQL 20–23 已建立 graph、row-stochastic transitions、0–8 abstract iterations、global
locked-run scale、quality registry與 deterministic receipt gate；API 新增：

```text
/api/v1/lab/v0.3/network-redistribution/cells
/api/v1/lab/v0.3/network-redistribution/links
```

React challenger 只用 discrete cell choropleth、manual iteration slider、fixed scale
與 support hatch overlay；schematic centroid links 預設隱藏，且不是 pipe alignment。
沒有 heat、interpolation、autoplay 或 calendar-time mapping。

2026-08-18 live BigQuery read-only fixtures 已證明：

- elementary-edge / local interval / HALF_EVEN primitives 可執行；
- A→B→C 只形成 A–B、B–C，正反向 canonical edge hash 相同；
- 3-cell recurrence iterations 0/1/2 的 mass 都精確為 1；
- `ST_COVEREDBY`、canonical WKB 與 byte separators 可用。

這些只是 fixture/runtime evidence。由於 parent v0.3 committed lock 與 finalized
selected-content manifest 尚未存在，永久 `subterrat_simulations` tables 仍未建立；
SQL 20–23 必須 fail closed。既有 889 reports 仍不得選 graph、weights、continuation、
iteration、scenario、scale 或 UI。

Network-based urban rodent simulations可作方法先例，但其 migration distance
與 spreading probability 不能搬成臺北參數：
[Applied Network Science](https://doi.org/10.1007/s41109-019-0212-6)。London
長期 sewer baiting 研究支持 persistent spatial heterogeneity，不提供臺北傳播
速度：[Epidemiology & Infection](https://doi.org/10.1017/S0950268805004607)。

## 8. 完成與停止條件

- Contract、SQL、exporter、API、React 與 renderer tests 全綠。
- BigQuery site/metrics component QA 可先執行；composite 必須等 commit identity。
- commit、push、PR 與公開/operational use 各自需要獨立人工授權。
- Rat Radar 只允許 lock 後一次性 concordance，且結果不回灌。
