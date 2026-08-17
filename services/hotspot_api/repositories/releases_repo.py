from __future__ import annotations

from google.cloud import bigquery

from services.hotspot_api.bigquery_gateway import BigQueryGateway


class ReleasesRepository:
    """Resolves the single release this service serves: the configured
    `RELEASE_ID` (GitHub issue #4), not the richer human-approved
    `release_manifest` publish workflow docs/API_CONTRACT.md section 6
    describes — that table does not exist yet. Readability is proven by
    actually querying the serving table for that freeze_id, never assumed.
    """

    def __init__(
        self, gateway: BigQueryGateway, table_ref: str, release_id: str
    ) -> None:
        self._gateway = gateway
        self._table_ref = table_ref
        self._release_id = release_id

    def current_release_id(self) -> str:
        return self._release_id

    def is_readable(self, release_id: str) -> bool:
        if release_id != self._release_id:
            return False
        sql = f"""
        SELECT 1
        FROM `{self._table_ref}`
        WHERE freeze_id = @release_id
        LIMIT 1
        """
        parameters = [
            bigquery.ScalarQueryParameter("release_id", "STRING", release_id)
        ]
        return bool(self._gateway.query(sql, parameters))
