# GPT Pro review receipt — v0.3 network redistribution challenger

- Conversation: https://chatgpt.com/c/6a834dff-6408-83e8-8bb6-8d30dd199a47
- Model surface: Pro
- Review duration shown by provider: 19m 25s
- Verdict: `REVISE_BEFORE_IMPLEMENTATION`
- Confidence: `HIGH`
- Capture method: complete response inner text from the signed-in browser session

The text below is preserved as the review receipt. UI-only labels such as
`Pasted markdown` and source-link labels are retained because they were present
in the provider-rendered response.

---

1. VERDICT

REVISE_BEFORE_IMPLEMENTATION
Confidence：HIGH

這個 challenger 不需要被整體否決。使用 S2 L15 cell 作為粗粒度 state、以固定 seed 和 row-stochastic transition 做 deterministic redistribution，在嚴格限制為 internal simulation 時，是可實作的方法性壓力測試。

但目前規格尚未達到可直接實作的程度，原因不是 Rat Radar 表現，而是：

graph edge identity 尚未完整定義；

transition bucket 如何分配到多個 neighbor 尚未定義；

P1 的公式實際上不是合理的 renewal-context sensitivity；

frame-by-frame x / max(x) 與 autoplay 會製造不可比較、近似時間擴散的視覺效果；

predictions、propagation intensity、corridors 等名稱仍超出治理語義。

原始 node ID 的嚴重 coordinate conflicts 足以支持「不使用 raw node topology」；但它不會自動證明 cell graph 是真實 sewer topology。它只能證明 cell graph 是一個較可控的粗粒度替代圖。附件本身已明確禁止 probability、calendar-time、Rat Radar 調參、實際施工活動與 operational use，這些治理邊界應保留。

Pasted markdown

2. FATAL_FLAWS

以下問題會阻止依照目前文字進行 implementation。

F1. Endpoint-cell edge construction 不是完整的 geometry-derived route

目前規格以每條 pipe segment 的 start/end cells 建立 cross-cell pair。

Pasted markdown

這會產生至少兩類錯誤：

一條線跨過多個 cell 時，start/end pair 會建立跳過中間 cell 的 non-local edge。

一條線 start/end 位於同一 cell、但中途離開再進入時，會被錯分為 within-cell segment。

因此，start_cell ↔ end_cell 不能直接等同於 geometry-derived route。必須沿完整 LineString 的 cell traversal sequence建立相鄰 cell pair。

F2. P 並未被唯一決定

規格只定義：

self/sewer/surface buckets；

sewer edge weight；

unavailable bucket 回到 self；

P 必須 row-stochastic。

Pasted markdown

但沒有定義：

sewer bucket 如何分給多個 sewer neighbors；

多條 pipe 對應同一 cell pair 時是 binary edge、segment-count weighting，還是 length weighting；

surface neighbor 是 shared-edge adjacency 還是包含 corner touch；

sewer 與 surface 同時連到同一 neighbor 時是否相加；

within-cell pipe 數量是否真的改變 self weight。

因此，兩個工程師可以產生不同的 P，且都聲稱符合現有 contract。這不符合 deterministic preregistration。

F3. P1 目前不是有效的 renewal sensitivity

目前：

P0 self   = 0.65
P0 sewer  = 0.35


P1 self   = 0.55 + 0.10 * r
P1 sewer  = 0.45 - 0.10 * r

其中 r = renewal_admin_percentile。

Pasted markdown

相對 P0：

Delta self  = -0.10 * (1 - r)
Delta sewer = +0.10 * (1 - r)

結果是：

r = 1：P1 完全等於 P0；

r = 0：P1 與 P0 差異最大。

換言之，它不是「renewal context 越高，retention 被調整越多」，而是「renewal context 越低，transfer 越高」。這個方向既沒有行政資料語義支持，也沒有施工時間資訊支持。

此外，只實作單一方向會把未知方向偷渡成模型假設。這違反 fail-closed 原則。

F4. 每個 frame 各自除以最大值，卻允許動畫比較

目前 API 輸出：

x[t] / max(x[t])

而 UI 有 step slider 與 autoplay。

Pasted markdown +1

若每個 scenario/step 都自行縮放到最大值 1：

不同 frame 的相同顏色不代表相同 synthetic mass；

最大值即使從 0.01 降至 0.002，畫面仍會顯示一個值為 1 的 cell；

