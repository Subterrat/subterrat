# GPT Pro final closure review receipt — v0.3 network redistribution challenger

- Conversation: https://chatgpt.com/c/6a834dff-6408-83e8-8bb6-8d30dd199a47
- Model surface: Pro
- Verdict: `REVISE_BEFORE_IMPLEMENTATION`
- Capture method: complete response inner text from the signed-in browser session

The text below is preserved as the final closure review receipt. UI-only labels and
source-link labels are retained because they were present in the provider-rendered
response.

---

1. VERDICT

REVISE_BEFORE_IMPLEMENTATION

本輪已把核心 recurrence、seed quantization、combined transition rounding、API envelope，以及 input snapshot selectors 收斂得相當完整；但仍有少數會實際改變 output-table hash、run ID、quality artifact 或 API payload的規格歧義。

依本次明定標準，只要兩位工程師仍可能合理產生不同 artifact，就不能把差異降格為 implementation gate。

Pasted markdown

2. UNCLOSED_FATAL_FLAWS
F4-A. Transition 主矩陣已唯一，但 transition artifact 的兩個 class 欄位仍未唯一

核心計算已明確要求：

unrounded sewer allocation
+ unrounded generic allocation
→ combined by (from,to)
→ round combined transition once to 24 decimals

這部分已關閉。

Pasted markdown

但 artifact schema 同時要求儲存：

sewer_allocation              BIGNUMERIC(24)
generic_adjacency_allocation  BIGNUMERIC(24)
transition_value              BIGNUMERIC(24)

Pasted markdown

目前沒有定義：

sewer_allocation 是否獨立 round 24；

generic_adjacency_allocation 是否獨立 round 24；

兩者是否必須精確加總為 transition_value；

rounding residual 應歸到哪一 class；

self row 的兩個 allocation 欄位應為 0，還是包含 unavailable bucket return-to-self。

因此相同的 canonical transition_value 可以對應多種合法 artifact rows 和不同 content hashes。

最小修訂

在 artifact contract 固定：

stored_sewer_allocation =
  ROUND(unrounded_sewer_class_allocation, 24, ROUND_HALF_EVEN)


stored_generic_adjacency_allocation =
  ROUND(unrounded_generic_class_allocation, 24, ROUND_HALF_EVEN)


stored_transition_value =
  ROUND(
    unrounded_sewer_class_allocation
    + unrounded_generic_class_allocation,
    24,
    ROUND_HALF_EVEN
  )

並明文：

stored_sewer_allocation
+ stored_generic_adjacency_allocation
is not required to equal stored_transition_value exactly
because the combined value is rounded independently.

對 self row 固定：

sewer_allocation = 0
generic_adjacency_allocation = 0
transition_value = stored_self_transition

如果這兩個 class 欄位不需要供 QA，直接從 canonical artifact 移除會更乾淨。

F4-B. Quality artifact 仍缺少 normative row registry

目前 quality table 只規定：

quality_record_id = STRING_DETERMINISTIC_FROM_DIMENSIONS
metric_name       = STRING_REQUIRED_GRAPH_OR_NUMERIC_QA_ENUM
dimension_key     = STRING

但沒有提供：

完整 metric_name enum；

每個 metric 應產生哪些 rows；

graph_scope、scenario_id、abstract_iteration 的適用矩陣；

dimension_key 的 canonical encoding；

quality_record_id 的公式；

connected component 的 canonical component ID；

source-segment 多重失敗時的 exclusion-reason precedence。

Pasted markdown

例如 source_mass_by_component_and_graph_scope 可以用 component ordinal、任意 traversal order，或 component minimum cell ID 當 dimension_key。三者都能表達同一 QA 結果，但會產生不同 rows 和 hashes。

Required QA 名稱雖已列出，還不足以唯一決定 quality table 的實體內容。

Pasted markdown

最小修訂

新增 normative quality registry。每個 metric 固定：

metric_name
graph_scope applicability
scenario applicability
iteration applicability
dimension_key formula
typed value column
required row cardinality

