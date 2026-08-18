# GPT Pro last closure review receipt — v0.3 network redistribution challenger

- Conversation: https://chatgpt.com/c/6a834dff-6408-83e8-8bb6-8d30dd199a47
- Model surface: Pro
- Verdict: `REVISE_BEFORE_IMPLEMENTATION`
- Capture method: complete response inner text from the signed-in browser session

The text below is preserved as the last closure review receipt.

---

1. VERDICT

REVISE_BEFORE_IMPLEMENTATION

七項中的五項已關閉，但 transition artifact 與 quality artifact 仍各有一個會改變 canonical table bytes／content hash 的缺口。這些不是 runtime 正確性問題，而是兩位工程師依現有文件仍可能合理產生不同 artifact，因此尚未達到「只剩 tests/runtime」的核准門檻。此次判定僅檢查指定的 bytes-level closure，未重新討論 F1–F3/F5，也未使用 Rat Radar、visual plausibility 或 outcome。

Pasted markdown

2. UNCLOSED_FATAL_FLAWS
A. Transition artifact 的 transition_limitation_codes 尚未唯一決定

本版已正確移除：

sewer_allocation
generic_adjacency_allocation

只保存 combined transition_value，因此 class-allocation residual 的原始問題已關閉。

Pasted markdown

但是 canonical transition table 仍包含：

transition_limitation_codes ARRAY<STRING>

而 artifact contract 沒有為它固定：

合法 enum；

exact assignment rule；

scenario-specific 或 row-specific mapping；

self row 與 non-self row是否相同；

是否必須為空陣列；

是否引用 API 的 global、cell 或 link limitation sets。

該欄位是 canonical table field，會按 schema field order 進入 content hash。兩位工程師可以分別輸出空陣列、scenario-level limitations，或 transition-specific limitations，而都沒有直接違反目前文字。

Pasted markdown

最小修訂二選一：

從 transition artifact 移除 transition_limitation_codes；這是較乾淨的方案，因為 transition table不是一般 UI/API response，治理限制已存在於 scenario、state與API metadata。

保留欄位，但在 artifact contract 中加入 exact enum與 deterministic assignment table，並明定：

final_array =
  exact union of applicable rules,
  lexicographic ascending,
  unique,
  no other codes

不能只在 implementation test 中決定該陣列內容，因為 test需要先有唯一 expected bytes。

B. Quality registry 固定了 row shape，但尚未完全固定 row value與 limitation bytes

本版已關閉大部分 quality artifact問題：

graph scope固定；

scenario／iteration applicability固定；

dimension key shape固定；

component ID固定為 component內最小 signed cell ID；

terminal classification precedence固定；

required row cardinality固定。

Pasted markdown

仍有兩個 bytes-level缺口。

B1. 部分 metric只有名稱，沒有 normative value_formula

最明顯的是：

parallel_source_segment_count_total

目前至少有兩個合理解讀：

SUM(parallel_segment_count)

或：

SUM(parallel_segment_count - 1)

前者是所有位於parallel groups中的source segment總量；後者是duplicate excess。兩者會得到不同 integer_value。

類似地，registry沒有逐項明文固定：

largest_component_cell_share 的精確分子／分母與rounding；

source_mass_by_component 使用哪個canonical seed欄位；

self_only_source_mass 是否按selected scenario的stored transition判定；

endpoint_metric_missingness_excluded_link_count 是計算unique binary links，還是source traversals。

Metric名稱通常足以讓人理解意圖，但不符合本輪要求的 bytes-level唯一性。

B2. Quality table的 limitation_codes 沒有assignment rule

Canonical quality table每列都有：

limitation_codes ARRAY<STRING>

但 quality registry沒有為任何metric指定exact array。實作者可以輸出空陣列、graph-level limitations，或metric-specific limitations。這同樣會改變table hash。

Pasted markdown

最小修訂：

對每個 quality registry record新增：

value_formula
canonical_input_fields
rounding_or_integer_rule
limitation_codes_exact

其中至少把歧義metric改成公式式名稱或明確公式，例如：

parallel_source_segment_duplicate_excess_total =
  SUM(GREATEST(parallel_segment_count - 1, 0))

若 quality rows不需要 limitations，直接從quality artifact移除limitation_codes，或統一規定所有quality rows必須是空陣列。後者也足以關閉bytes-level歧義。

3. SEVEN_ITEM_CLOSURE_TABLE
項目	狀態	判定理由
1. Transition artifact唯一性	OPEN	Class diagnostic allocations已移除，但hashed transition_limitation_codes仍無enum與exact assignment rule。
2. Quality artifact registry	OPEN	Scope、dimension、cardinality與component identity已固定；部分metric仍缺exact value formula，且limitation_codes未唯一指派。
3. Run-ID byte order	CLOSED	九個ordered fields已逐一列出；UTF-8、U+001F、無trailing separator及SHA-256公式均已固定，不再依JSON member order。

