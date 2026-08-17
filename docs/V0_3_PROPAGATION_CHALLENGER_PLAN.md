# v0.3 network redistribution challenger

歷史工作名稱：`v0.3 propagation challenger`

狀態：`APPROVED_FOR_INTERNAL_IMPLEMENTATION_NO_TRUSTED_RESULT`

## 1. GPT Pro verdict 與目前定位

第一輪完整審查 verdict 是 `REVISE_BEFORE_IMPLEMENTATION`（HIGH confidence），
原文保存於 `docs/V0_3_PROPAGATION_GPT_PRO_REVIEW.md`。第二輪 closure review 仍是
`REVISE_BEFORE_IMPLEMENTATION`（HIGH confidence），原文保存於
`docs/V0_3_NETWORK_REDISTRIBUTION_SECOND_GPT_PRO_REVIEW.md`。審查認為 S2 L15 cell、
fixed seed、row-stochastic transition 可作 internal 方法壓力測試，但原規格的
endpoint shortcut、P1 renewal 方向、missing-support self allocation、逐 frame
max normalization、heat/autoplay 與 naming 都必須修正。

第三輪 closure review 仍為 `REVISE_BEFORE_IMPLEMENTATION`（HIGH confidence），
原文保存於 `docs/V0_3_NETWORK_REDISTRIBUTION_THIRD_GPT_PRO_REVIEW.md`。它確認
F1–F3、F5 與 semantic boundary 已關閉；本版只再收斂 F4 canonical arithmetic/hash、
F6 API wire format 與 F7 unique input selection/content identity。

第四輪 final review 仍為 `REVISE_BEFORE_IMPLEMENTATION`，原文保存於
`docs/V0_3_NETWORK_REDISTRIBUTION_FINAL_GPT_PRO_REVIEW.md`。本版不改 recurrence
或情境，只再固定 quality row registry、pipe census、run-ID byte order、limitation
assignment 與 canonical wire values。

第五輪 last closure 只剩兩個 canonical bytes 缺口，原文保存於
`docs/V0_3_NETWORK_REDISTRIBUTION_LAST_GPT_PRO_REVIEW.md`。本版已從 transition
與 quality artifacts 移除不必要且未被使用的 limitation arrays，並為每一個 quality
metric 固定 `value_formula`、canonical input fields 與 integer/rounding rule。

