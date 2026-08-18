# GPT Pro second review receipt — v0.3 network redistribution challenger

- Conversation: https://chatgpt.com/c/6a834dff-6408-83e8-8bb6-8d30dd199a47
- Model surface: Pro
- Verdict: `REVISE_BEFORE_IMPLEMENTATION`
- Confidence: `HIGH`
- Capture method: complete response inner text from the signed-in browser session

The text below is preserved as the second review receipt. UI-only labels and
source-link labels are retained because they were present in the provider-rendered
response.

---

1. VERDICT

REVISE_BEFORE_IMPLEMENTATION
Confidence：HIGH

第二版已完整關閉大部分第一輪方法問題，包括：

propagation／prediction 語義移除；

endpoint-cell shortcut 移除；

P1 renewal transition 移除；

binary sewer links；

uniform-link comparator；

missing food fail-closed；

global locked-run scale；

discrete choropleth、無 autoplay。

Pasted markdown

原本的治理邊界也有保留：這不是 probability、risk、calendar-time forecast、field ground truth 或 operational output，Rat Radar 不得參與 graph、parameter、scenario 或 iteration 選擇。

Pasted markdown

但仍有數個會讓兩位工程師產生不同 edge set、transition matrix、quality artifact、API payload 或 React rendering 的規格缺口。因此尚未達到 APPROVE_FOR_INTERNAL_IMPLEMENTATION。

本 verdict 不是因為缺乏 field calibration；internal synthetic simulation 不需要先證明外部校準。問題是 implementation determinism 尚未閉合。這也符合本輪指定的判準。

Pasted markdown

2. UNCLOSED_FATAL_FLAWS
F1. ST_LINELOCATEPOINT traversal 仍不保證唯一

目前規格以：

fragment midpoint
→ ST_LINELOCATEPOINT(original segment, midpoint)
→ fraction ordering

建立 traversal sequence，只有在「不同 fragments 產生相同 ambiguous fraction」時才排除整條 segment。

Pasted markdown

這沒有關閉以下情況：

self-crossing LineString；

重複經過同一空間位置的 LineString；

retraced／overlapping subline；

fragment midpoint 同時位於原始 LineString 的多個 traversal positions。

BigQuery 官方定義明確指出：ST_LINELOCATEPOINT 先尋找 linestring 上距離輸入點最近的位置；若有兩個位置等距，不保證選擇哪一個。因此，檢查函式最後回傳的 fraction 是否重複，無法發現另一個未被選中的同距位置。
Google Cloud Documentation

ACTIVE_VALID_NONEMPTY ST_LineString 也不足以排除上述非唯一 linear referencing。valid 不等於沒有 self-overlap 或 repeated traversal。

這會直接改變 traversal order 與 binary pair set，屬於 fatal。

F2. Midpoint-only ordering 無法辨識 traversal gap 與 boundary overlap

目前只記錄 fragment midpoint fraction，沒有記錄 fragment 的 start/end interval。

Pasted markdown

因此無法可靠辨識：

離開 support 後重新進入

例如：

eligible cell A
→ state universe 外或 eligible geometry gap
→ eligible cell B

目前排序後 A、B 會成為 sequence 中相鄰 cells，可能被錯建為 sewer link。規格雖然要求排除 out-of-scope geometry，但沒有定義：

整條 segment 必須完全 in-scope；

還是只刪掉 out-of-scope fragment；

或拆成多個 maximal contiguous traversal runs。

Pasted markdown

沿 cell shared boundary 行進

若 pipe geometry 有正長度部分落在兩個 cells 的共同邊界，該 line fragment 可能同時出現在兩個 cell intersections。單純以 cell ID、fraction、所謂 canonical fragment text 排序，可能：

建立任意 A→B→A sequence；

因 FLOAT64 fraction 的微小差異未被判為 tie；

或依未定義的 text canonicalization 得到不同結果。

目前沒有：

traversal fraction quantization；

tie tolerance；