並固定：

connected_component_id =
  minimum signed INT64 cell_id in that component

所有 graph scope 都以完整 3,420-cell vertex universe 計算，isolated cells 算單節點 component。

另新增 source-segment exclusion precedence，例如：

1. SOURCE_ROW_INACTIVE
2. GEOMETRY_NULL
3. GEOMETRY_TYPE_UNSUPPORTED
4. GEOMETRY_EMPTY_OR_INVALID
5. COLLAPSED_ELEMENTARY_EDGE
6. OUTSIDE_OR_GAPPED_CELL_UNIVERSE
7. POSITIVE_LENGTH_BOUNDARY_OVERLAP
8. NONUNIQUE_TRAVERSAL
9. ADMITTED

每個 source row 必須恰好落入一個 terminal classification。

F4-C. run_id 的 input-hash ordering 仍有歧義

目前公式是：

selected_input_content_hashes_sorted_by_manifest_section

但沒有固定「manifest section」是：

JSON source order；

lexicographic section-name order；

或另一個 explicit order。

Pasted markdown

JSON object member order不應被當成語義 identity，因此這仍可能產生不同 run_id。

最小修訂

固定唯一順序：

cell_universe
food_seed
pipe_geometry
sewer_attribute
parent_v0_3_lock

並將完整 run-ID byte construction 寫成 ordered field list，而不是 sorted_by_manifest_section。

F6-A. Limitation code 的合法值已固定，但 assignment mapping 尚未固定

API schema 已固定：

global limitation code enum；

cell limitation code enum；

link limitation code enum；

unique arrays；

lexicographic canonical order。

Pasted markdown

但它沒有規定哪些合法 code 必須出現在哪一筆 response。

例如一個 GENERIC_ADJACENCY_ONLY cell，實作者可以合理輸出：

JSON
["GENERIC_ADJACENCY_ONLY_SUPPORT"]

也可以輸出：

JSON
[
  "GENERIC_ADJACENCY_ONLY_SUPPORT",
  "SEWER_ATTRIBUTE_MISSING",
  "V0_2_SEWER_METRIC_GATES_INCOMPLETE"
]

兩者都可能通過目前 schema。

同樣地，尚未唯一固定：

global codes 是永遠輸出完整 known-limitations set，還是 scenario-specific subset；

sewer link 是否永遠帶 SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT；

generic link 是否必須同時帶 barrier 與 schematic codes；

cell support state 與 additive limitation codes 的對應。

這會直接造成不同 API payload。

最小修訂

新增 deterministic mapping table：

global_limitation_codes_by_scenario
cell_limitation_codes_by_support_state_and_conditions
link_limitation_codes_by_link_class

建議 global codes直接固定為每個 scenario 的 exact required set，不讓 API 實作者自行挑選。

Cell code採 additive rule。例如：

all cells:
  CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY
  V0_2_SEWER_METRIC_GATES_INCOMPLETE


if sewer_attribute_available = false:
  SEWER_ATTRIBUTE_MISSING


if eligible_sewer_neighbor_count = 0:
  NO_ELIGIBLE_SEWER_NEIGHBOR


if support state = GENERIC_ADJACENCY_ONLY:
  GENERIC_ADJACENCY_ONLY_SUPPORT


if self_only_transition_row = true:
  SELF_ONLY_TRANSITION_ROW

Link code也應逐 class 固定 exact set。

F6-B. Normative JSON Schema 仍允許非 canonical decimal-string representation

目前：

JSON
"cellId": {
  "pattern": "^-?[0-9]+$"
}

會接受：

000123
-000123
-0

而 canonical integer contract要求 base-10、不得有非必要 leading zeros，且 negative zero 要轉成 positive zero。

另外：

JSON
"decimal24Positive"

的 pattern實際允許：

0.000000000000000000000000

與 display_scale_max = STRICTLY_POSITIVE 不一致。decimal7 也允許 -0.0000000。

Pasted markdown

最小修訂

