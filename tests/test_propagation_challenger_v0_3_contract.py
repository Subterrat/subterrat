import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "contracts" / "propagation_challenger_v0_3_candidate.json"
INPUT_MANIFEST_PATH = (
    ROOT / "contracts" / "network_redistribution_input_manifest_v0_3_candidate.json"
)
ARTIFACT_SCHEMA_PATH = (
    ROOT / "contracts" / "network_redistribution_artifacts_v0_3_candidate.json"
)
API_SCHEMA_PATH = ROOT / "contracts" / "network_redistribution_api_v0_3.schema.json"


class PropagationChallengerV03ContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
        cls.input_manifest_bytes = INPUT_MANIFEST_PATH.read_bytes()
        cls.input_manifest = json.loads(cls.input_manifest_bytes)
        cls.artifact_schema_bytes = ARTIFACT_SCHEMA_PATH.read_bytes()
        cls.artifact_schema = json.loads(cls.artifact_schema_bytes)
        cls.api_schema_bytes = API_SCHEMA_PATH.read_bytes()
        cls.api_schema = json.loads(cls.api_schema_bytes)

    def test_is_relative_internal_simulation_not_probability(self) -> None:
        self.assertEqual(
            self.contract["model_kind"],
            "DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION",
        )
        self.assertEqual(self.contract["use_state"], "INTERNAL_SIMULATION_ONLY")
        self.assertEqual(self.contract["evidence_state"], "NO_TRUSTED_RESULT")
        self.assertEqual(self.contract["operational_use"], "PROHIBITED")
        self.assertIsNone(
            self.contract["output_semantics"]["calibrated_probability"]
        )

    def test_rat_radar_cannot_select_simulation_parameters(self) -> None:
        policy = self.contract["outcome_policy"]
        self.assertFalse(
            policy["existing_889_reports_allowed_for_parameter_or_scenario_selection"]
        )
        self.assertEqual(policy["rat_radar_role"], "POST_LOCK_CONCORDANCE_ONLY")
        self.assertTrue(
            {
                "edge_selection",
                "transition_weight_selection",
                "continuation_parameter_selection",
                "iteration_count_selection",
                "scenario_selection",
            }.issubset(policy["forbidden_uses"])
        )

    def test_exact_infrastructure_is_not_served(self) -> None:
        graph = self.contract["analysis_graph"]
        self.assertEqual(graph["state_unit"], "S2_LEVEL_15_ANALYSIS_CELL")
        self.assertEqual(graph["raw_pipe_node_id_role"], "QA_ONLY_NOT_GRAPH_IDENTITY")
        self.assertFalse(graph["exact_pipe_geometry_in_api_or_ui"])
        self.assertEqual(
            self.contract["ui_policy"]["schematic_link_geometry"],
            "CELL_CENTROID_TO_CELL_CENTROID_ONLY",
        )
        self.assertIn("SOURCE_VERTEX_ORDER", graph["sewer_route_identity"])
        self.assertIn("ELEMENTARY_EDGE", graph["sewer_route_identity"])
        self.assertIn("POSITIVE_LENGTH", graph["sewer_route_identity"])

    def test_elementary_edge_traversal_is_source_ordered_and_fail_closed(self) -> None:
        graph = self.contract["analysis_graph"]
        self.assertIn("ST_POINTN", graph["elementary_edge_construction"])
        self.assertNotIn("ST_LINELOCATEPOINT(segment", json.dumps(graph))
        self.assertEqual(graph["traversal_fraction_quantization_places"], 15)
        self.assertEqual(graph["traversal_fraction_rounding_mode"], "ROUND_HALF_EVEN")
        self.assertIn("WHOLE_SEGMENT_COVERED", graph["out_of_universe_policy"])
        self.assertIn("EXCLUDE_SOURCE_SEGMENT", graph["nonunique_interval_action"])
        self.assertEqual(
            graph["traversal_sort_key"],
            [
                "source_snapshot_id",
                "source_resource_id",
                "segment_id",
                "edge_ordinal",
                "quantized_interval_low",
                "quantized_interval_high",
                "cell_id",
            ],
        )

    def test_all_geometry_roles_use_the_same_frozen_eligible_geometry(self) -> None:
        graph = self.contract["analysis_graph"]
        expected = (
            "devjam26aug17tpe-1270.subterrat_curated."
            "analysis_cells.eligible_geom"
        )
        for field in (
            "sewer_traversal_intersection_geometry",
            "generic_adjacency_geometry",
            "eligible_area_geometry",
            "map_render_geometry",
        ):
            self.assertEqual(graph[field], expected)
        self.assertIn("FROM_CELL_ID_NOT_EQUAL", graph["generic_adjacency_rule"])
        self.assertIn("SHARED_BOUNDARY_LENGTH", graph["generic_adjacency_rule"])

    def test_primary_and_numeric_sensitivity_buckets_are_row_stochastic(self) -> None:
        scenarios = {
            scenario["scenario_id"]: scenario
            for scenario in self.contract["scenarios"]
        }
        for scenario_id in (
            "n0_uniform_sewer_link_comparator",
            "n1_metric_weighted_sewer_links",
            "n2_generic_cell_adjacency_sensitivity",
        ):
            scenario = scenarios[scenario_id]
            self.assertAlmostEqual(
                scenario["self_allocation_bucket"]
                + scenario["sewer_link_bucket"]
                + scenario["generic_adjacency_bucket"],
                1.0,
            )
        self.assertEqual(
            self.contract["transition_rule"]["matrix"],
            "ROW_STOCHASTIC_NONNEGATIVE_FINITE",
        )
        self.assertEqual(
            self.contract["transition_rule"]["abstract_iteration_range"], [0, 8]
        )

    def test_review_revisions_remove_renewal_effect_and_time_animation(self) -> None:
        self.assertIn(
            "NOT_USED_IN_NETWORK_TRANSITION",
            self.contract["metric_roles"]["approved_rebuilding_admin_site_r150"],
        )
        self.assertFalse(self.contract["ui_policy"]["autoplay"])
        self.assertFalse(self.contract["ui_policy"]["playback_control"])
        self.assertIn("NO_HEAT_KERNEL", self.contract["ui_policy"]["rendering"])
        self.assertEqual(
            self.contract["output_semantics"]["normalization_scope"],
            "LOCKED_RUN_GLOBAL_ALL_SCENARIOS_AND_ITERATIONS",
        )

    def test_simulation_artifacts_do_not_use_prediction_namespace(self) -> None:
        artifact_policy = self.contract["artifact_policy"]
        self.assertEqual(artifact_policy["dataset"], "subterrat_simulations")
        self.assertTrue(artifact_policy["prediction_dataset_or_namespace_forbidden"])
        self.assertTrue(
            all("predictions" not in table for table in artifact_policy["tables"])
        )

    def test_input_manifest_identity_and_hash_are_immutable_contract_inputs(self) -> None:
        expected_hash = hashlib.sha256(self.input_manifest_bytes).hexdigest()
        self.assertEqual(
            self.contract["input_manifest_id"],
            self.input_manifest["input_manifest_id"],
        )
        self.assertEqual(
            self.contract["input_manifest_path"],
            "contracts/network_redistribution_input_manifest_v0_3_candidate.json",
        )
        self.assertEqual(self.contract["input_manifest_candidate_sha256"], expected_hash)
        self.assertIn("Rat Radar raw rows", self.input_manifest["forbidden_sources"])
        self.assertEqual(
            self.input_manifest["parent_v0_3_lock"]["current_state"],
            "PENDING_COMMITTED_PARENT_LOCK",
        )
        self.assertTrue(
            self.input_manifest["finalization_policy"][
                "finalized_manifest_required_before_any_simulation_run"
            ]
        )
        for source_name in (
            "cell_universe",
            "food_seed",
            "pipe_geometry",
            "sewer_attribute",
            "parent_v0_3_lock",
        ):
            selected = self.input_manifest[source_name]["selected_content_identity"]
            self.assertIsNone(selected["selected_content_sha256"])
            self.assertIn("REQUIRED_IN_FINALIZED_MANIFEST", selected["selected_content_sha256_state"])

    def test_numerical_pipeline_is_canonical_and_hashable(self) -> None:
        numeric = self.contract["numerical_pipeline"]
        self.assertEqual(numeric["calculation_type"], "BIGNUMERIC")
        self.assertEqual(numeric["rounding_mode"], "ROUND_HALF_EVEN")
        self.assertEqual(numeric["canonical_scales"]["transition_value"], 24)
        self.assertEqual(numeric["canonical_scales"]["recurrence_product"], 30)
        self.assertEqual(numeric["canonical_scales"]["unit_mass_state"], 24)
        self.assertEqual(numeric["canonical_scales"]["source_reinjection_term"], 30)
        self.assertEqual(numeric["api_decimal_serialization"], "FIXED_12_DECIMAL_STRING")
        self.assertEqual(numeric["canonical_content_hash"]["algorithm"], "SHA256")
        self.assertEqual(numeric["negative_zero_action"], "SERIALIZE_AS_POSITIVE_ZERO")
        self.assertIn("stored_raw_seed values", numeric["quantization_order"][1])
        self.assertIn(
            "combined nonself transition once",
            " ".join(numeric["quantization_order"]),
        )
        self.assertIn(
            "source reinjection term",
            " ".join(numeric["quantization_order"]),
        )

    def test_graph_quality_scopes_are_explicit_and_internal_connectivity_is_unknown(self) -> None:
        quality = self.contract["required_graph_quality"]
        self.assertIn(
            "NORMATIVE_REGISTRY_contracts/network_redistribution_artifacts_v0_3_candidate.json_quality_registry",
            quality,
        )
        self.assertIn(
            "internal_cell_connectivity_state_NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL",
            quality,
        )
        self.assertIn(
            "ALL_3420_CELLS_IN_EVERY_GRAPH_SCOPE_ISOLATES_AS_SINGLE_VERTEX_COMPONENTS",
            quality,
        )
        self.assertFalse(any("internal_geometry_components" in item for item in quality))

    def test_api_cell_and_link_contracts_preserve_support_semantics(self) -> None:
        api = self.contract["api_policy"]
        self.assertEqual(
            api["link_route"],
            "/api/v1/lab/v0.3/network-redistribution/links",
        )
        self.assertEqual(
            api["cell_response_schema"]["relative_synthetic_network_state"],
            "FIXED_12_DECIMAL_STRING_0_TO_1",
        )
        self.assertIn("SELF_ONLY", api["cell_support_state_enum"])
        self.assertIn("link_class", api["link_response_schema"])
        self.assertIn("ONLY_LINKS_ACTIVE", api["link_response_scope"])
        self.assertIn(
            "OVERLAY_HATCH_ON_FIXED_SCALE_STATE_FILL",
            self.contract["ui_policy"]["missing_or_unsupported_rendering"],
        )

    def test_artifact_and_api_schema_hashes_are_pinned(self) -> None:
        self.assertEqual(
            self.contract["artifact_schema_contract_sha256"],
            hashlib.sha256(self.artifact_schema_bytes).hexdigest(),
        )
        self.assertEqual(
            self.contract["api_schema_contract_sha256"],
            hashlib.sha256(self.api_schema_bytes).hexdigest(),
        )
        table_contracts = {
            item["table"]: item for item in self.artifact_schema["table_contracts"]
        }
        self.assertIn(
            "subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation",
            table_contracts,
        )
        self.assertTrue(
            all(table["primary_key_fields_in_order"] for table in table_contracts.values())
        )
        self.assertTrue(all(table["fields"] for table in table_contracts.values()))

    def test_api_wire_schema_uses_signed_ids_strings_and_dual_class_rows(self) -> None:
        defs = self.api_schema["$defs"]
        self.assertEqual(defs["cellId"]["pattern"], "^(0|-?[1-9][0-9]*)$")
        self.assertEqual(defs["cell"]["properties"]["eligible_geojson"]["type"], "string")
        self.assertEqual(
            defs["cellsMetadata"]["allOf"][1]["properties"]["display_scale_max"]["$ref"],
            "#/$defs/decimal24Positive",
        )
        self.assertTrue(defs["sewerLink"]["properties"]["metric_eligible"]["const"])
        self.assertEqual(
            defs["genericLink"]["properties"]["metric_eligible"]["type"],
            "null",
        )
        self.assertEqual(
            defs["coordinate"]["properties"]["longitude"]["$ref"],
            "#/$defs/decimal7",
        )
        wire = self.api_schema["x-normative-wire-rules"]
        self.assertIn("STRICTLY_LESS", wire["link_orientation"])
        self.assertEqual(
            wire["link_limitation_codes_by_class"]["SYNTHETIC_SEWER_LINK"],
            [
                "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
                "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
            ],
        )
        self.assertEqual(
            wire["cell_limitation_code_assignment"]["final_array"],
            "EXACT_UNION_OF_APPLICABLE_RULES_LEXICOGRAPHIC_ASCENDING_UNIQUE_NO_OTHER_CODES",
        )

    def test_input_selectors_are_unique_and_executable(self) -> None:
        sewer = self.input_manifest["sewer_attribute"]
        self.assertIn("source_snapshot_id =", sewer["required_predicate"])
        self.assertIn("variant_id IN", sewer["required_predicate"])
        self.assertIn("EXACTLY_ONE_ROW_PER", sewer["uniqueness_assertion"])
        parent = self.input_manifest["parent_v0_3_lock"]
        self.assertEqual(
            parent["required_lock_id"],
            "v0.3-internal-simulation-concordance-lock",
        )
        self.assertEqual(parent["expected_matching_rows"], 1)
        self.assertEqual(parent["zero_or_multiple_match_action"], "FAIL_MATERIALIZATION")
        self.assertNotIn("specification_state", parent["required_fields"])
        self.assertIn(
            "EXACTLY_ONE_ROW_PER",
            self.input_manifest["cell_universe"]["uniqueness_assertion"],
        )
        self.assertIn(
            "EXACTLY_ONE_ROW_PER",
            self.input_manifest["food_seed"]["uniqueness_assertion"],
        )
        self.assertIn(
            "EXACTLY_EQUALS",
            self.input_manifest["food_seed"]["cell_set_assertion"],
        )
        pipe = self.input_manifest["pipe_geometry"]
        self.assertEqual(pipe["expected_source_census_rows"], 198091)
        self.assertEqual(
            pipe["source_census_predicate"],
            "source_snapshot_id = '979ee9ac61c536177f4ee929afb2fcf44313023f6ae6d3f0585a7ffd26ea0911'",
        )
        self.assertIn(
            "geom_wgs84_wkb_hex_or_null",
            pipe["selected_content_identity"]["hashed_fields_in_order"],
        )

    def test_quality_registry_and_run_id_order_are_normative(self) -> None:
        self.assertEqual(
            self.artifact_schema["run_id_ordered_fields"],
            [
                "contract_hash",
                "finalized_input_manifest_hash",
                "sql_bundle_hash",
                "code_revision",
                "cell_universe_selected_content_sha256",
                "food_seed_selected_content_sha256",
                "pipe_geometry_selected_content_sha256",
                "sewer_attribute_selected_content_sha256",
                "parent_v0_3_lock_selected_content_sha256",
            ],
        )
        registry = self.artifact_schema["quality_registry"]
        self.assertEqual(
            registry["connected_component_id"],
            "MINIMUM_SIGNED_INT64_CELL_ID_IN_COMPONENT",
        )
        self.assertEqual(len(registry["source_segment_terminal_classification_precedence"]), 9)
        metric_names = {row["metric_name"] for row in registry["records"]}
        self.assertIn("neighbor_degree_by_cell", metric_names)
        self.assertIn("source_segment_terminal_classification_count", metric_names)
        self.assertIn("parallel_source_segment_duplicate_excess_total", metric_names)
        self.assertTrue(
            all(
                "value_formula" in row
                and "canonical_input_fields" in row
                and "rounding_or_integer_rule" in row
                for row in registry["records"]
            )
        )
        transition_table = next(
            row
            for row in self.artifact_schema["table_contracts"]
            if "synthetic_network_transitions" in row["table"]
        )
        transition_fields = {field["name"] for field in transition_table["fields"]}
        self.assertNotIn("sewer_allocation", transition_fields)
        self.assertNotIn("generic_adjacency_allocation", transition_fields)
        self.assertIn("transition_value", transition_fields)
        self.assertNotIn("transition_limitation_codes", transition_fields)
        quality_table = next(
            row
            for row in self.artifact_schema["table_contracts"]
            if "synthetic_network_quality" in row["table"]
        )
        quality_fields = {field["name"] for field in quality_table["fields"]}
        self.assertNotIn("limitation_codes", quality_fields)


if __name__ == "__main__":
    unittest.main()
