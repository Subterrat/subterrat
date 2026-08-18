# SubTerrat Agent Guide

## 開始工作前

- 先閱讀 `docs/BELIEF.md` 固定專案焦點，再閱讀 `docs/HARNESS_ARCHITECTURE.md` 了解 Evidence、Belief、Decision、Action、Feedback 與治理邊界。
- 涉及產品方向或失焦判斷時使用 `[route:belief]`；涉及架構、Belief record、Agent 權限、Ground Truth、公開／內部資料或跨模組決策時使用 `[route:architecture]`。
- 目前唯一宣告的 path route 僅涵蓋 `AGENTS.md`、`docs/BELIEF.md` 與 `docs/HARNESS_ARCHITECTURE.md`；新增程式或目錄後必須重新執行 `$coh:set-up` 更新 Model。

## 證據與行動邊界

- 明確區分 Evidence、Belief、Decision、Operational State 與 Ground Truth。
- 在臺北 E2／E3 標籤與 calibration 尚未建立前，不得把風險 score 稱為 probability。
- 派工、公共衛生升級、現場介入與對外公開需要人工核准。
- 目前沒有 repository-owned Sensor 或 validation receipt；不得宣稱 `TRUSTED_RECEIPT`，應回報 `NO_TRUSTED_RESULT`。
- 對 static、runtime、browser、live-provider、production 與 human-review 證據分層陳述，不得跨層推論。

## 測試資料夾

`test/` 與 `tests/` 是兩個獨立資料夾，分屬不同工具鏈，不要合併：

- `test/`：Flutter／Dart，`flutter test` 預設只認這個名稱。
- `tests/`：Python tests；repository-owned 驗證命令是 `PYTHONPATH=. uv run python -m unittest discover -s tests -v`。若開發環境另有 pytest，`pyproject.toml` 的 `[tool.pytest.ini_options]` 會把 discovery 固定在 `tests/`，但 pytest 目前不在 `uv.lock` 的 dev dependencies 內。

新增測試一律照語言放進對應資料夾，不要互相搬移。

## 維護觸發

當 product belief、source layout、資料契約、Model card、Operations runbook、Sensor、CI、provider、deployment、Agent 權限或公開政策改變時，重新檢查 `docs/BELIEF.md`、`docs/HARNESS_ARCHITECTURE.md` 與 `.coh/model.json`。