positive-length shared-boundary overlap policy；

gap tolerance；

interval overlap policy。

這同樣會改變 edge set，屬於 fatal。

F3. Generic adjacency 的 geometry support 未唯一固定

規格定義：

frozen Taipei universe 內、共享正長度 boundary 的 edge neighbors。

但沒有指定 boundary 是基於：

完整 S2 L15 cell polygon；

Taipei boundary clipped cell geometry；

更進一步的 eligible_geom；

其他既有 analysis geometry。

Pasted markdown

這些選擇會在市界、河川、水域排除區、holes 或其他 eligible mask 附近產生不同 Na(c)。

另外尚未明文要求：

from_cell_id != to_cell_id

若工程師直接對 cell table self-join 後檢查 shared boundary，cell 本身與自己的 boundary 具有正長度，可能被誤納入 Na(c)。

因為 Na(c) 會改變 N2 transition matrix，所以屬於 fatal。

F4. Numerical contract 仍只保證「接近」，不保證相同 artifact

目前文字是：

sewer metric quantize 12 decimals
intermediate values preferably BIGNUMERIC
row sum tolerance 1e-12
state mass tolerance 1e-9
recurrence residual 1e-12
hash 前 quantize 12 decimals

Pasted markdown

問題在於 preferably BIGNUMERIC 不是 contract。仍未固定：

food score 與 eligible_area_m2 的輸入型別；

FLOAT64 → BIGNUMERIC 的 conversion rule；

rounding mode；

每個 quantization 發生在運算前、運算後或 storage 前；

transition probability 的 storage scale；

SUM denominator 使用 quantized 或 unquantized weights；

recurrence 使用 stored transition 或 transient higher-precision value；

display_scale_max 使用 quantized 或 pre-quantized state；

decimal serialization；

negative zero；

row ordering、field ordering、NULL encoding 與 hash algorithm。

BigQuery 對 NUMERIC／BIGNUMERIC 支援至少兩種明確 rounding mode：ROUND_HALF_AWAY_FROM_ZERO 與 ROUND_HALF_EVEN。目前 contract 未選定其中之一。
Google Cloud Documentation

Tolerance 只能證明兩個結果足夠接近，不能證明兩個 artifacts 完全一致。尤其 contract 又要求 content hash 作為 lock identity，這是 fatal determinism gap。

F5. 三項 internal-connectivity QA 指標沒有可實作定義

目前要求報告：

cells_with_multiple_internal_geometry_components
cells_where_distinct_exits_are_not_geometry_connected
cross_cell_links_per_internal_component

Pasted markdown

但沒有定義 cell 內的 connectivity identity：

是否使用 raw node ID；

exact coordinate equality；

source resource namespace；

geometry endpoint equality；

ST_INTERSECTS；

crossing lines 是否視為 junction；

是否允許 snap tolerance；

overlapping pipe fragments 如何處理。

而 raw node IDs 已被明確禁止作 topology identity。

Pasted markdown

因此，這三個 required QA outputs 目前無法唯一實作。兩位工程師可能分別產生完全不同的 component counts。

F6. API／React 尚缺少 cell-level support 與 link payload contract

Contract 目前只規定 response 必須包含若干 run-level metadata：

contract_hash
scenario_id
abstract_iteration
normalization_scope
display_scale_max
use_state
evidence_state
operational_use
limitation_codes

Pasted markdown

但沒有定義：

每個 cell 的完整 schema；

cell_id 的 JSON 型別；

relative state 是 number 還是 decimal string；

decimal precision；

per-cell limitation codes；

sewer metric availability；

scenario-specific neighbor counts；

scenario-specific self_only_transition_row；

hatch 是否覆蓋 fill、疊加 fill，或讓 fill 變成 null；

schematic link 的 API route；

link payload；

full binary sewer links 或 scenario-active links；

N2 generic adjacency links 是否顯示；

metric-ineligible sewer links是否仍畫在畫面上。