autoplay 會讓使用者直覺解讀為真實強度在移動。

這不是單純 UI 小問題，而是 output semantics 與 presentation semantics 不一致。

3. REQUIRED_REVISIONS
R1. 將模型重新命名為 network redistribution，而非 propagation

至少修改：

model_kind:
  DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION


primary_output:
  relative_synthetic_network_state


UI mode:
  Network redistribution challenger

propagation 可保留在內部歷史文件名稱中，但不應作為 API、資料表欄位或 UI 的主要使用者語義。

R2. 使用完整 geometry traversal 建立 cell links

對每個有效 active pipe geometry：

找出 geometry 依行進順序穿越的 S2 L15 cells；

移除連續重複 cell；

僅建立 sequence 中相鄰 cell 的 unordered pair；

geometry 僅碰觸 cell 邊界或頂點、但沒有正長度交集時，不建立 traversed-cell route；

MultiLineString、empty、invalid、out-of-scope geometry 必須有固定處理規則；

exact geometry 留在 BigQuery construction layer，不輸出 API/UI。

這可避免 endpoint teleport edge，同時仍維持 cell-level privacy boundary。

R3. Cell-pair edge 採 binary adjacency；parallel pipes 只作 QA

在沒有 literature-backed route-capacity rule 的前提下，最少假設的方式是：

one unordered cell pair = one sewer link

同一 pair 的：

segment count；

distinct pipe count；

total geometry length；

resource count；

可以保留作 QA，但不得自動乘入 route weight。使用 segment multiplicity 或 pipe length 會新增未註冊的容量假設。

R4. 明確寫出 transition allocation

對 cell c：

Ns(c) = eligible sewer-link neighbors
Na(c) = eligible generic adjacency neighbors

Sewer synthetic route weight：

w(c,d) =
  0.25 + 0.75 * mean(
    SewerAttribute(c),
    SewerAttribute(d)
  )

Sewer-normalized distribution：

qs(c,d) =
  w(c,d) / sum_{j in Ns(c)} w(c,j)

Surface/generic adjacency 使用最少假設的 uniform rule：

qa(c,d) = 1 / |Na(c)|

對 d != c：

P(c,d) =
  sewer_bucket(c)  * qs(c,d)
  + surface_bucket(c) * qa(c,d)

若 d 同時屬於兩種 route class，兩項相加，不視為兩個 cell rows。

Self：

P(c,c) =
  self_bucket(c)
  + sewer_bucket(c)  * I[Ns(c) is empty]
  + surface_bucket(c) * I[Na(c) is empty]

不得把 unused sewer mass 動態分配到 surface，反之亦然。

R5. 修正 within-cell pipe 的描述

目前文字稱 180,359 個 within-cell segments 進入「self-retention context」，但固定 self bucket 並未使用 segment 數量、長度或有無 pipe。

Pasted markdown

因此應改成：

Within-cell pipe segments are not represented as traversable
links at S2 L15 resolution. Their counts are retained for QA only
and do not determine the self-allocation bucket.

否則會錯誤暗示 self=0.65 是由 within-cell sewer evidence 推導而來。

R6. P1 必須移除或改成雙向、以 P0 為基準的 paired sensitivity

可接受的修正有兩種。

首選：暫時移除 P1

Urban renewal 繼續留在 v0.3 administrative-context layer，不進 network transition。

次選：同時實作兩個方向，不選 winner
r(c) = renewal administrative-context percentile


P1_lower_self:
  self   = 0.65 - 0.10 * r(c)
  sewer  = 0.35 + 0.10 * r(c)


P1_higher_self:
  self   = 0.65 + 0.10 * r(c)
  sewer  = 0.35 - 0.10 * r(c)

這兩個方向都在 r=0 時回到 P0，且只在有 renewal context 時偏離 baseline。

要求：

兩個方向必須一起呈現；

不得以 Rat Radar 或 visual plausibility 選其中一個；

名稱只能是 higher_self_allocation／lower_self_allocation；

不得稱 displacement、disturbance、retention effect 或 construction effect。

如果產品只允許一個 P1 scenario，則應不實作 P1，而不是任選一個方向。

R7. 將 surface route 改為 generic cell adjacency sensitivity

P2 沒有 river、street、building 或其他 barrier，因此它不是有證據的 surface movement network。應改名：

p2_generic_cell_adjacency_sensitivity

並固定：

