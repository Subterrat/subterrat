# GPT Pro third closure review receipt — v0.3 network redistribution challenger

- Conversation: https://chatgpt.com/c/6a834dff-6408-83e8-8bb6-8d30dd199a47
- Model surface: Pro
- Verdict: `REVISE_BEFORE_IMPLEMENTATION`
- Confidence: `HIGH`
- Capture method: complete response inner text from the signed-in browser session

The text below is preserved as the third closure review receipt. UI-only labels and
source-link labels are retained because they were present in the provider-rendered
response.

---

1. VERDICT

REVISE_BEFORE_IMPLEMENTATION
Confidence：HIGH

F1–F3 與 F5 已在 specification level 關閉；目前不是 traversal、graph semantics 或 field calibration 的問題。仍未關閉的是：

F4：canonical arithmetic 與 content-hash contract

F6：API wire-format contract

F7：部分 input selection／snapshot identity

這三項仍可能讓兩位工程師合理產生不同的 stored states、content hashes 或 API payload，因此尚不符合本輪明定的 approval threshold。這個判定沒有使用 Rat Radar、visual plausibility 或任何 outcome；本輪本來就只允許判斷 F1–F7 的可重現性 closure。

Pasted markdown

前兩輪要求的核心修訂，包括不使用 raw-node topology、移除 renewal transition、固定 global scale、改用 discrete choropleth，以及禁止 outcome 選參數，已大致落實。

Pasted markdown

2. UNCLOSED_FATAL_FLAWS
F4-A. Seed 與 recurrence 的 quantization order 尚未完整唯一化

目前已固定：

BIGNUMERIC

ROUND_HALF_EVEN

各欄位 scale

transition/state 的主要 rounding sequence

這比第二輪完整很多。

Pasted markdown

但仍缺三個會影響 stored states 的順序規則：

1. Seed denominator 使用哪一版 raw_seed

目前只有：

raw_seed = food_score * eligible_area_m2
source_seed = raw_seed / sum(raw_seed)

以及 raw_seed=18 decimals、source_seed=24 decimals。沒有明定：

stored_raw_seed =
  ROUND(food_score_12 * eligible_area_m2_6, 18)


raw_seed_total =
  SUM(stored_raw_seed)


stored_source_seed =
  ROUND(stored_raw_seed / raw_seed_total, 24)

另一個合理實作是先用未量化乘積計算 denominator，再只 round 最後的 source seed。兩者在 rounding boundary 上可能得到不同 state。

2. Same-neighbor multi-class allocation 的 rounding 時點有衝突

Plan 定義：

P(c,d) =
  sewer_bucket * qs(c,d)
  + adjacency_bucket * qa(c,d)

但 contract 又定義：

stored_nonself_transition =
  ROUND(class_bucket * canonical_neighbor_distribution, 24)

同一 pair 同時是 sewer link 與 generic adjacency 時，尚未決定：

A. ROUND(sewer allocation, 24)
 + ROUND(adjacency allocation, 24)

或：

B. ROUND(sewer allocation + adjacency allocation, 24)

兩者可能產生不同 transition row。必須固定為其中一種；較一致的是 先加總所有 class allocations，再 round combined non-self row 一次。相關公式與 rounding contract 位於同一份規格，但目前沒有解決此順序歧義。

Pasted markdown

3. Source-reinjection term 沒有 canonical scale

規格要求每個 transition product round 到 30 decimals，但：

0.25 * source_seed[to]

在與 transition-product sum 相加前是否也 round 到 30 decimals，尚未定義。

最小修正是增加：

stored_source_term[to] =
  ROUND(
    BIGNUMERIC "0.25" * stored_source_seed[to],
    30,
    "ROUND_HALF_EVEN"
  )


stored_state[t+1,to] =
  ROUND(
    stored_source_term[to]
    + SUM(stored_recurrence_product[from,to]),
    24,
    "ROUND_HALF_EVEN"
  )

BigQuery 確實允許對 NUMERIC／BIGNUMERIC 明確指定 ROUND_HALF_EVEN；問題不是函式能力，而是 contract 尚未把上述三個運算順序全部固定。
Google Cloud Documentation

F4-B. Output-table content hash 仍不是 canonical

Contract 目前使用：

row_sort_keys = TABLE_SPECIFIC_PRIMARY_KEYS_ASCENDING
field_order   = TABLE_SCHEMA_DECLARATION_ORDER

但三份文件沒有逐表定義：

完整 table schema；

exact primary key；

exact field order；

GEOGRAPHY encoding；

ARRAY<STRING> encoding與排序；

JSON／GeoJSON encoding；

repeated values 是否保留原順序；

run-level metadata 是否參與 table hash。

Pasted markdown

因此兩位工程師仍可合理採用不同做法，例如：

GEOGRAPHY 使用 WKB、WKT 或 GeoJSON；

