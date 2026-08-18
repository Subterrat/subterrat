# GPT Pro last closure：v0.3 network redistribution challenger

你在前一輪仍判定 `REVISE_BEFORE_IMPLEMENTATION`。這次只檢查你列出的七個
bytes-level 缺口是否關閉；禁止擴張模型、重新討論已 CLOSED 的 F1–F3/F5，亦禁止
使用 Rat Radar、visual plausibility 或 outcome。

## 前一輪缺口的直接修訂

1. Transition artifact：移除 `sewer_allocation` 與
   `generic_adjacency_allocation` diagnostic columns，只保存唯一的 combined
   `transition_value`，不再有 residual 歸屬問題。
2. Quality artifact：artifact contract 新增 normative quality registry，固定每個
   metric 的 scope/scenario/iteration/dimension/value/cardinality；component ID 是
   component 內最小 signed cell ID；所有 scopes 使用完整 3,420-cell universe，
   isolates 是 single-vertex components；quality record ID 與九類 terminal exclusion
   precedence 固定。
3. Run ID：不再使用 JSON section order；明列九個 ordered fields 與 UTF-8/U+001F
   byte formula。
4. Limitation assignment：normative wire rules 固定每 scenario exact global set、
   cell additive condition mapping 與每 link class exact set；no other codes。
5. Canonical wire：cell ID regex禁止 leading/negative zero；display scale regex要求
   strictly positive；normative application validator固定 decimal negative-zero、signed
   numeric ordering、link `from < to` orientation且 serializer不得重導向。
6. Cell/food input：各自 one-row-per-version/freeze+cell fail-closed；food cell-ID set
   必須與 universe 完全相等。
7. Pipe/parent input：pipe selected-content hash改涵蓋完整 198,091-row census，null-safe
   geometry identity；traversal predicate另行套用，census每列恰好一種 terminal class。
   Parent manifest不再宣稱讀取實際 lock table不存在的 `specification_state`；正式
   `lock_status` 與全部治理欄位仍由 exact selector與content hash固定。

## 檔案

- `docs/V0_3_PROPAGATION_CHALLENGER_PLAN.md`
- `contracts/propagation_challenger_v0_3_candidate.json`
- `contracts/network_redistribution_input_manifest_v0_3_candidate.json`
- `contracts/network_redistribution_artifacts_v0_3_candidate.json`
- `contracts/network_redistribution_api_v0_3.schema.json`

## 固定輸出

1. `VERDICT`：只能是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`、
   `REVISE_BEFORE_IMPLEMENTATION` 或 `REJECT_CHALLENGER`。
2. `UNCLOSED_FATAL_FLAWS`：若無必須寫 `NONE`。
3. `SEVEN_ITEM_CLOSURE_TABLE`：逐項 CLOSED/OPEN。
4. `IMPLEMENTATION_GATES`：只列 unit fixture、BigQuery dry-run、finalized manifest、
   canonical wire validator、React tests 或 receipt 要證明的事項。
5. `SEMANTIC_BOUNDARY_CHECK`。

若現在只剩 tests/runtime 才能證明的事項，依前幾輪共同門檻，請判定
`APPROVE_FOR_INTERNAL_IMPLEMENTATION`。