只使用共享正長度 boundary 的 edge-neighbor；

不使用僅 corner-touch 的 diagonal neighbor；

每個 eligible neighbor 均分 0.10；

Taipei universe 外 neighbor 不納入；

無 neighbor 時 0.10 回到 self。

R8. 修正 restart_alpha 名稱

公式中的 alpha=0.75 是：

75% transition continuation
25% source reinjection

不是 75% restart。

應改成：

transition_continuation_alpha = 0.75
source_reinjection_weight = 0.25
R9. 不得把 missing food 無條件當成真實零值

Contract 現在指定：

missing_food_action = ZERO_WITH_EXPLICIT_SOURCE_COVERAGE_REPORT

Pasted markdown

只有在 frozen v0.1 contract 已明確定義「null 表示沒有 food evidence，且可視為 score 0」時才可使用。

否則應：

fail materialization；或

明確建立 source_support_limited simulation；

將 missing seed 設為 0，但保留 food_missing=true，且只在 observed support 上正規化；

不得把 missing cell 稱為 low-food cell。

R10. 改用跨 locked run 固定的 display scale

建議：

display_scale_max =
  max(x[c,t,scenario])
  over all locked cells, steps, and scenarios


relative_synthetic_network_state =
  x[c,t,scenario] / display_scale_max

這使相同顏色可跨 scenario 與 iteration 比較。

若仍使用 frame-specific max，則必須：

回傳 normalization_scope = FRAME;

顯示「colors are not comparable across iterations or scenarios」；

禁止 autoplay；

禁止 side-by-side quantitative comparison。

較安全的選擇是固定 global scale。

R11. 新增 topology-only comparator

g(c,d) 經 row normalization 後，只影響同一 cell 多個 sewer neighbors 之間的分配：

degree 0：完全無作用；

degree 1：完全無作用；

degree ≥2：才改變 neighbor allocation。

因此應新增一個 outcome-free diagnostic comparator：

uniform_sewer_link_weight(c,d) = 1

用途只是拆分：

cell-link topology 造成的 redistribution；

sewer attribute weighting 造成的 redistribution。

它不得取代 P0，也不得依 Rat Radar 決定是否保留 metric weighting。

Seattle 研究支持 sewer attributes 與 baited-manhole rat presence 的關聯方向，但研究本身也明確指出仍需研究 rats 在 sewer、surface 與兩者之間的 movement drivers；它不提供 Taipei edge-transfer coefficient。
Springer Link

R12. map_propagation_corridors 必須定義數值或移除

若 corridor table 表示 step-specific synthetic transition contribution，可定義：

directed_transfer_t(c,d) =
  alpha * x_t(c) * P(c,d)


undirected_link_contribution_t({c,d}) =
  directed_transfer_t(c,d)
  + directed_transfer_t(d,c)

UI 必須稱：

synthetic cell-link contribution

不得稱：

sewer flow；

rat movement；

propagation corridor；

migration path。

如果不採此公式，則先移除 corridor artifact；不能只因為兩個 cell 有 pipe-derived link，就畫成「傳播走廊」。

4. PARAMETER_REVIEW
項目	判定	審查結論
0.25 + 0.75 * endpoint mean	CONDITIONAL	可作單一、固定、synthetic route-weight assumption；不可稱 physical conductance。其值域為 0.25–1，等於預設最大相對差異 4:1，但經 row normalization 後只決定 neighbor share，不決定 sewer bucket 總量。
alpha = 0.75	CONDITIONAL ACCEPT	可作 abstract continuation assumption；必須更名，並禁止解讀為 migration probability、速度或時間尺度。
P0 self=0.65, sewer=0.35	CONDITIONAL ACCEPT	可作 baseline bucket assumption。不是由 sewer evidence 推估，也不是 65% rats stay / 35% rats move。
P1 現行公式	REJECT	變動最大發生在 low-renewal cells，且只假設單一未知方向。必須移除或改為成對方向 sensitivity。
P2 self=.55, sewer=.35, adjacency=.10	CONDITIONAL ACCEPT	可作 generic adjacency stress test；不得稱 surface movement。需明確定義 shared-edge adjacency 與 uniform allocation。
Steps 0–8	ACCEPT WITH RESTRICTIONS	可作固定 abstract iteration horizon。所有 steps 都要輸出；不得選「最像」的一步；step 8 不得稱 final forecast、steady state 或八個時間單位。