所有 3,420 cells 在 food 完整時都會有 synthetic state；所以「missing/unsupported cells hatch」不是普通的 null rendering 問題，而是有數值但有 support limitation 的 overlay semantics。目前尚未區分。

Pasted markdown

這會讓不同 API／React 實作者產生不同 payload 與不同視覺敘事，屬於 fatal。

F7. Input manifest 尚未成為 contract 的一部分

Plan 要求 pipe、food、grid snapshots、parent lock、SQL hash 與 contract hash 全部吻合才可 materialize。

Pasted markdown

但 candidate JSON 沒有實際列出或引用一份 immutable input manifest，包含：

source table identity；

snapshot／version identity；

required columns；

active predicate；

geometry column；

resource dedup key；

3,420-cell universe table；

eligible_geom column；

eligible_area_m2 column；

food score field；

sewer attribute field；

expected schema hash。

若這些只留在工程師的 repo knowledge，而沒有進 contract reference，SQL implementation 仍不是 self-contained、uniquely determined。

3. REQUIRED_REVISIONS
R1. 將 whole-LineString midpoint ordering 改成 ordered elementary-edge traversal

建議唯一化為：

使用 source LineString 的 vertex order：

edge_ordinal = 1 .. ST_NUMPOINTS(segment)-1

每個 elementary edge 由：

ST_POINTN(segment, edge_ordinal)
ST_POINTN(segment, edge_ordinal + 1)

建立。

collapsed、empty 或非 LineString elementary edge 必須 fail/exclude 並計數。

每個 elementary edge 分別與固定 cell geometry 求 intersection。

對每個正長度 fragment，使用 fragment start/end points 計算：

local_fraction_a
local_fraction_b
interval_low  = MIN(a,b)
interval_high = MAX(a,b)

排序鍵固定為：

segment_identity
edge_ordinal
quantized_interval_low
quantized_interval_high
cell_id

不再使用 canonical fragment text 作未定義 tie-break。

這使 traversal identity 來自 source vertex order，而不是依賴 whole-LineString 上可能非唯一的 closest-point selection。

R2. 固定 interval overlap、boundary 與 gap policy

Contract 必須新增：

traversal_fraction_quantization_places
traversal_fraction_rounding_mode
traversal_gap_tolerance
interval_overlap_tolerance

並明定：

point/corner-only contact：排除；

同一 elementary edge 上，不同 cells 擁有正長度重疊 fraction interval：

EXCLUDE_SOURCE_SEGMENT_AND_COUNT_BOUNDARY_OVERLAP

無法唯一排序的 interval：

EXCLUDE_SOURCE_SEGMENT_AND_COUNT_NONUNIQUE_TRAVERSAL

segment 離開 cell-universe union 後再進入：

拆成 maximal contiguous traversal runs；

不得跨 run 建 pair。

consecutive duplicate cells 只能在同一 contiguous run內移除。

每個 pair 只能來自同一 run 中相鄰 sequence entries。

若團隊不願實作 contiguous-run detection，較簡單但更保守的替代是：

segment 必須完全 covered by frozen cell-universe union；
否則整條 segment 排除。

兩者擇一，不得留給實作者選擇。

R3. 唯一固定 cell geometry roles

Contract 至少分別指定：

sewer_traversal_intersection_geometry
generic_adjacency_geometry
eligible_area_geometry
map_render_geometry

並引用確切 immutable fields。

Generic adjacency 還必須寫成：

from_cell_id != to_cell_id
shared_boundary_length_m > 0
unordered pair deduplicated
corner-only contact excluded

需要明確選擇 full S2 geometry 或 clipped eligible geometry；不能只寫「analysis cell boundary」。

R4. 將 numerical pipeline 改為強制性 contract

至少固定：

calculation_type = BIGNUMERIC
rounding_mode = ROUND_HALF_EVEN

或另一個明確模式，但只能選一個。

並逐欄定義：

food score canonical scale；

eligible area canonical scale；

