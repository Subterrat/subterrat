# SubTerrat Agent Guide

## 開始工作前

- 先閱讀 `HARNESS_ARCHITECTURE.md`；它是產品、Evidence、Belief、Decision、Action、Feedback 與治理邊界的候選權威。
- 涉及架構、Belief、Agent 權限、Ground Truth、公開／內部資料或跨模組決策時，使用 `[route:architecture]`。
- 目前唯一宣告的 path route 僅涵蓋 `AGENTS.md` 與 `HARNESS_ARCHITECTURE.md`；新增程式或目錄後必須重新執行 `$coh:set-up` 更新 Model。

## 證據與行動邊界

- 明確區分 Evidence、Belief、Decision、Operational State 與 Ground Truth。
- 在臺北 E2／E3 標籤與 calibration 尚未建立前，不得把風險 score 稱為 probability。
- 派工、公共衛生升級、現場介入與對外公開需要人工核准。
- 目前沒有 repository-owned Sensor 或 validation receipt；不得宣稱 `TRUSTED_RECEIPT`，應回報 `NO_TRUSTED_RESULT`。
- 對 static、runtime、browser、live-provider、production 與 human-review 證據分層陳述，不得跨層推論。

## 維護觸發

當 source layout、資料契約、Model card、Operations runbook、Sensor、CI、provider、deployment、Agent 權限或公開政策改變時，重新檢查 `HARNESS_ARCHITECTURE.md` 與 `.coh/model.json`。