對 recurrence：

x[t+1] = (1-alpha)s + alpha P^T x[t]
x[0]   = s

可展開為：

x[t] =
  (1-alpha) * sum_{k=0}^{t-1} alpha^k (P^T)^k s
  + alpha^t (P^T)^t s

因此每個 x[t] 是多種 path lengths 的混合，不是「所有 synthetic units 正好移動了 t 次」。

在 alpha=0.75, t=8 時：

alpha^8 = 0.100112915...

所以第 8 iteration 仍保留約 10% 的最高階 transient term。它不能被默認為 convergence。

Applied Network Science 的 cited study使用 building geometric graph 與 SIR，並改變 migration distance、spread probability 和 graph connectivity。它支持「network topology 與 assumptions 會改變模擬結果」這個一般性先例，但不支持此處的 Markov recurrence、S2 cell state、0.75 alpha 或 bucket weights。
Springer Link

London sewer baiting研究支持某些 sewer locations 可能多年重複呈現 bait activity hotspot，但這只支持空間異質性；它不提供 cell-to-cell direction、transition probability 或 transfer rate。
PubMed Central (PMC)

5. GRAPH_AND_MASS_REVIEW
5.1 Identity

Cell graph 可接受，但只能稱 coarse cell-link graph。

Raw node IDs 存在大量 coordinate conflicts，resource scoping 後仍未消除，使用 raw ID 作 topology identity 不合理。附件也顯示 geometry-derived endpoint graph 有大量 degree-1 nodes，而 cell-level profile 有 180,359 within-cell segments 與 2,685 distinct cross-cell pairs。

Pasted markdown

但 cell collapse 會引入新的假設：

同一 cell 內所有 source mass、within-cell pipes 和 cross-cell exits 可在一次 abstract iteration 內完全混合。

即使兩條 sewer subnetworks 在同一 cell 內不相連，cell model 仍可能透過共同 cell state 將它們連接。這是 cell-level mixing assumption，必須列入 limitation。

至少應產生：

cells_with_multiple_internal_geometry_components
cross_cell_links_per_internal_component
cells_where_distinct_exits_are_not_geometry_connected

這些只作 QA，不輸出 exact geometry。

5.2 Direction

Undirected cell links可以作為：

symmetric-route assumption under unknown directionality

但不能稱 conservative assumption。允許雙向 transition 可能增加原本不存在的 reverse reachability，因此它不必然保守。

應分開說明：

hydraulic flow direction 未驗證；

rat movement direction 未觀測；

所以 challenger 使用 symmetric abstract links；

這不是 actual sewer flow graph。

5.3 Missingness

兩端都需要 complete-case sewer index，會讓 attribute missingness 直接決定 graph connectivity。

必須報告：

eligible_sewer_link_count
excluded_link_count_due_to_endpoint_metric_missingness
cells_with_zero_eligible_sewer_neighbors
cells_with_one_eligible_sewer_neighbor
cells_with_two_or_more_eligible_sewer_neighbors
connected_component_count
largest_component_cell_share
source_mass_in_self_only_cells
source_mass_by_connected_component

特別是 P0 中沒有 sewer neighbor 的 cell：

self = 1.0

因為 0.35 sewer bucket 會全部回到 self。這些是 self_only_transition_rows，不是「高 retention sewer cells」。

v0.2 四項 metric gate 仍未通過，限制必須跟著 edge、state、API metadata 和 UI，而不能只放在文件。

Pasted markdown

5.4 Row sums 與 mass

令：

P[from_cell, to_cell]

且每個 from_cell：

sum_to P[from,to] = 1
P[from,to] >= 0

更新應實作為：

next[to] =
  0.25 * source_seed[to]
  + 0.75 * sum_from(
      state[from] * P[from,to]
    )

而不是依欄做 normalization。

若：

sum(source_seed) = 1
sum(x[t]) = 1

則：

sum(x[t+1])
= 0.25 * 1 + 0.75 * 1
= 1

所以 recurrence 在數學上可保 mass。問題不在公式本身，而在 transition orientation、duplicate joins 與 bucket construction。

必須額外 assert：

no negative transition values
no negative state values
no NaN
no Infinity
seed sum = 1
step 0 exactly equals seed
row sums = 1
state mass = 1
recurrence residual within frozen tolerance

