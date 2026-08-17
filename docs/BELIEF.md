# SubTerrat Belief

> Project focus contract — what we currently believe, why it matters, and what evidence could change it.

## 1. 這份文件的角色

本文件固定 SubTerrat 的核心工作假設，避免專案因模型、地圖、Agent、A2A 或雲端元件而失焦。

Belief 是可被證據更新的工作信念，不是 Ground Truth、產品成效宣告或自動行動授權。完整 Evidence、Belief、Decision、Action 與 Feedback 邊界以 `docs/HARNESS_ARCHITECTURE.md` 為準。

## 2. North Star Belief

> **SubTerrat 相信：餐飲／傳統市場密度、地下水道環境與廢棄建築可形成一張不使用見鼠通報調權的臺北結構性風險地圖；其第一階段價值必須由之後發生、且經見鼠雷達審核通過的民眾見鼠通報做時間向前比對，而不是把既有通報重新畫成一張看似預測的熱區圖。**

目前狀態：`INFERRED`。

這個信念具有 Seattle 下水道研究、都市食源與棲地機制支持，但目前只能支持「民眾見鼠通報熱點預測」研究。見鼠雷達通報仍受能見度、人口、媒體注意與通報意願影響；在取得臺北 E2／E3 正負樣本、完成時空外推驗證及現場巡檢回饋前，不得把輸出稱為實際鼠類存在機率或臺北鼠患 Ground Truth。

## 3. Supporting Beliefs

### B1 — 第一版固定三組結構性 Evidence

第一版只使用三組模型輸入：餐飲區密度（含傳統市場）、地下水道環境，以及廢棄建築。地下水道以臺北官方人孔、陰井與其他可定位節點作資料連接單位，但 feature eligibility 僅限 Seattle 研究明確支持的五類：污水／雨水系統類型、高程、相連管線深度、相連管線管徑與相連管線年代。只有欄位語義、端點 join 與 coverage 通過 data gate 的項目才能進分數；人孔／陰井密度、最近人孔距離、local topology 或其他自行衍生 proxy 不進第一版。資料中的「人孔／陰井」不等於已證明老鼠可通行的孔洞，這些輸入也只能形成文獻先驗結構性 score，不能單獨證明近期鼠類活動或疾病風險。

截至 2026-08-17，GCP 已建立三組 `model_input_contract`，但三者均為 `training_eligible_now=false`。餐飲／市場已有 20,336 個官方名錄 candidate points，仍缺現行營業語義、market footprint、cell density 與 coverage gate；下水道只有 system type 可用，高程及相連管線欄位仍受阻；廢棄建築目前只有 19 筆「市有尚未利用建物」address-only candidate，不能代表 citywide abandoned-building construct。這些差距不得用新 proxy 或調整主張掩蓋。

Google Places／Maps content 明確排除於訓練、測試、驗證與 spatial feature construction。Google Maps Platform 條款禁止使用 Places 座標進行 point-in-polygon，也禁止用 Google Maps Content 改善機器學習模型；可保存的 `place_id` 只可作 Google Maps operational reference，不是模型特徵。餐飲／市場輸入仍以可版本化、可保存的臺北市官方開放資料為準。

第一版所稱的「模型」是預先鎖定、可重現的 deterministic prior score，不是用既有見鼠通報擬合的 supervised model，因此不會有 BigQuery ML 或 Vertex AI training job。Google Maps 只顯示從 BigQuery frozen predictions 匯出的聚合網格；待取得封存後的新 outcome 或 E2／E3 標籤、並另立 supervised challenger 契約後，才可啟動真正的 fitted training。

### B2 — 見鼠雷達是第一階段 outcome，不是鼠群 Ground Truth

第一階段的主要 outcome 是臺北範圍內、指定未來觀測窗中，見鼠雷達審核通過且 `類型=Rat` 的通報。`Approved` 表示通過該平台的 AI 初篩與志工人工複審，不等於專業人員現場確認；有合格照片或獨立交叉訊號者最高仍只列為 E1。`Pending` 不進入主要 outcome，`Poison` 是疑似投藥訊號而非見鼠標籤。

目前 BigQuery 只保存 `NOT_FROZEN` 的 outcome contract，未匯入通報：見鼠雷達公開再利用授權、T0／T1 起訖、review finalization 與 status-history ingestion 尚未鎖定，故 `ingestion_allowed=false`。

