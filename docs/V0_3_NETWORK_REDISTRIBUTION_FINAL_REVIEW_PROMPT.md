# GPT Pro final closure review：v0.3 network redistribution challenger

你在第三輪給出 `REVISE_BEFORE_IMPLEMENTATION`（HIGH confidence），並確認 F1–F3、
F5 與 semantic boundary 已關閉。這次只審查第三輪仍 open 的 F4、F6、F7；不得
重新使用 Rat Radar、visual plausibility 或 outcome 選 graph、parameter、scenario、
iteration 或 display scale。

## 第三輪 open items 的最小修訂

### F4 canonical arithmetic / table hash

- Seed 固定先產生 `food_score_12`、`eligible_area_m2_6`、`stored_raw_seed_18`；
  denominator 只 SUM stored raw seeds；stored source seed 再 round 24。
- Same `(from,to)` 的 sewer/generic allocations 先以未量化值相加，再只 round
  combined non-self transition 一次到 24；self 是 1 減 stored non-self sum。
- Source reinjection 固定 round 30，recurrence products 固定 round 30，兩者加總後
  stored state round 24。
- 新增 normative artifact schema contract，逐表固定完整 fields order、PK、type、
  scale/null/array rules、run metadata、hash serialization；不 hash/serve GEOGRAPHY，
  map 只 hash canonical GeoJSON text。新增 transition artifact table。

### F6 API wire format

- 新增 JSON Schema 2020-12 normative contract與可執行 schema validation。
- Cell ID 使用 signed INT64 decimal string；GeoJSON 是 canonical text string；
  relative state fixed-12 string、display scale fixed-24 string。
- Centroid 是 longitude/latitude fixed-7 string object；limitation codes 都有 enum、
  unique、lexicographic canonical order。
- Sewer row `metric_eligible=true`；generic row固定 null；dual-class pair 以兩列、
  key 含 link class。Cell/link envelopes 與 metadata scope 分開固定。

### F7 unique input selection / content identity

- Sewer attribute新增 exact snapshot + five-variant predicate、exact row count與
  one-row-per `(snapshot,variant,cell)` fail-closed assertion。
- Parent lock新增 exact lock ID/status/governance predicate、expected one row與
  zero/multiple fail-closed action。
- 每個 input section新增 ordered fields與 derived canonical content-hash projection。
- Candidate manifest 是 template；任何 run 前必須複製為 finalized manifest、填滿
  所有 selected-content SHA256、重驗 selectors/uniqueness與 source content。Pending 或
  mismatch 一律 fail；finalized manifest hash和 selected hashes都進 deterministic run
  ID與 receipt。這次審查只請核准 implementation；實際值必須在 parent v0.3 lock完成
  後的 pre-materialization gate 填入，不能在 candidate 階段假造。

## 請審查的完整檔案

- `docs/V0_3_PROPAGATION_CHALLENGER_PLAN.md`
- `contracts/propagation_challenger_v0_3_candidate.json`
- `contracts/network_redistribution_input_manifest_v0_3_candidate.json`
- `contracts/network_redistribution_artifacts_v0_3_candidate.json`
- `contracts/network_redistribution_api_v0_3.schema.json`

## 固定輸出格式

1. `VERDICT`：只能是 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`、
   `REVISE_BEFORE_IMPLEMENTATION` 或 `REJECT_CHALLENGER`。
2. `UNCLOSED_FATAL_FLAWS`：若無，明確寫 `NONE`。
3. `F4_F6_F7_CLOSURE_TABLE`：逐項 `CLOSED`/`OPEN` 並附一句理由。
4. `IMPLEMENTATION_GATES`：只列必須由 unit fixtures、BigQuery dry-run、finalized
   input manifest、API/React tests 或 receipt 證明的項目。
5. `SEMANTIC_BOUNDARY_CHECK`：確認只稱 synthetic redistribution，仍為
   `INTERNAL_SIMULATION_ONLY / NO_TRUSTED_RESULT / OPERATIONAL_USE_PROHIBITED`。

若剩餘事項已被明確設成 fail-closed implementation gate、而不是讓兩位工程師能
合理產生不同規格，verdict 應為 `APPROVE_FOR_INTERNAL_IMPLEMENTATION`。若仍 OPEN，
只指出最小、可直接加入現有五份文件的缺口。
