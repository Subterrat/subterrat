# GPT Pro second review：v0.3 network redistribution challenger

你先前對這個 proposal 給出 `REVISE_BEFORE_IMPLEMENTATION`（HIGH confidence）。
本次只審查 required revisions 是否已被完整、可唯一實作地關閉；不要重新使用
Rat Radar、visual plausibility 或 outcome 選參數。

## 已採用的主要修訂

- User-facing/model/API semantics 已從 propagation 改為
  `DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION`。
- Graph 不再使用 raw node ID 或 segment endpoint-cell shortcut；改用完整
  LineString 與 cell 正長度 intersection fragments，依 `ST_LINELOCATEPOINT`
  排序 traversal sequence，只連續相鄰 cells。
- Cell pair 是 binary link；parallel counts/length/resources 只作 QA。
- Transition allocation、same-neighbor class addition、unused bucket self return、
  matrix orientation 與 tolerances 已唯一固定。
- Renewal transition P1 已移除；都更只留 v0.3 administrative-context ranking。
- 新增同 edge support 的 uniform-link topology comparator。
- Surface 已改名 generic shared-edge cell adjacency sensitivity；corner touch 排除。
- `restart_alpha` 已更名 transition continuation；source reinjection 分開。
- Missing food 直接 fail materialization；missing sewer/self-only rows 明確 QA。
- Frame-specific normalization 已改成 locked-run global scale。
- Dataset 改為 `subterrat_simulations`；API 不使用 prediction/risk/forecast namespace。
- React 改用 discrete choropleth；無 heat/interpolation，autoplay/playback 關閉，
  schematic links default hidden。

## 請審查的兩個檔案

- `docs/V0_3_PROPAGATION_CHALLENGER_PLAN.md`
- `contracts/propagation_challenger_v0_3_candidate.json`

## 固定輸出格式

1. `VERDICT`：只能是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`、
   `REVISE_BEFORE_IMPLEMENTATION` 或 `REJECT_CHALLENGER`。
2. `UNCLOSED_FATAL_FLAWS`：若無，明確寫 `NONE`。
3. `REQUIRED_REVISIONS`：只列仍會阻止 SQL/API/React implementation 的項目。
4. `BIGQUERY_TRAVERSAL_REVIEW`：檢查 fragment ordering、ambiguous tie、boundary、
   sequence adjacency、binary pair 與 determinism。
5. `TRANSITION_AND_SCALE_REVIEW`：檢查 row sums、support、self-only、recurrence、
   tolerances、same-support comparator 與 global scale。
6. `API_UI_REVIEW`：檢查 naming、fields、choropleth、missingness、iteration 與 links。
7. `IMPLEMENTATION_GATES`：列出獲准後仍須由 tests/live dry-run 證明的 gates。

不要把缺乏 field calibration 本身當成 internal synthetic simulation 的否決理由；
但任何仍可讓兩個工程師產生不同 artifact 的規格缺口都必須列為 fatal。