Two-field closure 最終 verdict 為 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`，且
`UNCLOSED_FATAL_FLAWS = NONE`；完整 receipt 保存於
`docs/V0_3_NETWORK_REDISTRIBUTION_GPT_PRO_APPROVAL.md`。這只授權受控 SQL/API/React
實作與測試，不改變 `NO_TRUSTED_RESULT`，也不授權 retrospective validation、公開
發布或 operational use。

修訂後模型只稱：

```text
DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION
```

它不取代或改寫 v0.3 equal-group ranking。它只回答：

> Frozen food score 經 area weighting 成為 synthetic seed 後，在一張由官方
> active pipe geometry 聚合出的 coarse cell-link graph 上，固定 transition
> assumptions 會形成什麼 `relative_synthetic_network_state`？

它不是鼠患 probability、risk、rat density、sewer flow、migration、calendar-time
forecast、construction effect、現場驗證或行動建議。固定狀態：

- `use_state = INTERNAL_SIMULATION_ONLY`
- `evidence_state = NO_TRUSTED_RESULT`
- `operational_use = PROHIBITED`

既有 889 筆 Rat Radar rows 不得選 graph、weights、alpha、iteration、scenario、
scale 或 UI；只能在未來完整 lock 後作一次性位置 concordance。

## 2. Outcome-free live graph QA

2026-08-18 live BigQuery profile：

- 192,533 active pipe segments；1,512/1,509 缺 start/end node ID；
- raw node ID graph 有 4,239 coordinate-conflict nodes、493 span >5 m，最大
  約 17,009 m；resource-scoped ID 仍有 3,641 conflicts、437 span >5 m；
- geometry exact-7dp endpoint graph 有 201,212 nodes，degree-1/2/3+ 為
  70,959/92,391/37,862；
- endpoint-only profile 初見 180,359 within-cell、12,174 cross-cell segments、
  2,685 unordered cross-cell pairs，但 GPT Pro 指出 endpoint pair 可能跳過中間
  cell，因此這些只保留作問題發現，不能直接成為 graph artifact。

Profile job：
`asia-east1.script_job_2a63769d85e4be2cda142c0406884dbb_2`；temporary
destination。Raw node IDs 只作 QA，不作 graph identity。

## 3. Source-ordered elementary-edge traversal graph

State universe 是 frozen 3,420 個 S2 L15 analysis cells。所有 graph geometry role
都固定使用
`devjam26aug17tpe-1270.subterrat_curated.analysis_cells.eligible_geom`。每個 active、
valid、non-empty、in-scope `ST_LineString` 依 source vertex order 處理：

1. `edge_ordinal = 1..ST_NUMPOINTS(segment)-1`，以
   `ST_MAKELINE(ST_POINTN(segment, edge_ordinal),
   ST_POINTN(segment, edge_ordinal + 1))` 建立 elementary edge；collapsed edge
   使整條 source segment 排除並計數。
2. elementary edge 與每個 frozen cell 求 intersection，只保留正長度 line
   fragments；point/corner-only contact 因長度為 0 排除。
3. 在 elementary edge 上分別定位 fragment start/end，得到 local interval low/high；
   兩端以 `BIGNUMERIC`、15 decimals、`ROUND_HALF_EVEN` 量化。
4. 排序鍵固定為 `(source_snapshot_id, source_resource_id, segment_id,
   edge_ordinal, quantized_interval_low, quantized_interval_high, cell_id)`；不同
   cells 有超過 `1e-12` 的 positive
   interval overlap、或 traversal 無法唯一決定時，整條 source segment 排除。
5. source segment 必須被 frozen `eligible_geom` union 完整涵蓋；coverage gap 超過
   `1e-12` fraction 或離開 universe 時整條排除。Boundary overlap 不任意指派 cell。
6. 對 admissible traversal 移除 consecutive duplicate cells，只連結相鄰 cells；
   pair 轉成 unordered `(LEAST(cell_id), GREATEST(cell_id))` 並去除 self pair。

Implementation fixture 必須包含跨越三個以上 cells、repeated vertex、self-overlap、
retracing、shared-boundary、out-of-universe gap 與 reversed source orientation；正反向
只允許 traversal order 反轉，最終 unordered binary link set 必須完全相同。

只允許 active、valid、non-empty、in-scope `ST_LineString`。MultiLineString、empty、
invalid、ambiguous traversal 與 out-of-scope geometry 都要固定 exclusion code。

每個 unordered pair 是一個 binary sewer link。Parallel segment count、distinct
pipe count、total intersected length、resource count 只作 QA，不進 weight。Exact
geometry 留在 BigQuery construction layer，不進 API/UI。

同 cell 內管段只留 QA，不影響固定 self bucket。現有 source 沒有足以唯一重建
junction 的資料，所以不計算內部 geometry component 指標，必須明示：
`internal_cell_connectivity_state =
NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL`。Cell collapse 可能把同 cell
內實際不連通的 subnetworks 混合，保留為 limitation，不能包裝成已量測 QA。

Cell links 採 symmetric abstract links，因 hydraulic flow 與 rat movement direction
都未驗證；這不是 actual sewer flow，也不稱 conservative。

## 4. Metric roles 與 seed

角色互斥：

1. Frozen `food_market_v0_1`：synthetic source seed。
2. `sewer_attribute_index_v0_2`：synthetic sewer route weight；四項 gate 未通過
   的限制必須跟 edge、state、API 與 UI。
3. `approved_rebuilding_admin_site_r150`：不進 network transition；它仍只存在
   v0.3 administrative-context ranking，沒有可靠施工起訖或 effect direction。

```text
food_score_12(c)    = ROUND(CAST(food_score AS BIGNUMERIC), 12, HALF_EVEN)
eligible_area_m2_6  = ROUND(CAST(eligible_area_m2 AS BIGNUMERIC), 6, HALF_EVEN)
stored_raw_seed(c)  = ROUND(food_score_12 * eligible_area_m2_6, 18, HALF_EVEN)
raw_seed_total      = SUM(stored_raw_seed)
stored_seed(c)      = ROUND(stored_raw_seed / raw_seed_total, 24, HALF_EVEN)
state[0,c]          = stored_seed(c)
```

Frozen food layer 必須 3,420 cells 全部 finite/non-null，否則 fail materialization；
不得把 missing 當 low-food 或真實零值。

## 5. 唯一決定的 transition matrix

`P[from_cell,to_cell]` 必須 nonnegative、finite、row-stochastic。

對 attribute-eligible binary sewer link：

```text
w(c,d)  = 0.25 + 0.75 * mean(SewerAttribute(c), SewerAttribute(d))
qs(c,d) = w(c,d) / sum_{j in Ns(c)} w(c,j)
```

兩端 sewer attribute 皆 non-null 才進 `Ns(c)`。Topology comparator 使用完全相同
eligible link support，但 `qs(c,d)=1/|Ns(c)|`，只拆分 topology 與 metric weighting。

Generic adjacency `Na(c)` 僅以 frozen `analysis_cells.eligible_geom` 建構，明確
要求 `from_cell_id != to_cell_id`、共享正長度 boundary，並以 unordered pair
deduplicate；corner-only contact 不算，`qa(c,d)=1/|Na(c)|`。它只作 sensitivity，
不表示地表可通行性，也沒有建模道路、河川或建物 barrier。

對 `d != c`：

```text
P(c,d) = sewer_bucket(c) * qs(c,d)
       + adjacency_bucket(c) * qa(c,d)
