# GPT Pro two-field closure：v0.3 network redistribution challenger

上一輪只留下兩個 canonical artifact bytes 缺口。這次只檢查這兩項，不得新增審查
範圍，也不得重開已 CLOSED 的其他七項或 semantic boundary。

## 唯二修訂

1. Transition artifact 已直接移除 `transition_limitation_codes`；它現在只保存 run、
   scenario、from/to、canonical combined `transition_value`、self flags，不再有任何
   未指派的 array bytes。
2. Quality artifact 已移除 `limitation_codes`；normative registry 的每一筆 metric
   現在都明列 `value_formula`、`canonical_input_fields`、
   `rounding_or_integer_rule`。原本有歧義的 parallel metric 已改為
   `parallel_source_segment_duplicate_excess_total =
   SUM(GREATEST(parallel_segment_count - 1, 0))`；component share、component source
   mass、self-only source mass、missing-metric link count等也都有精確公式。

請審查完整 artifact schema與引用它的 challenger contract／plan。

固定輸出：

1. `VERDICT`：只能是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`、
   `REVISE_BEFORE_IMPLEMENTATION` 或 `REJECT_CHALLENGER`。
2. `UNCLOSED_FATAL_FLAWS`：無則寫 `NONE`。
3. `TWO_FIELD_CLOSURE`：逐項 CLOSED/OPEN。
4. `IMPLEMENTATION_GATES`：只列 runtime/test evidence。
5. `SEMANTIC_BOUNDARY_CHECK`。

若這兩項已關閉，依上一輪結論直接判定 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`。
