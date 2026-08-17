# SubTerrat Hotspot Lab

Simple React internal research viewer for
`map_hotspot_cells_v0_3_internal_simulation` through a disabled-by-default
FastAPI route. Its default view renders a metric-weighted Leaflet heat surface
from aggregate-cell centroids on an OpenStreetMap basemap; an explicit cell-audit
mode preserves the source polygons and coverage. It does not require a map token.

## Run locally

### Current read-only BigQuery preview

The checked-in local fixture contains all 3,420 analysis cells from BigQuery job
`devjam26aug17tpe-1270:asia-east1.bquxjob_24ad5cf9_1a011d71c37`. Of these,
1,589 have the complete-case v0.3 composite and 1,831 remain explicit missing
support. Run it without the backend:

```bash
cd web/hotspot-lab
npm ci
VITE_PREVIEW_DATA_URL=/data/v0_3_composite_preview.json npm run dev
```

The fixture is `READ_ONLY_PREVIEW_UNCOMMITTED`, not the locked serving contract.
Its SHA-256 is
`b806fda5fdb7293972da77c6aa8e587088672a829f5f7237880f9b48556a7203`.

### Locked-table API mode

Start the API from the repository root:

```bash
export LAB_V03_ENABLED=true
export PUBLIC_CORS_ORIGINS=http://127.0.0.1:5173
export BQ_V03_TABLE=map_hotspot_cells_v0_3_internal_simulation
uvicorn services.hotspot_api.public_app:app --host 127.0.0.1 --port 8080
```

Then run the viewer without `VITE_PREVIEW_DATA_URL`:

```bash
cd web/hotspot-lab
npm ci
npm run dev
```

Set `VITE_API_BASE_URL` only when the API is not at `http://127.0.0.1:8080`.

The default basemap uses the official interactive-view URL
`https://tile.openstreetmap.org/{z}/{x}/{y}.png` and keeps the required visible
OpenStreetMap attribution. Override both values together when switching provider:

```bash
export VITE_BASEMAP_TILE_URL='https://example.test/{z}/{x}/{y}.png'
export VITE_BASEMAP_ATTRIBUTION='Provider attribution required by its licence'
```

The lab does not prefetch, bulk-download, or offer offline tiles. The default is
for normal human interactive use only; see the
[OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/).

## Evidence boundary

- v0.3 is an ordinal internal simulation, not a probability, risk prediction,
  frozen model, or trusted result.
- Rat Radar is absent from the feature and score path.
- The five-metric sewer attribute index includes blocked/conditional diagnostics.
- The renewal component is an approved-rebuilding administrative-site proxy with
  blocked reuse/taxonomy/temporal gates, not proof of construction or disturbance.
- The 34 px heat kernel is render-only visual smoothing. It is not biological
  diffusion, temporal propagation, or a new model output.
- `NO_TRUSTED_RESULT`; operational use and public release are prohibited.