sewer attribute canonical scale；

route weight scale；

transition probability scale；

state scale；

display value scale。

還要固定：

quantization 發生位置；

recurrence 使用 stored canonical values；

display_scale_max 從哪一版 state 計算；

API decimal serialization；

canonical hash：

row sort keys；

field order；

decimal fixed-format；

NULL encoding；

delimiter/escaping；

hash algorithm。

另外必須 hard assert：

0 <= sewer_attribute_index <= 1
0.25 <= synthetic_sewer_route_weight <= 1
display_scale_max > 0

BigQuery 的 BIGNUMERIC 是固定精度 decimal type，可避免 FLOAT64 aggregation order 成為主要差異來源，但必須明文要求，而不是「優先」。
Google Cloud Documentation

R5. 修正 QA graph scope 與 internal-connectivity 指標

所有 graph QA 必須加 scope：

FULL_BINARY_SEWER_LINK_GRAPH
METRIC_ELIGIBLE_SEWER_LINK_GRAPH
N2_METRIC_SEWER_PLUS_GENERIC_ADJACENCY_GRAPH

例如：

connected_component_count_by_graph_scope
largest_component_cell_share_by_graph_scope
source_mass_by_component_and_graph_scope
self_only_source_mass_by_scenario

self_only_transition_row 必須 scenario-specific：

N0/N1：沒有 eligible sewer neighbor 即可能是 self-only；

N2：必須同時沒有 sewer 與 generic adjacency allocation。

對三項 internal connectivity metrics，二選一：

選項 A：完整定義 geometry-only component algorithm

必須明確定義 fragment identity、junction rule、crossing semantics 與 tolerance，並將結果命名為：

geometry_intersection_component

不得稱 true pipe connectivity。

選項 B：從 hard gates 移除

首版改為：

internal_cell_connectivity_state =
  NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL

我建議選項 B。否則會重新引入 raw node／snap／crossing-junction assumptions。

R6. 新增完整 API row schema 與 link contract

Cell response 至少應唯一固定為：

cell_id
relative_synthetic_network_state
sewer_attribute_available
eligible_sewer_neighbor_count
eligible_generic_neighbor_count
self_only_transition_row
cell_support_state
cell_limitation_codes

其中：

cell_support_state =
  METRIC_SEWER_SUPPORTED
  NO_ELIGIBLE_SEWER_NEIGHBOR
  SEWER_ATTRIBUTE_MISSING
  GENERIC_ADJACENCY_ONLY
  SELF_ONLY

具體 enum 可以調整，但必須 preregister。

Hatch 應定義為：

在仍顯示 fixed-scale synthetic state fill 的情況下，疊加 support-limitation hatch；不得把有值 cell 改成 null 或 low-state color。

Links 必須：

新增明確 endpoint；或

從第一版 UI scope 完全移除。

若保留，至少需要：

from_cell_id
to_cell_id
link_class
active_in_scenario
metric_eligible
schematic_from_centroid
schematic_to_centroid
link_limitation_codes

並明定 N2 generic adjacency links 是否顯示。不得讓 UI 顯示 full binary sewer graph，而 simulation 實際使用 metric-eligible subset，卻沒有視覺區分。

R7. 將 immutable input manifest 納入 contract hash

新增：

input_manifest_id
input_manifest_hash

manifest 必須包含所有 physical sources、fields、predicates、expected row identities 與 snapshots。

SQL 不應自行選擇「看起來對」的現有 table 或 column。Materialization receipt 必須同時記錄：

