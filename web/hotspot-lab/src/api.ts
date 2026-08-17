import type {
  LabCellFeature,
  LabFeatureCollection,
  NetworkCellsResponse,
  NetworkLinksResponse,
  NetworkScenarioId,
} from "./types";

const TAIPEI_BBOX = "121.45,24.95,121.67,25.22";

export async function fetchAllLabCells(
  apiBaseUrl: string,
  signal?: AbortSignal,
): Promise<LabCellFeature[]> {
  const features: LabCellFeature[] = [];
  let pageToken: string | null = null;
  let pageCount = 0;

  do {
    const url = new URL("/api/v1/lab/v0.3/cells", apiBaseUrl);
    url.searchParams.set("bbox", TAIPEI_BBOX);
    url.searchParams.set("limit", "1500");
    if (pageToken) url.searchParams.set("page_token", pageToken);

    const response = await fetch(url, { signal });
    if (!response.ok) {
      const body = (await response.json().catch(() => null)) as
        | { detail?: string }
        | null;
      throw new Error(body?.detail ?? `API request failed (${response.status})`);
    }
    const page = (await response.json()) as LabFeatureCollection;
    if (
      page.scenario_id !== "v0_3_equal_group_internal_simulation_r150" ||
      page.release_state !== "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY"
    ) {
      throw new Error("API returned an unexpected scenario contract");
    }
    features.push(...page.features);
    pageToken = page.next_page_token;
    pageCount += 1;
    if (pageCount > 10) throw new Error("API pagination exceeded the safety limit");
  } while (pageToken);

  return features;
}

export async function fetchPreviewLabCells(
  previewUrl: string,
  signal?: AbortSignal,
): Promise<LabCellFeature[]> {
  const response = await fetch(previewUrl, { signal });
  if (!response.ok) {
    throw new Error(`Preview fixture request failed (${response.status})`);
  }
  const payload = (await response.json()) as LabFeatureCollection;
  const scoredCells = payload.features.filter(
    (feature) =>
      feature.properties.scores
        .v0_3_equal_group_internal_simulation_r150 !== null,
  ).length;
  if (
    payload.scenario_id !== "v0_3_equal_group_internal_simulation_r150" ||
    payload.release_state !== "READ_ONLY_PREVIEW_UNCOMMITTED" ||
    payload.features.length !== 3420 ||
    payload.total_cells !== 3420 ||
    payload.scoreable_cells !== 1589 ||
    scoredCells !== 1589 ||
    payload.next_page_token !== null ||
    payload.truncated !== false ||
    payload.features.some(
      (feature) =>
        feature.properties.specification_state !== "PENDING_COMMITTED_LOCK" ||
        feature.properties.evidence_state !== "NO_TRUSTED_RESULT" ||
        feature.properties.operational_use !== "PROHIBITED" ||
        feature.properties.preview_source_job_id !== payload.source_job_id,
    )
  ) {
    throw new Error("Preview fixture returned an unexpected internal contract");
  }
  return payload.features;
}

export async function fetchNetworkCells(
  apiBaseUrl: string,
  scenarioId: NetworkScenarioId,
  abstractIteration: number,
  signal?: AbortSignal,
): Promise<NetworkCellsResponse> {
  const url = new URL(
    "/api/v1/lab/v0.3/network-redistribution/cells",
    apiBaseUrl,
  );
  url.searchParams.set("scenario_id", scenarioId);
  url.searchParams.set("abstract_iteration", String(abstractIteration));
  const response = await fetch(url, { signal });
  if (!response.ok) throw new Error(`Network cells request failed (${response.status})`);
  const payload = (await response.json()) as NetworkCellsResponse;
  if (
    payload.kind !== "NETWORK_REDISTRIBUTION_CELLS" ||
    payload.cells.length !== 3420 ||
    payload.metadata.scenario_id !== scenarioId ||
    payload.metadata.abstract_iteration !== abstractIteration ||
    payload.metadata.evidence_state !== "NO_TRUSTED_RESULT" ||
    payload.metadata.operational_use !== "PROHIBITED"
  ) {
    throw new Error("Network cells returned an unexpected internal contract");
  }
  return payload;
}

export async function fetchNetworkLinks(
  apiBaseUrl: string,
  scenarioId: NetworkScenarioId,
  signal?: AbortSignal,
): Promise<NetworkLinksResponse> {
  const url = new URL(
    "/api/v1/lab/v0.3/network-redistribution/links",
    apiBaseUrl,
  );
  url.searchParams.set("scenario_id", scenarioId);
  const response = await fetch(url, { signal });
  if (!response.ok) throw new Error(`Network links request failed (${response.status})`);
  const payload = (await response.json()) as NetworkLinksResponse;
  if (
    payload.kind !== "NETWORK_REDISTRIBUTION_LINKS" ||
    payload.metadata.scenario_id !== scenarioId ||
    payload.metadata.evidence_state !== "NO_TRUSTED_RESULT" ||
    payload.metadata.operational_use !== "PROHIBITED"
  ) {
    throw new Error("Network links returned an unexpected internal contract");
  }
  return payload;
}
