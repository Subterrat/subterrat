# GPT Pro review request：SubTerrat v0.3 propagation challenger

你是本研究的獨立方法審查者。請採 evidence-skeptical、fail-closed 立場，審查
`docs/V0_3_PROPAGATION_CHALLENGER_PLAN.md` 與
`contracts/propagation_challenger_v0_3_candidate.json`。

## 不可更改的治理邊界

- 這不是鼠患 probability、risk prediction、鼠群密度或現場 Ground Truth。
- 這不是 calendar-time forecast；step 0–8 只能是 abstract steps。
- Rat Radar 889 reports 不得用於任何 parameter、scenario、graph 或 step 選擇。
- 都更資料沒有可靠施工起訖，只能作 administrative context sensitivity。
- v0.2 sewer metrics 有四項 gate 尚未通過，必須持續顯示限制。
- exact sewer geometry、admin sites 與 report rows 不進前端。
- 輸出維持 internal simulation、NO_TRUSTED_RESULT、operational use prohibited。

## 實際 live QA

- 192,533 active segments；1,512/1,509 缺 start/end node ID。
- Raw node IDs：4,239 coordinate conflicts；493 span >5 m；max ~17 km。
- Resource-scoped IDs：3,641 conflicts；437 span >5 m；max ~17 km。
- Exact-7dp geometry endpoints：201,212 nodes；degree-1/2/3+ =
  70,959/92,391/37,862。
- Pipe segments：180,359 within-cell；12,174 cross-cell；2,685 distinct
  undirected cross-cell pairs。
- 因此 proposal 使用 S2 L15 cell states 與 geometry-derived cross-cell routes，
  不使用 raw node ID topology。

## Proposed recurrence

```text
x[0]   = normalized(food_score * eligible_area_m2)
x[t+1] = 0.25 * x[0] + 0.75 * transpose(P) * x[t]
```

`P` row-stochastic；每個 scenario／step synthetic unit mass 必須 sum to 1。
Primary P0：self=0.65、metric-weighted sewer=0.35、surface=0。
P1：renewal 只調 self-retention 的 sensitivity。
P2：self=0.55、sewer=0.35、touching-cell surface=0.10 sensitivity。

## 請輸出固定格式

1. `VERDICT`：只能是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`、
   `REVISE_BEFORE_IMPLEMENTATION` 或 `REJECT_CHALLENGER`。
2. `FATAL_FLAWS`：會阻止任何 implementation 的項目。
3. `REQUIRED_REVISIONS`：逐條、可直接修改規格的要求。
4. `PARAMETER_REVIEW`：逐一審查 conductance、alpha、buckets、steps。
5. `GRAPH_AND_MASS_REVIEW`：identity、direction、missingness、row sums、mass。
6. `NAMING_AND_UI_REVIEW`：是否仍暗示 probability／真實擴散／時間。
7. `MINIMUM_IMPLEMENTATION_GATES`：SQL／API／React 上線前 hard gates。
8. `ALLOWED_CLAIMS` 與 `FORBIDDEN_CLAIMS`。

請勿替本研究挑出「看起來最像 Rat Radar」的參數，也不要建議以既有通報做
任何 calibration 或 visual similarity selection。
