# v0.3 BigQuery + React internal-simulation runbook

This pipeline never reads Rat Radar in the feature or score path. It does not
overwrite v0.1/v0.2 tables or the pre-review v0.3 candidate metrics. Composite
materialization fails closed until a reviewed specification has a clean committed
Git identity.

## 0. Preconditions

- Project `devjam26aug17tpe-1270`, location `asia-east1`
- v0.2 source table
  `subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
- GPT Pro verdict recorded in `docs/V0_3_GPT_PRO_REVIEW.md`
- Contract state is `GPT_PRO_REVISED_AWAITING_COMMITTED_SPECIFICATION_LOCK`
- Urban-renewal reuse, taxonomy, temporal-meaning, and completeness gates remain
  blocked; operational use and publication remain prohibited

## 1. Export and load the source rows

```bash
PYTHONPATH=. uv run python scripts/export_taipei_urban_renewal_bq.py \
  '臺北市都市更新地圖_都更資料.csv' \
  --snapshot-date 2026-08-17 \
  --source-uri https://www.ur.org.tw/classroom/map_view/11 \
  --output artifacts/urban-renewal-v0.3/urban_renewal_v0_3.ndjson \
  --manifest artifacts/urban-renewal-v0.3/urban_renewal_v0_3.manifest.json
```

Expected manifest:

- 2,365 rows and unique row hashes
- 250 included source rows
- source file SHA-256
  `b1743a3d63105c5d1ea25251e1d881825c40ef7a905d902ebd0d455685c9cde2`
- source snapshot
  `f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e`
- `outcome_data_read = false`

The supplied date is repository-observed, not a provider publication date.

Create the raw objects and load an empty stage exactly once. Do not append to a
non-empty stage and do not replace a live table without a separate confirmation.

```bash
bq --location=asia-east1 query --use_legacy_sql=false \
  < sql/structural/13_create_urban_renewal_v0_3_raw.sql

bq --location=asia-east1 load \
  --source_format=NEWLINE_DELIMITED_JSON \
  subterrat_raw.urban_renewal_point_v0_3_load_stage \
  artifacts/urban-renewal-v0.3/urban_renewal_v0_3.ndjson \
  contracts/bigquery_urban_renewal_v0_3_schema.json

bq --location=asia-east1 query --use_legacy_sql=false \
  --parameter=source_snapshot_id::f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e \
  < sql/structural/14_merge_and_curate_urban_renewal_v0_3.sql
```

SQL 14 fails closed on row identity, file hash, coordinate validity, phase counts,
or snapshot mismatch. The live raw scaffold has four older nullable columns that
the minimized exporter and curated table never write; removing them is a separate
destructive schema action.

## 2. Materialize component-only administrative-site metrics

SQL 15 creates new versioned tables, deduplicates 250 included rows into 248
normalized source-record-number sites, and creates 0/150/300 m cell-footprint
buffer metrics. It does not materialize the composite and does not read outcomes.

```bash
bq --location=asia-east1 query --use_legacy_sql=false \
  < sql/structural/15_materialize_urban_renewal_metrics_v0_3.sql
```

Verify:

```sql
SELECT
  COUNT(*) AS sites,
  SUM(source_record_count) AS source_rows,
  COUNTIF(source_record_count > 1) AS duplicate_site_keys,
  COUNTIF(representative_geom_wgs84 IS NULL) AS null_geometries
FROM
  `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_admin_site_v0_3_internal_simulation`;

SELECT
  analysis_window_m,
  COUNT(*) AS cells,
  COUNTIF(admin_site_count > 0) AS nonzero_cells,
  SUM(admin_site_count) AS total_cell_matches,
  MAX(admin_site_count) AS max_count,
  COUNTIF(
    admin_site_count = 0
    AND admin_site_empirical_percentile != 0
  ) AS invalid_zero_percentiles
FROM
  `devjam26aug17tpe-1270.subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
GROUP BY analysis_window_m
ORDER BY analysis_window_m;
```

Expected site QA: `sites=248`, `source_rows=250`, `duplicate_site_keys=2`,
`null_geometries=0`; 247/248 sites match analysis cells at each registered
window. The observed total cell matches are 247, 971, and 2,102 at 0, 150, and
300 m respectively, with zero invalid zero-percentile rows.

## 3. Commit and derive artifact identity

Do not continue until the revised code is committed by explicit user authorization
and `git status --short` is empty.

```bash
git rev-parse HEAD
shasum -a 256 docs/V0_3_GPT_PRO_REVIEW.md
shasum -a 256 contracts/hotspot_scenario_v0_3_candidate.json
shasum -a 256 sql/structural/1[5-9]_*.sql | shasum -a 256
```

Record the exact four values as `specification_git_head`, review receipt hash,
contract hash, and SQL hash. SQL 16 and SQL 19 validate their shape and persist
them on every artifact row.