至少改為：

cellId:
  ^(0|-?[1-9][0-9]*)$

並對 decimal validators 明確排除 negative zero。

decimal24Positive 必須拒絕全零值；如果 regex 過度複雜，可用 JSON Schema pattern加 application-level canonical-format validator，但該 validator必須成為 normative contract 的一部分。

另外固定 link IDs 從 artifact 的 canonical unordered orientation原樣輸出：

from_cell_id < to_cell_id

不得由 API serializer 重新定向。

F7-A. Cell 與 food selections 缺少明文 uniqueness assertion

cell_universe 與 food_seed 都有：

expected 3,420 rows；

identity field；

selected-content primary key。

但不像 pipe與sewer attribute sections，沒有明文：

EXACTLY_ONE_ROW_PER_...
OTHERWISE_FAIL

Pasted markdown

總 row count 3,420 不足以保證 3,420 個 unique cells；例如一個 cell重複、一個 cell缺失，仍可能有 3,420 rows。

最小修訂

新增：

cell_universe:
  EXACTLY_ONE_ROW_PER_grid_version_cell_id_OTHERWISE_FAIL


food_seed:
  EXACTLY_ONE_ROW_PER_freeze_id_cell_id_OTHERWISE_FAIL

並要求 selected cell-ID set與 cell universe完全相等，而不只是 row count相等。

F7-B. Pipe selector 先排除部分 source rows，卻又要求完整 exclusion QA

Manifest 同時聲明：

expected_source_rows = 198091
expected_active_nonnull_geometry_rows = 192533

但 canonical selected predicate 已先過濾為：

is_active
AND geom_wgs84 IS NOT NULL
AND ST_GEOMETRYTYPE(...) = 'ST_LineString'

Pasted markdown

Plan卻要求 MultiLineString、empty、invalid、collapsed、ambiguous、out-of-scope等 rows有固定 exclusion code，並將 source-segment exclusion counts寫入 deterministic quality artifact。

Pasted markdown

目前會有兩種合理實作：

只對 192,533 個預先篩選 rows做 exclusion QA；

對完整 198,091 個 snapshot rows做 terminal classification。

兩者會得到不同 quality artifacts。更嚴重的是，如果 excluded source rows在 manifest finalization後變動，目前 selected-content hash可能完全不變。

最小修訂

把 pipe input拆成兩層：

source_census_predicate:
  source_snapshot_id = '<locked snapshot>'


expected_source_census_rows:
  198091

完整 census selection進 selected-content hash，geometry hash使用 null-safe expression：

NULL_OR_TO_HEX(ST_ASBINARY(geom_wgs84))

再另外固定：

traversal_candidate_predicate:
  is_active
  AND geometry non-null
  AND supported geometry type

所有 census rows依前述 exclusion precedence恰好分類一次。這樣 input hash、exclusion QA及run identity才對同一個 source population負責。

F7-C. Parent lock 的 specification_state 被要求讀取，但未被 predicate 或 content hash 鎖定

Parent-lock section把 specification_state 列為 required field，卻：

沒有在 required_predicate 中要求 exact locked value；

沒有放入 hashed_fields_in_order。

Pasted markdown

因此同一列的 specification_state 可以改變，而 selector和selected-content hash都維持不變。

最小修訂

在 predicate中加入 exact value，例如：

specification_state = 'LOCKED'

實際 enum應使用 parent contract 已定義的正式值。

並把：

specification_state

加入 parent-lock selected-content hash projection。

3. F4_F6_F7_CLOSURE_TABLE
項目	狀態	理由
F4 — canonical arithmetic / artifact hash	OPEN	Core seed、combined transition與recurrence已唯一，但 per-class transition fields、quality-row registry、exclusion precedence及run-ID input order仍可產生不同 canonical artifacts。
F6 — API wire format	OPEN	Envelope、types與enums已固定，但 limitation-code assignment、canonical integer/decimal representations及link orientation尚未完全由normative schema唯一決定。
F7 — unique input selection / content identity	OPEN	Sewer與parent selectors大幅改善，但cell/food uniqueness、完整pipe census hashing及parent specification_state仍未fail-closed。
4. IMPLEMENTATION_GATES