現有 1e-9 mass tolerance 可接受，但 row-sum tolerance、per-cell recurrence residual tolerance及 artifact hashing precision也必須在 contract 中固定。附件目前已有 mass、row count、step range 和 no-Rat-Radar assertions 的方向，但尚不足以驗證 recurrence implementation 本身。

Pasted markdown

5.5 Determinism

FLOAT64 SUM 的 reduction order 可能產生極小差異。若要以 artifact hash 宣稱 deterministic：

優先使用 NUMERIC／BIGNUMERIC 可表達的中間值；

或在 content hash 前使用 contract-defined decimal quantization；

不要直接 hash 未量化的 floating-point serialization；

tolerance 與 rounding scale 必須在 outcome access 前鎖定。

6. NAMING_AND_UI_REVIEW
必須替換的名稱
現行名稱	問題	建議名稱
DETERMINISTIC_RELATIVE_PROPAGATION_SIMULATION	暗示真實擴散	DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION
relative_propagation_intensity	暗示實際 propagation 強度	relative_synthetic_network_state
subterrat_predictions.*	直接暗示 prediction	subterrat_simulations.*
propagation_states	暗示擴散狀態	synthetic_network_states
propagation_corridors	暗示真實路徑	schematic_cell_link_contributions
sewer_edge_conductance	暗示物理或 hydraulic conductance	synthetic_sewer_route_weight
self_retention	暗示生物 persistence	self_allocation_bucket
surface route	暗示實際 surface movement	generic_cell_adjacency_link
Primary challenger	容易被解讀為最可信模型	Baseline challenger
step	容易被解讀為時間	abstract iteration
UI 必須修正

Autoplay 預設關閉。
動畫是最強的 calendar-time／movement 暗示之一。Contract 目前設定 autoplay=true，應改為 false。

Pasted markdown

使用 cell choropleth，不使用平滑 heat kernel。
Heat interpolation 會在未建模位置創造連續 surface。

缺值與 unsupported cells 必須 hatch。
不能用低顏色或透明度讓它們看起來像低 synthetic state。

Cell-centroid links 預設關閉。
圖例固定顯示：

Schematic aggregated cell link — not pipe alignment

每個 frame 都固定顯示：

Internal synthetic network redistribution
Abstract iteration — no time mapping
Not a calibrated rat-presence probability
Not a sewer-flow or movement map
NO_TRUSTED_RESULT
Operational use prohibited

Not probability 建議改成：

Not a calibrated rat-presence probability

原因是 x 在數學上是非負、sum-to-one 的 synthetic mass vector；真正需要禁止的是把它解讀成 rat-presence probability，而不是模糊否認其 normalization structure。

UI 不得顯示：

hotspot；

spread rate；

movement；

risk；

predicted；

likely rats；

active construction；

recommended inspection；

final iteration；

convergence implies truth。

7. MINIMUM_IMPLEMENTATION_GATES
7.1 BigQuery / SQL hard gates

在任何 candidate table materialization 前，全部必須 PASS：

Clean committed Git head、review receipt、contract hash、SQL hash、parent lock、所有 input snapshot identities 完全吻合。

Contract JSON schema validation PASS。

BigQuery job referenced tables 中不存在 Rat Radar 或其 derived tables。

Authoritative cell universe：

exactly 3,420 cells；

unique cell_id；

positive eligible area；

frozen boundary/snapshot hash。

Pipe geometry：

active official records only；

valid/nonempty geometry；

full geometry traversal；

deterministic exclusion reasons；

no endpoint-only teleport route。

Edge table：

unordered pair unique；

no self-pair；

all cells belong to universe；

route multiplicity retained as QA only；

no exact geometry exported。

Sewer route weight：

both endpoint attributes non-null；

endpoint values within frozen range；

weight within [0.25,1]；

gate states attached。

Generic adjacency：

shared-edge rule locked；

corner-only touch excluded；

no out-of-universe links。

Transition matrix：

one deterministic allocation formula；

nonnegative finite values；

every cell has one complete row；

row sums within locked tolerance；

no cross-route dynamic reweighting。

Seed：

nonnegative finite values；

missing-vs-zero preserved；

positive total before normalization；

normalized sum equals 1。

State table：

unique (contract_hash, scenario_id, iteration, cell_id)；

exactly 3420 × scenario_count × 9 rows；

iteration exactly 0–8；

iteration 0 equals seed；

recurrence residual passes；

mass passes for every scenario/iteration。