### B3 — 先封存 T0，再觀察 T1

第一個可反證實驗必須先封存 T0 的資料快照、特徵定義、模型／規則版本、權重與預測地圖，之後才取得 T1 觀測窗的見鼠雷達 outcome。既有通報可作 retrospective check；由於團隊已看過現有見鼠地圖，不得把它描述為完全盲化的乾淨驗證，也不得以肉眼看起來相似作為主要成功標準。真正的 prospective holdout 必須使用封存之後的新通報。

### B4 — 通報相符只證明通報熱點相符

模型與見鼠雷達的空間相符，只能支持「預測到民眾通報分布」；它也可能反映人口、步行量、媒體注意或通報習慣。第一輪以 frozen Top-K 捕捉未來合格通報的比例與 food-only baseline 增益評估，不以目前地圖的視覺相似度評分。後續若要宣稱實際鼠類活動預測，仍需標準化巡檢的正例、負例、介入、復查與復發資料。

### B5 — 投藥是介入，不是結構性風險證據

只有能確認為鼠類防治用途，且具位置、日期、措施類型與來源的投藥紀錄，才能作為 treatment exposure 用於分層或敏感度分析；不得把投藥點直接當成鼠類活動標籤。見鼠雷達的 `Poison` 通報只列為低等級疑似介入訊號。臺北市戶外環境噴藥日程僅證明一般戶外環境消毒安排，未證明使用滅鼠餌劑，因此不納入鼠類投藥資料。

### B6 — Belief 永遠不能越權成為 Action

正式派工、公共衛生升級、現場介入與對外公開需要人工核准。模型分數不得自動升級為 Ground Truth，也不得直接指認住宅、店家或感染區。

## 4. Focus Test

任何新功能、資料、模型或協定進入 MVP 前，必須回答：

1. 它改善哪一個研究判斷、巡檢或治理決策？
2. 它提供的是 Evidence、Belief、Decision、Action 還是 Feedback？
3. 它的證據等級、時間窗、不確定度與失效方式是什麼？
4. 它是否保留人工核准、責任歸屬與稽核紀錄？
5. T1 outcome 或未來現場結果如何回流，並能否證明它比簡單 baseline 更有價值？

無法回答上述問題的項目，不進入 MVP。Google 元件、GNN、LLM、A2A、Flutter、Looker 或其他技術都不因技術名稱本身取得優先權。

## 5. 可反證條件

發生下列任一情況時，必須降低或改寫相關 Belief，而不是替既有方向找理由：

- 封存的 T0 地圖在 T1 outcome 上無法穩定超越餐飲密度單一特徵、人口／通報機會或其他簡單 baseline。
- 模型表現主要由人口、可見度、媒體注意或通報參與差異解釋，無法隔離結構性風險訊號。
- 無法取得具時間版本的餐飲／市場、地下水道與廢棄建築資料，因而不能證明特徵早於 outcome。
- 無法取得臺北 E2 正負 Ground Truth；此時只能定位為文獻先驗風險篩選，不宣稱 rat-presence prediction。
- System-generated task、公開地圖或媒體注意造成 feedback contamination，且無法可靠隔離。
- 隱私、基礎設施安全、商譽或錯誤介入風險高於預期治理效益。

## 6. 明確非目標

- 預測個人疾病感染。
- 精確估算城市鼠群數量。
- 把見鼠雷達通報熱點稱為實際鼠群密度、實際鼠患機率或地下鼠群 Ground Truth。
- 由模型決定滅鼠餌劑種類、劑量或投放位置。
- 自動投藥、修繕、派工或對外通報。
- 公開未驗證的精確住宅、店家、人孔或管段風險。
- 為了展示 Agent 而拆分多個沒有獨立責任與狀態的假 Agent。
- 為了使用特定技術而改寫問題定義。

## 7. 更新規則

- Owner：Project／Architecture owner。
- Trigger：目標、Ground Truth、決策 policy、Agent 權限、資料來源、模型驗證或公開政策改變。
- 每次更新必須記錄支持 Evidence、反證 Evidence、狀態變化與影響的決策。
- 衝突證據保留為 `CONFLICTING`；不得靜默刪除，也不得由模型或助手自動改寫本文件。
