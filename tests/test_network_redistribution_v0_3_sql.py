import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql" / "structural"


class NetworkRedistributionV03SqlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.graph = (SQL_DIR / "20_build_synthetic_network_graph_v0_3.sql").read_text(
            encoding="utf-8"
        )
        cls.redistribution_sql = (
            SQL_DIR / "21_run_synthetic_network_redistribution_v0_3.sql"
        ).read_text(encoding="utf-8")
        cls.quality = (
            SQL_DIR / "22_finalize_synthetic_network_quality_v0_3.sql"
        ).read_text(encoding="utf-8")

    def test_all_materialization_scripts_are_commit_and_review_gated(self) -> None:
        for sql in (self.graph, self.redistribution_sql, self.quality):
            self.assertIn("@repository_state = 'COMMITTED_SOURCE'", sql)
            self.assertIn(
                "@review_verdict = 'APPROVE_FOR_INTERNAL_IMPLEMENTATION'", sql
            )
            self.assertIn("@finalized_input_manifest_hash", sql)
            self.assertIn("@parent_v0_3_lock_content_hash", sql)
            self.assertNotIn("Rat Radar", sql)
            self.assertNotIn("rat_radar", sql.lower())

    def test_graph_uses_source_ordered_elementary_edges_and_full_census(self) -> None:
        self.assertIn("expected_source_census_rows", (ROOT / "contracts" / "network_redistribution_input_manifest_v0_3_candidate.json").read_text())
        self.assertIn("COUNT(*) = 198091", self.graph)
        self.assertIn("ST_POINTN(candidate.geom_wgs84, edge_ordinal)", self.graph)
        self.assertIn("ST_MAKELINE", self.graph)
        self.assertIn("ST_LINELOCATEPOINT(elementary_edge", self.graph)
        self.assertIn("POSITIVE_LENGTH_BOUNDARY_OVERLAP", self.graph)
        self.assertIn("NONUNIQUE_TRAVERSAL", self.graph)
        self.assertIn("OUTSIDE_OR_GAPPED_CELL_UNIVERSE", self.graph)
        self.assertIn("previous_cell_id != cell_id", self.graph)
        self.assertIn("LEAST(cell_id, next_cell_id)", self.graph)
        self.assertNotIn("start_node_id", self.graph)
        self.assertNotIn("end_node_id", self.graph)

    def test_transition_rounds_combined_classes_once_and_returns_unused_mass_to_self(self) -> None:
        self.assertIn(
            "SUM(sewer_allocation_unrounded + generic_allocation_unrounded)",
            self.redistribution_sql,
        )
        self.assertIn("CAST(1 AS BIGNUMERIC) - COALESCE", self.redistribution_sql)
        self.assertIn("row-stochastic", self.redistribution_sql)
        self.assertNotIn("transition_limitation_codes", self.redistribution_sql)
        self.assertIn("n0_uniform_sewer_link_comparator", self.redistribution_sql)
        self.assertIn("n1_metric_weighted_sewer_links", self.redistribution_sql)
        self.assertIn("n2_generic_cell_adjacency_sensitivity", self.redistribution_sql)

    def test_recurrence_and_display_scale_are_canonical(self) -> None:
        self.assertIn("WHILE iteration_number <= 8", self.redistribution_sql)
        self.assertIn("CAST('0.25' AS BIGNUMERIC)", self.redistribution_sql)
        self.assertIn("CAST('0.75' AS BIGNUMERIC)", self.redistribution_sql)
        self.assertIn("30,\n        'ROUND_HALF_EVEN'", self.redistribution_sql)
        self.assertIn("ROUND(MAX(unit_mass_state), 24", self.redistribution_sql)
        self.assertIn("COUNT(DISTINCT display_scale_max) = 1", self.redistribution_sql)
        self.assertNotIn("CURRENT_TIMESTAMP", self.redistribution_sql)

    def test_quality_registry_has_component_and_numeric_gates(self) -> None:
        self.assertIn("component_iteration < 3420", self.quality)
        self.assertIn("MIN(neighbor.component_id)", self.quality)
        self.assertIn("neighbor_degree_by_cell", self.quality)
        self.assertIn("parallel_source_segment_duplicate_excess_total", self.graph)
        self.assertIn("state_mass_absolute_residual", self.quality)
        self.assertIn("recurrence_max_absolute_residual", self.quality)
        self.assertNotIn("limitation_codes", self.quality)
        self.assertIn("COUNT(*) = COUNT(DISTINCT quality_record_id)", self.quality)

    def test_output_namespaces_are_internal_not_predictions(self) -> None:
        combined = "\n".join((self.graph, self.redistribution_sql, self.quality))
        self.assertIn("subterrat_simulations", combined)
        for table in (
            "synthetic_network_cell_links_v0_3_candidate",
            "synthetic_network_transitions_v0_3_internal_simulation",
            "synthetic_network_states_v0_3_internal_simulation",
            "synthetic_network_quality_v0_3_internal_simulation",
            "map_synthetic_network_cells_v0_3_internal_simulation",
            "schematic_cell_links_v0_3_internal_simulation",
        ):
            self.assertIn(table, combined)


if __name__ == "__main__":
    unittest.main()