P1 current formula absent。只允許 removed 或 paired-direction revision。

Quality artifact包含：

graph degree distribution；

components；

isolates/self-only cells；

source mass by component；

missingness-excluded routes；

degree-1 share；

cell mixing ambiguity；

uniform-link comparator。

Simulation dataset 不得命名為 predictions。

Dataset/view IAM 不得 public。

7.2 API hard gates

API 只接受 locked scenario enum 與 integer iteration 0–8；不能輸入任意 alpha、bucket、conductance 或 step count。

每個 response 必須包含：

contract_hash
scenario_id
abstract_iteration
normalization_scope
display_scale_max
use_state
evidence_state
operational_use
limitation_codes

API schema 不得含：

probability
risk
prediction
rat_count
rat_density
construction_active
movement_rate
calendar_time

Exact pipe geometry、exact admin coordinates、report rows 不得出現在 serializer 前的 API projection；不能只依賴 React 隱藏。

Cell-link endpoint 只能是 aggregated cell IDs/centroids。

Raw unit-mass state若需要供 QA，必須放在 restricted QA endpoint；一般 map endpoint只回 fixed-scale synthetic state。

Response 中不能出現 frame-relative value卻缺少 normalization metadata。

API integration test 必須證明沒有 Rat Radar table dependency。

API route 不得掛在 /predictions、/risk 或 /forecast namespace。

No public cache、public export 或 public sharing endpoint。

7.3 React hard gates

Internal authorization/feature gate PASS。

Autoplay default false。

使用 discrete cell polygons；禁止 kernel heatmap、spatial interpolation 或跨 missing-cell smoothing。

Global locked legend scale；若非 global，必須禁止跨 frame comparison。

Missing/blocked/support-limited cells 使用 hatch 和 limitation code。

Schematic links default hidden，並永久標記不是 pipe alignment。

Persistent governance banner不可關閉。

Scenario名稱不得暗示 best、most likely 或 validated。

Step顯示為 Abstract iteration 0…8，不使用 clock、date、week、day 或 speed controls。

不得有 dispatch、inspection priority、alert 或 intervention action。

UI snapshot/string tests掃描 forbidden terminology。

Production/public build中 challenger route必須不可達。

8. ALLOWED_CLAIMS 與 FORBIDDEN_CLAIMS
ALLOWED_CLAIMS

可以說：

這是一個 deterministic、internal、synthetic network redistribution simulation。

Frozen food score 被轉換為 area-weighted synthetic seed。

Official pipe geometries只用來建立 aggregated S2 cell links。

Sewer attribute index只作 synthetic route weighting，且其四項未通過 gate 的限制仍然存在。

P0/P1/P2 的差異反映固定 assumptions，不反映哪個 scenario 更接近真實鼠患。

Row-stochastic transition 和 recurrence 在 QA tolerance 內保存 synthetic unit mass。

某 cell 在固定 normalization 下具有較高 relative_synthetic_network_state。

Graph topology、source distribution、missingness、bucket allocation 和 route weights共同決定輸出。

Uniform-link comparator可描述 metric weighting 相對於純 topology 帶來多少數值差異。

結果可用於檢查 scenario mechanics、graph fragmentation、mass conservation 和 UI safety。

Evidence state仍是 NO_TRUSTED_RESULT。

FORBIDDEN_CLAIMS

不得說：

某 cell 有較高 rat-presence probability。

某 cell 有較多 rats、較高 population density 或較高 public-health risk。

synthetic state 是鼠群實際分布。

某條 cell link 是 rat movement corridor。

cell-centroid line 是 sewer pipe location。

g(c,d) 是真實 sewer conductance、flow capacity 或 migration probability。

Undirected edge 代表 rats 可實際雙向通行。

Iteration 1–8 對應天、週、月、距離或移動速度。

Iteration 8 是 forecast、final state、equilibrium 或 long-term outcome。

Urban renewal records 表示 active construction。

Renewal context 造成 rats displacement、retention、migration 或 disturbance。

P0 是最可信、最符合臺北或最接近 Rat Radar 的 scenario。

Rat Radar concordance 可以選 alpha、weights、steps、graph、P1 direction 或 scenario。

Higher concordance 表示模型已 validated。

Lower concordance 表示某 literature-directed feature應被移除。

Challenger 可以用於巡查、投藥、dispatch、資源配置或公開風險溝通。