```

同一 neighbor 同時屬兩種 class 時，先計算未量化的兩個 class allocations、依
`(from,to)` 相加，再只對 combined non-self row 做一次 24-decimal HALF_EVEN；不可
先各自 round 再相加。Self：

```text
P(c,c) = self_bucket(c)
       + sewer_bucket(c)    * I[Ns(c) is empty]
       + adjacency_bucket(c)* I[Na(c) is empty]
```

Unused sewer mass 不得流到 adjacency，反之亦然。`self=1` 的 cells 必須標成
`self_only_transition_row`，不是 high-retention cell，並報其 source mass。

## 6. Fixed scenarios 與 recurrence

三個 scenarios 全部同時保留，不依 outcome 選 winner：

| Scenario | Self | Sewer | Generic adjacency | Sewer distribution |
| --- | ---: | ---: | ---: | --- |
| `n0_uniform_sewer_link_comparator` | 0.65 | 0.35 | 0 | uniform |
| `n1_metric_weighted_sewer_links` | 0.65 | 0.35 | 0 | attribute-weighted |
| `n2_generic_cell_adjacency_sensitivity` | 0.55 | 0.35 | 0.10 | attribute-weighted |

沒有 renewal transition scenario。參數只是 fixed synthetic assumptions：0.25/0.75
route-weight range 意味最大 4:1 raw ratio；row normalization 後只改 neighbor share。

```text
transition_continuation_alpha = 0.75
source_reinjection_weight     = 0.25

stored_source_term[to]
  = ROUND(BIGNUMERIC '0.25' * stored_seed[to], 30, HALF_EVEN)
stored_product[from,to]
  = ROUND(BIGNUMERIC '0.75' * stored_state[t,from] * stored_P[from,to], 30, HALF_EVEN)
stored_state[t+1,to]
  = ROUND(stored_source_term[to] + SUM(stored_product[from,to]), 24, HALF_EVEN)

