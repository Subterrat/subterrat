# GPT Pro third closure review：v0.3 network redistribution challenger

你在第二輪對此 internal synthetic challenger 給出
`REVISE_BEFORE_IMPLEMENTATION`（HIGH confidence），並列出 F1–F7。這次只判斷
F1–F7 是否已被唯一、可重現地關閉；禁止用 Rat Radar、visual plausibility 或
任何 outcome 選 graph、parameters、scenario、iteration 或 display scale。

## 第二輪缺口的逐項修訂

- F1：不再以 whole-linestring midpoint + `ST_LINELOCATEPOINT` 排 traversal；依來源
  頂點順序用 `ST_POINTN` 建 elementary edges，在每個 edge 的 local interval 排序。
- F2：保存 fragment start/end local fractions，量化 15 decimals；固定 gap/overlap
  tolerance、whole-segment in-universe coverage、boundary overlap/nonunique fail-closed。
- F3：sewer traversal、generic adjacency、area 與 map rendering 全部固定使用同一張
  frozen `analysis_cells.eligible_geom`；generic adjacency 排除 self、要求正長度 shared
  boundary，且明示 barriers 未建模。
- F4：全計算固定 `BIGNUMERIC`、`ROUND_HALF_EVEN`、每欄位 scale、quantization
  order、stored transition/state、display scale、decimal serialization 與 canonical
  SHA256 row serialization。
- F5：移除無法由現有資料唯一辨認的 internal component metrics，改成固定
  `NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL`；其餘 QA 按三個 graph scope
  明確列出。
- F6：新增 cell/link routes、完整 row schemas、support enum/precedence、scenario link
  scope，以及 fixed-scale fill 上 overlay hatch；exact pipe geometry 不進 API/UI。
- F7：新增 immutable input manifest，固定 exact table、fields、predicates、row
  identities、snapshot IDs、parent lock、forbidden sources，並把 manifest SHA256 納入
  challenger contract 與 materialization receipt。

## 請審查的三個完整檔案

- `docs/V0_3_PROPAGATION_CHALLENGER_PLAN.md`
- `contracts/propagation_challenger_v0_3_candidate.json`
- `contracts/network_redistribution_input_manifest_v0_3_candidate.json`

## 固定輸出格式

1. `VERDICT`：只能是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`、
   `REVISE_BEFORE_IMPLEMENTATION` 或 `REJECT_CHALLENGER`。
2. `UNCLOSED_FATAL_FLAWS`：若無，明確寫 `NONE`。
3. `F1_F7_CLOSURE_TABLE`：逐項寫 `CLOSED` 或 `OPEN`，並附一句可驗證理由。
4. `IMPLEMENTATION_GATES`：只列獲准後仍須由 unit fixture、BigQuery dry-run、
   API/React tests 或 materialization receipt 證明的事項；不要把它們誤列為規格 fatal。
5. `SEMANTIC_BOUNDARY_CHECK`：確認它只稱 synthetic redistribution，不是 probability、
   risk、forecast、sewer flow、rat movement、field validation 或 operational output。

若兩位工程師依這三個檔案仍可能合理產生不同 edge set、transition matrix、stored
states、content hashes、API payload 或 React support rendering，請指出最小剩餘規格
缺口。若只剩實作測試才能證明的問題，verdict 應為
`APPROVE_FOR_INTERNAL_IMPLEMENTATION`，並列入 `IMPLEMENTATION_GATES`。