以下項目應在上述規格缺口修正後，作為 implementation evidence；不應再用來重新改 specification。

Unit fixtures

Golden arithmetic fixture逐值驗證：

food_score_12

eligible_area_m2_6

stored_raw_seed_18

raw_seed_total

stored_seed_24

route weight

unrounded class allocations

stored class diagnostic allocations

combined transition

self transition

source term

recurrence products

stored state

display value。

Fixture包含同一 (from,to) 同時屬 sewer與generic class，證明 combined transition只round一次。

Fixture驗證 class diagnostic columns與combined transition在rounding-boundary情況下遵守新 contract。

Golden hash fixture驗證：

null；

empty array；

escaped string；

signed INT64；

fixed-scale decimal；

negative zero；

canonical GeoJSON text；

exact run-ID byte sequence。

BigQuery dry-run與deterministic rerun

Traversal fixtures涵蓋 repeated vertex、retracing、boundary overlap、coverage gap、collapsed edge與reverse orientation。

每個pipe source census row恰好得到一個 terminal classification。

N0與N1 metric-eligible edge-set hash完全相同。

每個transition row：

nonnegative；

finite；

exact canonical self row；

row sum通過。

每個scenario／iteration：

iteration 0等於stored seed；

recurrence residual通過；

mass tolerance通過；

display scale取自canonical stored states。

兩次clean materialization必須得到完全相同的：

run ID；

cell-link hash；

transition hash；

state hash；

quality hash；

map hash；

schematic-link hash。

Finalized input manifest

所有 selected_content_sha256 非null。

Cell、food、pipe、sewer及parent selectors均符合exact row count與uniqueness assertions。

Parent lock exactly one row，且所有治理欄位與content hash一致。

Finalized manifest bytes hash、selected-content hashes及run ID重新計算一致。

Finalization後重新讀取source，任何content mismatch一律停止run。

API tests

Draft 2020-12 schema validation通過。

另執行canonical wire validator，檢查JSON Schema標準無法直接強制的：

lexicographic array order；

signed INT64 numeric ordering；

no leading zeros；

no negative zero；

strictly positive display scale；

exact limitation-code mapping；

canonical unordered link orientation。

Cell response恰有3,420 cells，並依signed INT64數值排序，而不是字串lexicographic排序。

Link response只含requested scenario active links；dual-class pair恰有兩列。

Serializer不可輸出exact pipe geometry、admin-site coordinates、Rat Radar rows或raw unit-mass state。

React tests與receipt

所有scenarios與iterations共用同一locked-run scale。

Hatch只作support-limitation overlay，不改變state value或色階。

無autoplay、playback、heat interpolation或calendar-time mapping。

Schematic links預設隱藏，且sewer／generic classes可區分。

Persistent governance banner與forbidden-language tests通過。

Receipt保存：

contract hash；

finalized manifest hash；

artifact schema hash；

API schema hash；

SQL bundle hash；

code revision；
-所有output table hashes。

5. SEMANTIC_BOUNDARY_CHECK

PASS

目前正式模型語義已一致限制為：

DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION
relative_synthetic_network_state
INTERNAL_SIMULATION_ONLY
NO_TRUSTED_RESULT
OPERATIONAL_USE_PROHIBITED

文件明確排除 probability、risk、rat density、sewer flow、migration、calendar-time forecast、construction effect、field validation與行動建議；Rat Radar仍只能在完整lock後作一次性位置concordance，不能選graph、weights、scenario、iteration或display scale。

Pasted markdown

API與React也維持：

no time mapping；

not a calibrated rat-presence probability；

not a sewer-flow or movement map；

schematic links不是pipe alignment；

operational use prohibited。

Pasted markdown

因此剩餘問題是deterministic specification closure，不是semantic overclaim，也不是缺少field calibration。