t = 0..8 abstract iterations
```

Iteration 不是時間或單次實際移動；iteration 8 不是 final、forecast、equilibrium
或 convergence。每一 iteration 都輸出，不選看起來最好的一步。

Numerical contract 全程採 `BIGNUMERIC` 與 `ROUND_HALF_EVEN`。來源 FLOAT64 先依
欄位量化（food 12、area 6、sewer attribute 12）；raw seed 18、source seed 24、
route weight 12、combined transition 24、recurrence product/source term 30、stored state 24、global
scale 24、API display 12 decimals。Non-self transition 先固定到 24 decimals，self
固定為 `1 - stored nonself row sum`；每個 recurrence product 先固定到 30 decimals
再加總，stored state 固定到 24 decimals。Seed denominator 只使用 stored raw seeds；
same-neighbor class allocations 只在合併後 round 一次。Row sum tolerance `1e-12`、state mass
`1e-9`、per-cell recurrence residual `1e-24`。Hash 依 table primary keys 排序、
schema field order、固定 separators/null encoding/fixed-scale decimal ASCII；negative
zero 序列化為 positive zero。

## 7. Fixed-scale output

完整 locked run 完成後才計算：

```text
display_scale_max = max(unit_mass_state)
  over all locked cells, scenarios, and abstract iterations

relative_synthetic_network_state = unit_mass_state / display_scale_max
normalization_scope = LOCKED_RUN_GLOBAL_ALL_SCENARIOS_AND_ITERATIONS
```

一般 map API 不回 raw unit mass；restricted QA 才可讀。Display scale 只從 stored
canonical 24-decimal states 計算；API 再輸出 fixed 12-decimal string。相同色階因此
可跨 scenario 與 iteration 比較，不使用 frame-specific normalization。

## 8. BigQuery artifacts（final closure 通過後才實作）

不使用 `predictions` dataset／namespace：

1. `subterrat_features.synthetic_network_cell_links_v0_3_candidate`
2. `subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
3. `subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
4. `subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
5. `subterrat_simulations.map_synthetic_network_cells_v0_3_internal_simulation`
6. `subterrat_simulations.schematic_cell_links_v0_3_internal_simulation`

Schematic links 是 static binary aggregated cell links，預設隱藏；不稱 corridor，
也不假裝是 step-specific transfer。Initial implementation 不輸出 exact geometry。

Input manifest template 是
`contracts/network_redistribution_input_manifest_v0_3_candidate.json`，candidate SHA256
為 `1ef85ce04860d36f2104b68674281b9c71cf85506336d9f0bec70dca0b7d6a7b`；它固定
cell、food、pipe、sewer attribute、parent v0.3 lock 的 table/field/predicate/identity、
unique-row assertions 與逐 source canonical content-hash projection。任何 run 前都必須
複製成 finalized manifest，填滿每個 `selected_content_sha256`；pending、selector
row-count/uniqueness mismatch 或 source mutation 一律 fail materialization。Finalized
manifest hash 與 selected content hashes 都納入 deterministic run ID 與 receipt。
Pipe identity 涵蓋完整 198,091-row source census；traversal predicate 另行套用，所有
census rows 依固定 precedence 恰好得到一個 terminal classification。Cell/food 也
要求 unique cell identity 且兩者 cell-ID set 完全相同。

Exact output table schema、PK、field order、decimal/array/GeoJSON encoding 與逐表 hash
規則固定於 `contracts/network_redistribution_artifacts_v0_3_candidate.json`；candidate
SHA256 是 `72e7fe0248d2540cb292923af10221f2d9e34ad9da0c1ccfc21cda694d0d3a65`。
同一份 contract 另固定 quality metric registry、row cardinality、component ID（component
內最小 signed cell ID）、dimension key、terminal exclusion precedence 與 run-ID 的九個
ordered input fields。Transition artifact 只存 canonical combined transition，不再存
可能引入 rounding residual 歧義的 class diagnostic allocations。

Materialization fail closed：clean committed Git head、GPT Pro review receipt、contract
hash、finalized input manifest hash、artifact/API schema hash、SQL hash、v0.3 parent lock、
pipe/food/grid/sewer selected content hashes 全吻合；
referenced tables 不得含 Rat Radar/derived outcome。Receipt 固定保存 contract、input
manifest、SQL、code revision 與每張 output table content hash。Required QA 涵蓋
row sums、mass、recurrence、三個明確 graph scopes 的 link/每-cell degree/component/
source-mass、isolates/self-only source mass、endpoint-missingness exclusions、n0/n1
identical edge-set hash 與九類 source census terminal counts；內部 cell connectivity 固定為
`NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL`。