contract_hash
input_manifest_hash
sql_hash
code_revision
output_table_hashes
4. BIGQUERY_TRAVERSAL_REVIEW
審查項目	判定	結論
Fragment extraction	CONDITIONAL PASS	ST_INTERSECTION + dimension-1 dump + positive length 是合理方向。
Fragment ordering	FAIL	Whole-LineString midpoint fraction 在 repeated/self-overlapping traversal 下不唯一。
Ambiguous tie	FAIL	沒有 fraction quantization、tie tolerance；函式內部等距選擇也可能未被偵測。
Positive-length boundary overlap	FAIL	未定義同一 interval 同時屬於兩 cells 的處理。
Out-of-support gap	FAIL	可能跨 gap 連接相鄰 sequence entries。
Consecutive duplicate removal	CONDITIONAL PASS	只能在明確的 contiguous traversal run 內使用。
Binary unordered pair	PASS AFTER TRAVERSAL FIX	Binary pair、parallel metadata QA-only 已明確。

Pasted markdown


Reverse-orientation invariance	NOT YET GATED	反轉 source LineString 後 unordered edge set 應完全相同，需 fixture assertion。
Determinism	FAIL	Current midpoint／text／FLOAT64 tie rules尚不足。

BigQuery 官方亦只將 ST_ASTEXT 定義為 WKT formatter，沒有提供「canonical geometry serialization」保證；而幾何相等本身可在 vertex order 不同時仍成立。因此所謂 canonical fragment text 不應作為未明定的 identity primitive。這是依官方函式定義所作的實作推論。
Google Cloud Documentation

5. TRANSITION_AND_SCALE_REVIEW
已關閉
Row-stochastic bucket construction

目前已明確定義：

P(c,d) =
  sewer_bucket * qs(c,d)
  + adjacency_bucket * qa(c,d)

同 neighbor 跨 class 相加，無 neighbor 的 bucket 只回 self，不跨 class reallocate。

Pasted markdown

在 neighbor sets 與 self exclusion 正確的前提下，這足以構造 row-stochastic matrix。

Same-support comparator

N0 uniform comparator 與 N1 metric scenario 明文使用相同的 metric-eligible sewer-link support，只改變 neighbor distribution。這項 revision 已正確關閉。

Pasted markdown

必須以 edge-set hash equality 驗證，而不是只比較 link count。

Renewal removal

Renewal 已完全移出 network transition，只留在 v0.3 administrative-context ranking，這項已關閉。

Pasted markdown

Missing food

3,420 cells 任一 food score missing 即 fail materialization，已正確關閉。

Pasted markdown

Recurrence orientation

現在明文使用：

state[t+1,to]
  = 0.25 * seed[to]
  + 0.75 * SUM_from(state[t,from] * P[from,to])

matrix orientation 已清楚。

Pasted markdown

Global scale

Locked-run global maximum涵蓋所有 cells、scenarios 與 iterations，已消除 frame-specific normalization 的主要 presentation defect。

Pasted markdown

尚未關閉

Na(c) geometry support 未定，會改變 P。

self_only_transition_row 未定義為 scenario-specific。

source_mass_by_connected_component 未指出 graph scope。

sewer_attribute_index 缺 finite／range gate。

tolerance 已有數值，但 canonical numeric pipeline 未固定。

display_scale_max 是從 pre-quantized 或 canonical stored states 計算，尚未定義。

relative_synthetic_network_state 的 storage/API decimal precision 未定義。

因此 transition 數學形式通過，但 artifact-level transition／scale contract 尚未通過。

6. API_UI_REVIEW
項目	判定	結論
Model naming	PASS	DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION 可接受。
Dataset namespace	PASS	已移除 predictions namespace。

Pasted markdown


API route/input constraints	PASS	Locked scenario enum、iteration 0–8、無 arbitrary parameter input。
Required governance metadata	PASS	use/evidence/operational states均保留。
Cell payload schema	FAIL	僅列 metadata，未定義 rows、types、precision、support fields。
Per-cell missingness/support	FAIL	limitation_codes scope不明；hatch semantics 未定。
Choropleth	PASS	Discrete cells、無 heat kernel/interpolation。
Iteration semantics	PASS	手動 abstract iteration slider、無 playback、無時間對應。
Global scale	CONDITIONAL PASS	概念正確，仍需數值 canonicalization。
Schematic links	FAIL	無 link API schema，且 full links／active links／N2 adjacency 顯示規則未定。
Exact geometry exclusion	PASS	exact pipes/admin/report rows 不進 API/UI。
Forbidden wording	PASS	probability、risk、movement、active construction 等限制已明文保留。

