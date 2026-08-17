# SubTerrat Belief

> Project focus contract — what we currently believe, why it matters, and what evidence could change it.

## 1. 這份文件的角色

本文件固定 SubTerrat 的核心工作假設，避免專案因模型、地圖、Agent、A2A 或雲端元件而失焦。

Belief 是可被證據更新的工作信念，不是 Ground Truth、產品成效宣告或自動行動授權。完整 Evidence、Belief、Decision、Action 與 Feedback 邊界以 `docs/HARNESS_ARCHITECTURE.md` 為準。

## 2. North Star Belief

> **SubTerrat 相信：城市鼠害治理應被設計成一個以地下管網資產為分析單位、由證據持續更新、以巡檢決策為輸出、並由現場結果校正的閉環；而不是一張把未驗證通報直接畫成紅色熱區的地圖。**

目前狀態：`INFERRED`。

這個信念具有文獻與問題機制支持，但在取得臺北 E2／E3 正負樣本、完成時空外推驗證及實際巡檢回饋前，不得提升為 `OBSERVED`。

## 3. Supporting Beliefs

### B1 — 管網是結構性 prior，不是真相

管線年代、管徑、深度、類型、材質、地勢與拓撲可能幫助排序巡檢位置；它們不能單獨證明近期鼠類活動，更不能證明疾病風險。

### B2 — 民眾通報是動態 Evidence，不是 Ground Truth

通報受能見度、媒體注意、通報意願與重複事件影響。它可以更新 Recent Activity Belief，但只有標準化現場觀測、捕捉或檢驗才能建立較高等級標籤。

### B3 — 產品輸出是可解釋的巡檢優先序

MVP 應回答「有限人力下一步去哪裡、為什麼、證據多強、需要誰核准」，而不是追求一個無法校準的鼠患機率或漂亮 Heatmap。

### B4 — 沒有 Feedback 就沒有成立的 Agent

巡檢正例、負例、介入措施、復查與復發必須回到系統。無法接收結果並更新狀態的設計，只是資料展示或一次性模型，不是持續治理 Agent。

### B5 — Belief 永遠不能越權成為 Action

正式派工、公共衛生升級、現場介入與對外公開需要人工核准。模型分數不得自動升級為 Ground Truth，也不得直接指認住宅、店家或感染區。

## 4. Focus Test

任何新功能、資料、模型或協定進入 MVP 前，必須回答：

1. 它改善哪一個巡檢或治理決策？
2. 它提供的是 Evidence、Belief、Decision、Action 還是 Feedback？
3. 它的證據等級、時間窗、不確定度與失效方式是什麼？
4. 它是否保留人工核准、責任歸屬與稽核紀錄？
5. 現場結果如何回流，並能否證明它比簡單 baseline 更有價值？

無法回答上述問題的項目，不進入 MVP。Google 元件、GNN、LLM、A2A、Flutter、Looker 或其他技術都不因技術名稱本身取得優先權。

## 5. 可反證條件

發生下列任一情況時，必須降低或改寫相關 Belief，而不是替既有方向找理由：

- 在時間向前與 spatial holdout 中，管線特徵無法穩定超越歷史通報或土地使用 baseline。
- 相同巡檢資源下，Top-K 建議沒有提高 verified yield，或只重複既有通報偏差。
- 無法取得臺北 E2 正負 Ground Truth；此時只能定位為文獻先驗風險篩選，不宣稱 rat-presence prediction。
- System-generated task、公開地圖或媒體注意造成 feedback contamination，且無法可靠隔離。
- 隱私、基礎設施安全、商譽或錯誤介入風險高於預期治理效益。

## 6. 明確非目標

- 預測個人疾病感染。
- 精確估算城市鼠群數量。
- 自動投藥、修繕、派工或對外通報。
- 公開未驗證的精確住宅、店家、人孔或管段風險。
- 為了展示 Agent 而拆分多個沒有獨立責任與狀態的假 Agent。
- 為了使用特定技術而改寫問題定義。

## 7. 更新規則

- Owner：Project／Architecture owner。
- Trigger：目標、Ground Truth、決策 policy、Agent 權限、資料來源、模型驗證或公開政策改變。
- 每次更新必須記錄支持 Evidence、反證 Evidence、狀態變化與影響的決策。
- 衝突證據保留為 `CONFLICTING`；不得靜默刪除，也不得由模型或助手自動改寫本文件。