Pasted markdown


4. Limitation assignment	CLOSED	API已固定每scenario exact global set、cell additive mapping及每link class exact set，並禁止額外codes。

Pasted markdown


5. Canonical API wire	CLOSED	Signed cell ID禁止leading／negative zero；decimal scale、strictly-positive display scale、signed numeric sorting與canonical link orientation均由schema加normative validator固定。

Pasted markdown


6. Cell／food unique input selection	CLOSED	Cell與food各自要求exactly one row per version/freeze+cell；food cell-ID set必須與3,420-cell universe完全相等。

Pasted markdown


7. Pipe census／parent lock identity	CLOSED	Pipe hash涵蓋完整198,091-row census，traversal candidate另行篩選，每列依固定precedence得到一個terminal class；parent lock有exact selector、expected one row與完整治理欄位hash。

Pasted markdown

4. IMPLEMENTATION_GATES

以下項目在上述兩個artifact contract缺口修正後，才屬於 implementation evidence；不得再用test自行發明規則。

Unit fixtures

Golden transition fixture驗證：

same (from,to)多class allocation先相加、只round一次；

self transition等於1 - stored nonself sum；

transition artifact欄位與limitation array完全符合修訂後contract。

Golden quality fixture逐個registry metric驗證：

exact row cardinality；

exact dimension_key；

exact typed value；

exact limitation array；

exact quality_record_id bytes。

Hash fixture涵蓋：

signed INT64；

fixed-scale decimal；

null；

empty array；

escaped string；

negative zero canonicalization；

U+001E／U+001F／U+000A separators；
-九欄run-ID ordered byte sequence。

BigQuery dry-run與deterministic rerun

完整198,091-row pipe census恰好各有一個terminal classification，九類count總和必須等於198,091。

Traversal fixtures驗證reversed orientation產生完全相同的unordered edge-set hash。

N0與N1的metric-eligible edge-set hash完全相同。

每個scenario／from-cell transition row：

finite；

nonnegative；

row sum通過；

self-only判定一致。

每個scenario／iteration：

iteration 0等於stored seed；

recurrence residual通過；

mass residual通過；

global display scale來自canonical stored states。

兩次clean materialization的run ID及六張output table hashes必須逐byte一致。

Finalized manifest

所有selected_content_sha256非null。

所有selectors、row counts、uniqueness與cell-set equality重新驗證。

Parent lock selector恰好一列。

Finalized manifest hash及九欄run-ID輸入重新計算一致。

Finalization後任一source content mutation必須fail closed。

Referenced-table graph不得含Rat Radar、derived concordance或urban-renewal transition input。

Canonical wire validator

JSON Schema 2020-12 validation通過。

Normative validator另外驗證：

signed INT64 numeric sorting；

no leading zeros；

no negative zero；

strictly-positive display_scale_max；

exact scenario global limitations；

exact cell additive limitations；

exact link-class limitations；

canonical from_cell_id < to_cell_id；

serializer不得重新定向；

canonical array order。

Cell route必須恰有3,420 cells。

N0/N1 link route只回metric-eligible sewer rows；N2另回generic rows；dual-class pair固定為兩列。

React tests

所有scenario與iterations共用同一locked-run scale。

Hatch只覆蓋support limitation，不改變state值或使用另一套色階。

無autoplay、playback、heat kernel、interpolation或calendar-time mapping。

Schematic links預設隱藏，且永久標示不是pipe alignment。

Forbidden-language snapshot tests通過。

Production/public build無法存取internal challenger route。

Receipt

Receipt必須保存並驗證：

contract_hash
finalized_input_manifest_hash
artifact_schema_contract_hash
api_schema_contract_hash
sql_hash
code_revision
output_table_hashes
run_id
5. SEMANTIC_BOUNDARY_CHECK

PASS

目前正式語義仍一致限制為：

DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION
INTERNAL_SIMULATION_ONLY
NO_TRUSTED_RESULT
OPERATIONAL_USE_PROHIBITED

它明確不是rat-presence probability、risk、density、sewer flow、migration、calendar-time forecast、construction effect、field validation或行動建議；既有889筆Rat Radar reports也不能選graph、weights、alpha、iteration、scenario、scale或UI。

Pasted markdown

API與React仍固定使用abstract iteration、global locked-run scale、discrete choropleth、no autoplay、schematic links not pipe alignment，以及persistent governance banner。

Pasted markdown

因此，本輪剩餘阻礙僅是兩個canonical artifact bytes缺口。修正後若不再出現新的artifact歧義，下一輪應可直接判定：

APPROVE_FOR_INTERNAL_IMPLEMENTATION