Pasted markdown

目前的 persistent banner 足以降低直接誤讀，但它不能補救 payload 與 support rendering 尚未定義的問題。

7. IMPLEMENTATION_GATES

以下 gates 是在完成上述 required revisions、再次取得 approval 後，仍必須由 tests／live dry-run 證明的事項。

BigQuery traversal fixtures

至少包含：

單一 cell 內的 straight segment：不產生 cross-cell pair。

A→B→C：只產生 A–B、B–C，不產生 A–C。

A→B→A：binary output只含 A–B。

跨 S2 vertex：不得產生未經 traversal 的 intermediate pair。

沿 shared boundary 正長度行進：必須觸發固定 exclusion code。

短暫 point/corner contact：不建立該 cell route。

A→outside universe→B：不得建立 A–B。

self-crossing／repeated traversal：依新 admissibility rule deterministic 處理。

reversed LineString：unordered pair set hash 必須完全一致。

MultiLineString、empty、collapsed edge、invalid input：固定 exclusion code。

多 fragments 同 cell：不得因 dump order 改變 pair set。

同一 source segment重跑兩次：fragment/run/pair hashes完全一致。

Graph gates

3,420-cell universe identity完全吻合。

Binary pair unique、無 self-pair。

Generic adjacency無 self-neighbor。

Generic adjacency全部符合 frozen geometry predicate。

N0/N1 eligible sewer edge ID set hash完全相同。

Full binary、metric-eligible、N2 union graph各自有獨立 QA scope。

Exclusion counts依 reason完整加總回 source segment population。

不可計算的 internal topology QA 被明確標為 NOT_IDENTIFIABLE，不得靜默填 0。

Transition／recurrence gates

每個 scenario、from-cell恰有一個完整 transition row。

所有 transition values nonnegative、finite。

每 row sum符合 frozen tolerance。

同 neighbor跨 class只有一個 stored row，allocation正確加總。

Unused bucket只回 self。

self_only_transition_row依 scenario正確。

Step 0逐 cell完全等於 canonical seed。

Steps 1–8逐 cell recurrence residual通過。

每 scenario／iteration synthetic mass通過。

display_scale_max 等於 canonical state table的實際 maximum且大於 0。

所有 relative values位於 [0,1]。

兩次 clean rerun的完整 table content hashes完全一致，而不只是 tolerance-pass。

API gates

OpenAPI／JSON schema固定 cell fields、types、nullability、precision。

Per-cell limitation codes與global limitation codes分離。

No probability、risk、prediction、movement、construction-effect fields。

Raw unit mass僅 restricted QA endpoint。

Exact pipe/admin/report geometry無法經 serializer 路徑洩漏。

Link endpoint若存在，只回 schematic aggregated cell links。

Scenario-active／metric-ineligible／generic adjacency link states可被區分。

Response包含 contract、input manifest、run identity與global normalization metadata。

Rat Radar及其 derived tables不出現在 referenced-table graph。

React gates

Autoplay與playback不存在或永久 disabled。

所有 scenario共享同一 locked-run legend domain。

Hatch是 limitation overlay，不將有值 cell偽裝成 missing或low state。

Scenario-specific self-only／metric-missing狀態顯示正確。

Schematic links預設隱藏。

Link legend永久顯示：

Schematic aggregated cell link — not pipe alignment

N2 generic adjacency若不顯示，UI必須明示；若顯示，必須與 sewer links使用不同 class label。

禁止 heat interpolation、missing-cell smoothing、time icon、speed control。

Forbidden-language snapshot test通過。

Public／production build無法存取 challenger route。

在上述 revisions 關閉前，不能將狀態改為 APPROVE_FOR_INTERNAL_IMPLEMENTATION。