## 9. API 與 React

API routes：

```text
/api/v1/lab/v0.3/network-redistribution/cells
/api/v1/lab/v0.3/network-redistribution/links
```

Normative JSON Schema 是 `contracts/network_redistribution_api_v0_3.schema.json`
（candidate SHA256
`9fe6cd67915b10bc6579eccfd9fbe9a9dd2cd844d8963326f8dacf01614a7bae`）。只接受
locked scenario enum 與 integer iteration 0–8；不接受 alpha、bucket、weight 或
iteration count。Cell response 固定包含 contract/finalized input manifest/run ID、
scenario、abstract iteration、global normalization metadata、governance states、global
limitation codes，以及 signed-INT64 string `cell_id`、canonical GeoJSON text string、
fixed-12-decimal display state、
sewer attribute availability、sewer/generic neighbor counts、scenario-specific self-only、
support enum 與 cell limitation codes。`display_scale_max` 是 fixed-24-decimal string；
所有 limitation-code arrays 都由 schema enum 限制、lexicographic sort 並去重。Cell
rows 依 signed INT64 cell ID 排序。Support enum/precedence 由 contract 固定。
Normative wire rules 另固定 no leading/negative zero、strictly-positive display scale、
每 scenario/global、support-condition/cell 與 link-class 的 exact limitation-code sets。

Link route 只回 selected scenario 實際 active 的 cell links：n0/n1 僅 metric-eligible
synthetic sewer links，n2 另含 generic adjacency。每列固定包含 from/to cell、class、
metric eligibility、兩端 fixed-7-decimal string centroid object 與 limitation codes；
不回 exact pipe geometry。Sewer row 的 `metric_eligible=true`；generic row 固定 null。
同一 pair 同屬兩 class 時以兩列表示，key 包含 `link_class`。
Link 永遠沿 canonical unordered orientation 輸出：signed `from_cell_id < to_cell_id`，
serializer 不得重新定向。

React 增加 `Network redistribution challenger` mode：

- discrete cell choropleth；禁止 heat kernel、interpolation 與 missing-cell smoothing；
- autoplay=false，第一版不提供 playback，只手動 abstract iteration slider；
- missing/unsupported cells 在固定色階 state fill 上 overlay hatch，不把值改成 null、
  low color 或另一套 scale；
- schematic centroid links 預設隱藏並永久標示不是 pipe alignment；
- persistent banner：internal synthetic redistribution、no time mapping、not a
  calibrated rat-presence probability、not sewer-flow/movement map、
  NO_TRUSTED_RESULT、operational use prohibited。

UI 禁止 hotspot、spread rate、movement、risk、predicted、likely rats、active
construction、recommended inspection、final iteration 與 convergence implies truth。

## 10. Implementation approval

GPT Pro 已核准進入 internal implementation。仍須由 unit fixtures、BigQuery
read-only dry-run／schema probes、canonical wire tests、React tests 與 deterministic
receipt gates 證明；在 committed parent v0.3 lock 與 finalized input manifest 完成前，
永久 materialization 仍必須 fail closed。

## 11. 方法來源

Network-based urban rodent simulation只支持 graph structure 與假設會改變 simulation
結果，不支持本 recurrence 或臺北參數：
[Applied Network Science](https://doi.org/10.1007/s41109-019-0212-6)。

London sewer study只支持 sewer activity 空間異質性，不提供 cell transfer rate：
[Epidemiology & Infection](https://doi.org/10.1017/S0950268805004607)。

Seattle study只支持 sewer attributes 的 eligibility/direction，不支持 synthetic
route-weight effect size：
[Urban Ecosystems](https://doi.org/10.1007/s11252-022-01255-2)。