limitation codes 使用原順序或 lexicographic sort；

state table key 使用 (scenario, iteration, cell) 或加入 run_id；

schematic link key 使用 unordered pair，或加入 link_class。

這些選擇都可能符合目前文字，卻產生不同 SHA-256。

最小 closure 是為每張 hashed table新增：

table_name
primary_key_fields_in_order
hashed_fields_in_order
field_type
field_scale_or_encoding
array_order_rule
geography_encoding

對 geometry table，最安全的是明定 canonical WKB bytes 或明確排除 geometry column、改 hash 一個 preregistered canonical scalar projection。不能把 encoding 留給 SQL implementer。

F6. API schema 仍是 semantic schema，不是唯一 wire schema

Cell/link 欄位已補齊，support precedence 與 hatch overlay semantics 也已清楚，這部分確實關閉了第二輪的大部分 F6。

Pasted markdown

但以下 payload details 仍未唯一：

eligible_geojson 是：

JSON object；

GeoJSON text string；

還是已 parse 的 geometry member？

schematic_from_centroid／schematic_to_centroid 是：

[longitude, latitude]；

{ "longitude": ..., "latitude": ... }；

number 還是 fixed-decimal string；

使用多少 decimals？

display_scale_max 的 API type 尚未定義：

JSON number；

fixed-24 string；

fixed-12 string。

global_limitation_codes、cell_limitation_codes、link_limitation_codes：

沒有 enum registry；

沒有排序與去重規則。

Generic-adjacency row 的 metric_eligible 語義未定：

固定 false；

null/not applicable；

或表示同一 pair 是否也存在 metric-eligible sewer link。

cell_id schema 只允許 ^[0-9]+$，但 manifest 沒有 hard assertion 證明所有 IDs 非負。BigQuery 的 S2 cell ID 是 signed INT64，官方文件明確指出可能為負值。應改為 ^-?[0-9]+$，或在 input manifest 中加入並驗證 all_cell_ids_nonnegative=true。
Google Cloud Documentation

這些不是 React styling 細節；它們會產生不同 JSON payload。最小修正是加入正式 OpenAPI／JSON Schema 等價 contract，明定 envelope、JSON primitive types、coordinate representation、decimal formats、code enums及 array ordering。

F7. Manifest 尚未唯一選出所有 input rows

Manifest hash、exact table names與多數 source predicates已經存在；F7 並非整體失敗。

Pasted markdown

仍有兩個明確缺口：

1. Sewer attribute 沒有 exact required_predicate

該區塊提供：

source_snapshot_id

required variants

identity fields

expected rows

但沒有像 food／pipe block 一樣的 executable predicate，例如：

source_snapshot_id = '<locked-id>'
AND variant_id IN (...)

也沒有明定：

exactly one row per (source_snapshot_id, variant_id, cell_id)
otherwise FAIL

若 table 未來加入另一個 snapshot 或重複 row，兩位工程師可能選出不同集合。

Pasted markdown

2. Parent lock 沒有 unique row selector

Parent-lock block列出 required fields與 required state，但沒有：

identity field；

scenario／lock ID predicate；

expected matching rows = 1；

multiple-match action。

current_state = PENDING_COMMITTED_PARENT_LOCK 本身不是 fatal；它可以在 materialization 前轉為 locked。真正的缺口是即使 lock 已存在，contract仍未唯一指出應讀哪一列。

Pasted markdown

此外，若這些 BigQuery tables可以原地更新而保留相同 grid_version／freeze_id，僅 hash manifest bytes不能鎖住 input contents。每個 selected input最好再固定：

selected_content_sha256

或使用不可變 BigQuery snapshot/table version。這是 reproducibility requirement，不是要求新增 outcome資料。

3. F1_F7_CLOSURE_TABLE
項目	狀態	可驗證理由
F1 — whole-LineString nonunique traversal	CLOSED	Traversal identity已改為 source vertex order的 elementary edges；edge_ordinal隔離 repeated／retraced path，local low/high interval消除 fragment orientation dependence，collapsed edge直接排除。

Pasted markdown


F2 — gap、boundary overlap與run continuity	CLOSED	已保存 local interval endpoints、固定15-decimal quantization及1e-12 gap/overlap tolerance；whole segment不被 universe覆蓋、positive-length shared-boundary overlap或nonunique traversal均整段 fail closed。

Pasted markdown


F3 — generic adjacency geometry ambiguity	CLOSED	Sewer traversal、adjacency、area與map均指向同一 frozen eligible_geom；self明確排除、只接受正長度 shared boundary、corner touch不算且barriers明示未建模。

Pasted markdown +1


