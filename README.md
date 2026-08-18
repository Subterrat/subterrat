# SubTerrat

SubTerrat 是臺北結構性見鼠通報熱點排序研究。現階段以餐飲／市場、地下水道環境與範圍有限的市有未利用建物資料建立可重現的聚合網格；輸出是 `score`、`rank` 與 top-area flag，不是鼠類存在機率、疾病風險或自動派工依據。

## 目前狀態

| 範圍 | Repository 內可確認的狀態 | 主張上限 |
| --- | --- | --- |
| v0.1 ranking | 有 contracts、Python scripts、BigQuery SQL、freeze／map payload 流程與測試 | Deterministic layer ranking；`NO_TRUSTED_RESULT` |
| v0.2 sewer metrics | 有 outcome-free candidate contract、profiling／export scripts、SQL 與 runbook | Data-gated candidate；不是 frozen composite |
| FastAPI | 已實作唯讀 public MVP subset，並有 local endpoint tests | `IMPLEMENTED_UNVALIDATED`；沒有 production 證據 |
| Flutter Web | 可讀 FastAPI map subset；`API_BASE` 留空時改用 synthetic demo | Demo／UI 行為，不是臺北研究 Evidence |
| Cloud Run | Repository 有 frontend container／Cloud Build 設定 | 只證明 deployment artifacts 存在；不證明已部署或目前可用 |
| T1／field validation | 尚無 repository-owned trusted receipt | 不得宣稱 prospective validity、rat-presence probability 或治理成效 |

見鼠雷達資料只能在 T0 freeze 後作 validation comparison，不得進入 feature、label、training、calibration、權重或 model selection。對外公開、現場巡檢、派工與介入仍需人工核准。

## 快速驗證

Python pipeline／API：

```bash
uv sync --group dev
PYTHONPATH=. uv run python -m unittest discover -s tests -v
```

Flutter：

```bash
flutter pub get
flutter test
```

本機地圖執行與 Google Maps key 設定請見 [`docs/FRONTEND.md`](docs/FRONTEND.md)。

## 文件入口

- [`docs/BELIEF.md`](docs/BELIEF.md)：專案焦點、主張上限與可反證條件。
- [`docs/HARNESS_ARCHITECTURE.md`](docs/HARNESS_ARCHITECTURE.md)：Evidence、Belief、Decision、Action、Feedback 與治理邊界。
- [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md)：FastAPI target contract、目前實作範圍與 deferred endpoints。
- [`docs/V0_1_RUNBOOK.md`](docs/V0_1_RUNBOOK.md)：v0.1 layer ranking、freeze 與 validation-only 流程。
- [`docs/V0_2_RUNBOOK.md`](docs/V0_2_RUNBOOK.md)：v0.2 sewer candidate pipeline。
- [`docs/FRONTEND.md`](docs/FRONTEND.md)：Flutter Web、synthetic demo、API 串接與 frontend container 邊界。

若文件與實作或證據衝突，先依 `docs/BELIEF.md` 與 `docs/HARNESS_ARCHITECTURE.md` 收斂主張，再以 contracts、tests 與指定環境的直接證據確認狀態；不能用 README 或部署設定替代 runtime／production proof。
