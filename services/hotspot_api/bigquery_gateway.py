from __future__ import annotations

from typing import Any, Iterable

from google.cloud import bigquery


class BigQueryGateway:
    """Thin wrapper over google.cloud.bigquery.Client.

    The underlying client is constructed lazily, on first actual query —
    not at injection time. Several routes (e.g. /healthz) resolve a
    repository through FastAPI's dependency injection but never call into
    BigQuery; eager client construction would require GCP credentials just
    to answer those, which breaks local dev and is needless production risk.

    All SQL is parameterized by callers (never string-formatted values from
    request input) — this class does not itself sanitize anything, and never
    issues `SELECT *` (GitHub issue #4 "Query 與效能要求").
    """

    def __init__(self, project_id: str, location: str) -> None:
        self._project_id = project_id
        self._location = location
        self._client: bigquery.Client | None = None

    def _get_client(self) -> bigquery.Client:
        if self._client is None:
            self._client = bigquery.Client(
                project=self._project_id, location=self._location
            )
        return self._client

    def query(
        self,
        sql: str,
        parameters: Iterable[bigquery.ScalarQueryParameter] | None = None,
    ) -> list[dict[str, Any]]:
        job_config = bigquery.QueryJobConfig(query_parameters=list(parameters or []))
        rows = self._get_client().query(sql, job_config=job_config).result()
        return [dict(row.items()) for row in rows]