## 4. Materialize and QA the internal simulation

Set local shell variables to the committed values, then run SQL 16:

```bash
bq --location=asia-east1 query --use_legacy_sql=false \
  --parameter=specification_git_head::"$V03_GIT_HEAD" \
  --parameter=repository_state::COMMITTED_SOURCE \
  --parameter=review_verdict::REVISE_BEFORE_SIMULATION \
  --parameter=review_receipt_sha256::"$V03_REVIEW_SHA" \
  --parameter=scenario_contract_sha256::"$V03_CONTRACT_SHA" \
  --parameter=scenario_sql_sha256::"$V03_SQL_SHA" \
  --parameter=urban_renewal_source_snapshot_id::f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e \
  < sql/structural/16_build_hotspot_scenarios_v0_3.sql

bq --location=asia-east1 query --use_legacy_sql=false \
  < sql/structural/17_hotspot_scenario_quality_v0_3.sql

bq --location=asia-east1 query --use_legacy_sql=false \
  < sql/structural/18_materialize_map_payload_v0_3.sql
```

Verify:

```sql
SELECT
  variant_id,
  scoreable_cell_count,
  scoreable_area_share,
  selected_area_share,
  threshold_tie_cell_count,
  specification_state,
  use_state,
  evidence_state,
  operational_use,
  public_release_ready
FROM
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_quality_v0_3_internal_simulation`
ORDER BY variant_id;

SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT cell_id) AS unique_cells,
  COUNTIF(v0_3_simulation_index IS NOT NULL) AS scoreable_cells,
  COUNTIF(calibrated_probability IS NOT NULL) AS nonnull_probabilities,
  COUNTIF(specification_state != 'LOCKED') AS invalid_specification_states,
  COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') AS invalid_use_states,
  COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') AS invalid_evidence_states,
  COUNTIF(operational_use != 'PROHIBITED') AS invalid_operational_states
FROM
  `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_v0_3_internal_simulation`;
```

Expected: `rows=unique_cells=3420`, all invalid/non-null probability counts are
zero, and every variant remains unavailable for public or operational use.

SQL 16／17 intentionally retain seven outcome-free variants for QA and frontend
preview. Rat Radar must not be used to select, tune, rerank, or attribute among
those variants. Only the v0.3 composite and frozen food-only v0.1 baseline may
enter the later concordance lock.

## 5. Run the local API and React lab

```bash
export LAB_V03_ENABLED=true
export PUBLIC_CORS_ORIGINS=http://127.0.0.1:5173
export BQ_V03_TABLE=map_hotspot_cells_v0_3_internal_simulation
uvicorn services.hotspot_api.public_app:app --host 127.0.0.1 --port 8080
```

```bash
cd web/hotspot-lab
npm ci
npm run dev
```

Open `http://127.0.0.1:5173/`. The separate route is:

```text
GET /api/v1/lab/v0.3/cells?bbox=121.45,24.95,121.67,25.22&limit=1500
```

`LAB_V03_ENABLED` defaults to false. The UI must display locked/pending-lock,
internal-only, untrusted-evidence, and operational-prohibition states. It shows
aggregate polygons only, not precise admin sites or report rows. The default
Leaflet basemap uses `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, keeps
visible OpenStreetMap attribution, and must not be used for prefetch, bulk
download, automated pan/zoom, or offline tiles. Set `VITE_BASEMAP_TILE_URL` and
`VITE_BASEMAP_ATTRIBUTION` together to switch providers. The default 34 px
metric heat surface is render-only visual smoothing; use `Cell audit grid` to
inspect authoritative polygon values and missingness.

## 6. Lock and run one-shot concordance

Only after the committed live rows pass QA, execute SQL 19 with the same seven
parameters used by SQL 16. This creates the lock manifest; it does not make the
simulation public, operational, trusted, predictive, or prospective.

SQL 19 copies exactly two variants into the concordance lock: the v0.3
equal-group composite and frozen food-only v0.1 baseline. The remaining five
diagnostic variants stay outside the lock and cannot receive outcome results.

Then render the one-shot SQL locally:

```bash
PYTHONPATH=. uv run python scripts/render_rat_radar_v0_3_retrospective_sql.py \
  /path/to/rat-radar.csv \
  > artifacts/rat-radar-v0.3-concordance.sql
```

The generated SQL persists anonymous report hashes and S2 cells only. It creates:

- one primary citywide row for the v0.3 equal-group composite, with frozen
  food-only v0.1 metrics in baseline columns;
- one secondary exact-common-support row for the same composite and baseline.

Food, sewer-attribute, and approved-rebuilding layers may remain separate in
the frontend for explanation. They must not receive separate Rat Radar
concordance results, drive variant selection or tuning, or support component
attribution.

Do not use results to change any specification. Do not call the exercise
validation, prediction, risk estimation, or component attribution.