F4 — canonical numerical/hash contract	OPEN	Seed denominator、multi-class allocation rounding與source term scale仍有合理分歧；output-table PK/schema及GEOGRAPHY／ARRAY encoding尚未逐表固定。
F5 — unidentifiable internal connectivity QA	CLOSED	無法唯一重建的internal component metrics已移除，改為明確的NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL；其餘QA分成三個命名graph scopes。

Pasted markdown +1


F6 — API/UI support contract	OPEN	Cell/link欄位與support precedence已存在，但GeoJSON、centroid、decimal、limitation-code及generic-link metric_eligible wire semantics仍不唯一。
F7 — immutable input manifest	OPEN	Manifest檔案與多數source selectors已固定，但sewer attribute缺exact predicate，parent lock缺unique row identity；input content immutability亦未被完整receipt化。

BigQuery提供的 ST_POINTN 是1-based vertex extraction，而 ST_MAKELINE會依輸入順序串接 vertices；因此F1目前採用source-ordered elementary edges的方法本身是可直接實作的。極短edge可能被BigQuery snapping折疊，但目前contract已要求collapsed edge整段排除，這應留給fixture驗證，不再是規格fatal。
Google Cloud Documentation
+1

4. IMPLEMENTATION_GATES

以下只是在上述三個 OPEN 項目修正後，仍必須由實作證明的 gates；它們本身不應再被當成 specification fatal。

BigQuery traversal與graph

Fixtures涵蓋：

A→B→C，不得建立A–C；

A→B→A；

repeated vertices；

retracing；

self-overlap；

shared-boundary positive-length overlap；

corner-only contact；

out-of-universe gap；

collapsed elementary edge；

reversed source orientation。

Reversed LineString的unordered binary link-set hash必須完全一致。

每個source segment必須恰好落入：

admitted；或

一個preregistered exclusion reason。

Full binary、metric-eligible與N2 union graph各自驗證：

unique unordered links；

no self-pairs；

fixed 3,420-cell vertex universe；

degree/component/source-mass QA。

N0與N1的metric-eligible edge-set hash必須完全相同。

Numerical pipeline

Golden fixtures逐步驗證：

canonical food與area；

stored raw seed；

denominator；

stored source seed；

route weight；

class allocations；

combined transition；

source term；

recurrence product；

stored state；

display scale。

每個scenario/from-cell：

transition finite且nonnegative；

row sum通過；

self value等於1 - stored nonself sum。

每個scenario/iteration：

iteration 0逐cell等於canonical seed；

recurrence residual通過；

unit mass通過；

display values均在[0,1]。

兩次clean materialization必須得到完全相同的：

edge hash；

transition hash；

state hash；

quality hash；

map/link artifact hash。

Input manifest與receipt

每個source selector回傳exact expected rows與unique identities。

Sewer metric必須恰有五個required variants，且每個(variant_id, cell_id)最多一列。

Parent lock selector必須exactly one row。

Actual manifest file SHA-256、contract SHA-256、SQL SHA-256、Git revision及input snapshot/content identities全部吻合。

BigQuery referenced-table graph不得含：

Rat Radar raw rows；

Rat Radar aggregates；

retrospective concordance outputs；

urban-renewal network-transition input。

API與React

OpenAPI／JSON Schema conformance tests固定：

GeoJSON representation；

decimal strings；

signed/nonnegative cell-ID rule；

centroid representation；

limitation-code enum與排序；

link-class semantics。

API serializer不得輸出exact pipe geometry、admin-site coordinates或report rows。

React snapshot/integration tests證明：

所有scenario共用同一locked-run scale；

hatch疊加在state fill上；

hatch不把value改成null或low color；

links預設隱藏；

sewer與generic links可區分；

無autoplay、playback、heat interpolation或時間映射。

Forbidden-language tests不得出現：

probability；

risk；

forecast；

spread rate；

rat movement；

sewer flow；

active construction；

recommended inspection；

final／converged result。

5. SEMANTIC_BOUNDARY_CHECK

PASS

目前模型、API與UI的正式語義一致限定為：

DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION
relative_synthetic_network_state
INTERNAL_SIMULATION_ONLY
NO_TRUSTED_RESULT
OPERATIONAL_USE_PROHIBITED

它明確排除：

rat-presence probability；

public-health risk；

rat density；

calendar-time forecast；

sewer flow或capacity；

rat movement／migration corridor；

construction effect；

field validation；

intervention或dispatch output。

Pasted markdown +1

React policy也固定要求「no time mapping」、「not a calibrated rat-presence probability」、「not a sewer-flow or movement map」，並保留 NO_TRUSTED_RESULT 與 operational prohibition。

Pasted markdown

這符合最初不可更改的治理邊界：Rat Radar不得選parameter、scenario、graph或step；exact sewer geometry、admin sites與report rows不進前端；輸出不升格為ground truth或operational result。

Pasted markdown

歷史檔名與historical_working_name = propagation challenger可保留作內部追溯，但不得重新出現在user-facing API、UI label或export title。
