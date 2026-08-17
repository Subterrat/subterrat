export type Position = [number, number];

export type PolygonGeometry = {
  type: "Polygon";
  coordinates: Position[][];
};

export type MultiPolygonGeometry = {
  type: "MultiPolygon";
  coordinates: Position[][][];
};

export type LabReleaseState =
  | "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY"
  | "READ_ONLY_PREVIEW_UNCOMMITTED";

export type LabSpecificationState = "LOCKED" | "PENDING_COMMITTED_LOCK";

export type Scores = {
  food_market_v0_1: number | null;
  sewer_system_type_v0_1: number | null;
  sewer_system_type_v0_2: number | null;
  surface_elevation_v0_2: number | null;
  connected_pipe_diameter_v0_2: number | null;
  connected_pipe_depth_v0_2: number | null;
  connected_pipe_age_v0_2: number | null;
  sewer_attribute_index_v0_2: number | null;
  approved_rebuilding_admin_site_buffer_0m: number | null;
  approved_rebuilding_admin_site_buffer_150m: number | null;
  approved_rebuilding_admin_site_buffer_300m: number | null;
  v0_3_equal_group_internal_simulation_r150: number | null;
};

export type LabCellFeature = {
  type: "Feature";
  id: string;
  geometry: PolygonGeometry | MultiPolygonGeometry;
  properties: {
    cell_id: string;
    centroid_longitude: number;
    centroid_latitude: number;
    scenario_id: "v0_3_equal_group_internal_simulation_r150";
    release_state: LabReleaseState;
    score_semantics: "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY";
    specification_state: LabSpecificationState;
    use_state: "INTERNAL_SIMULATION_ONLY";
    evidence_state: "NO_TRUSTED_RESULT";
    operational_use: "PROHIBITED";
    calibrated_probability: null;
    scenario_state: string;
    support_state?: "SCORED_COMPLETE_CASE" | "MISSING_SEWER_COMPLETE_CASE";
    total_cell_count?: number;
    scoreable_city_area_share?: number;
    preview_source_job_id?: string;
    rank_within_scoreable_support: number | null;
    preregistered_selected_scenario_area: boolean;
    scores: Scores;
    limitation_codes: string[];
  };
};

export type LabFeatureCollection = {
  type: "FeatureCollection";
  scenario_id: "v0_3_equal_group_internal_simulation_r150";
  release_state: LabReleaseState;
  source_job_id?: string;
  scoreable_cells?: number;
  total_cells?: number;
  scoreable_city_area_share?: number;
  features: LabCellFeature[];
  next_page_token: string | null;
  truncated: false;
};

export type ScoreKey = keyof Scores;

export type NetworkScenarioId =
  | "n0_uniform_sewer_link_comparator"
  | "n1_metric_weighted_sewer_links"
  | "n2_generic_cell_adjacency_sensitivity";

export type NetworkCellSupportState =
  | "METRIC_SEWER_SUPPORTED"
  | "NO_ELIGIBLE_SEWER_NEIGHBOR"
  | "SEWER_ATTRIBUTE_MISSING"
  | "GENERIC_ADJACENCY_ONLY"
  | "SELF_ONLY";

export type NetworkMetadata = {
  schema_version: "0.3.0";
  contract_hash: string;
  finalized_input_manifest_hash: string;
  run_id: string;
  scenario_id: NetworkScenarioId;
  use_state: "INTERNAL_SIMULATION_ONLY";
  evidence_state: "NO_TRUSTED_RESULT";
  operational_use: "PROHIBITED";
  global_limitation_codes: string[];
};

export type NetworkCell = {
  cell_id: string;
  eligible_geojson: string;
  relative_synthetic_network_state: string;
  sewer_attribute_available: boolean;
  eligible_sewer_neighbor_count: number;
  eligible_generic_neighbor_count: number;
  self_only_transition_row: boolean;
  cell_support_state: NetworkCellSupportState;
  cell_limitation_codes: string[];
};

export type NetworkCellsResponse = {
  kind: "NETWORK_REDISTRIBUTION_CELLS";
  metadata: NetworkMetadata & {
    abstract_iteration: number;
    normalization_scope: "LOCKED_RUN_GLOBAL_ALL_SCENARIOS_AND_ITERATIONS";
    display_scale_max: string;
  };
  cells: NetworkCell[];
};

export type NetworkCoordinate = {
  longitude: string;
  latitude: string;
};

export type NetworkLink = {
  from_cell_id: string;
  to_cell_id: string;
  link_class: "SYNTHETIC_SEWER_LINK" | "GENERIC_CELL_ADJACENCY";
  active_in_scenario: true;
  metric_eligible: true | null;
  schematic_from_centroid: NetworkCoordinate;
  schematic_to_centroid: NetworkCoordinate;
  link_limitation_codes: string[];
};

export type NetworkLinksResponse = {
  kind: "NETWORK_REDISTRIBUTION_LINKS";
  metadata: NetworkMetadata;
  links: NetworkLink[];
};
