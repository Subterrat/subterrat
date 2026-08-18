# GPT Pro review prompt — SubTerrat v0.3

You are reviewing a pre-registered, deterministic spatial scenario for a public-health research prototype. Be skeptical. Do not optimize any feature, weight, radius, threshold, or model choice against the retrospective Rat Radar results. Distinguish construct validity, data quality, spatial methodology, validation design, and presentation safety.

## Non-negotiable boundaries

- The output is a `scenario_score`, rank, and top-area flag—not a rat-presence probability, population estimate, field-confirmed risk, or dispatch decision.
- Rat Radar is post-freeze validation-only. It cannot be a feature, label, tuning source, radius selector, weight selector, or model selector.
- Existing 889 approved Taipei reports are development-exposed retrospective data. They may be used once after the scenario is locked, not to revise the primary specification.
- v0.1 food and sewer system-type layers remain frozen references.
- v0.2 contains five literature-directed sewer diagnostics. Only system type currently passes its gate; elevation, diameter, depth, and age are conditional or blocked. A v0.2 composite is therefore simulation-only.
- Urban renewal is a new disturbance proxy. It is not the same construct as abandoned buildings and does not prove actual construction timing.
- No public release or intervention is authorized. Evidence state remains `NO_TRUSTED_RESULT`.

## Literature boundary

1. Seattle sewer study: sanitary systems, higher surface elevation, narrower pipes, shallower pipes, and older pipes were associated with rat presence. The study supports feature eligibility and direction, not Taipei coefficients.
   - https://doi.org/10.1007/s11252-022-01255-2
   - https://doi.org/10.5061/dryad.mw6m90603
2. A Netherlands trapping study found a positive relationship between restaurant counts and relative rat abundance and used a 150 m radius as an average local activity range. We treat 150 m only as a local-neighborhood assumption, not a construction-displacement coefficient.
   - https://doi.org/10.1007/s11252-024-01513-5
3. A Chicago study found a small positive association between construction/demolition permits and rat complaints, while warning that permit timing may not represent actual activity and that complaints reflect visibility and reporting behavior.
   - https://doi.org/10.1093/jue/juab006
4. Vancouver trapping research supports abandoned parcels/building condition as habitat correlates but does not justify treating urban-renewal records as abandoned-building density.
   - https://doi.org/10.1371/journal.pone.0097776

## Current BigQuery evidence

v0.1 retrospective reference:

- food Top 10% area: 447/889 reports, Capture 50.28%, Lift over area 5.03.
- sewer system-type: Capture about 1.01%, Lift about 0.087.

v0.2 data coverage and gates:

- system type: 1,801 cells, 55.68% city area, PASS reused v0.1 component.
- surface elevation: 1,761 cells, 54.56% area, conditional semantics/coverage.
- diameter/depth/age: 1,608 cells each, 49.78% area.
- depth blocked pending an authority-backed outlier rule.
- age blocked pending installation-date concentration review.
- five-metric complete-case intersection: 1,589 cells, 49.28% area.

Outcome-free structural comparison with food v0.1:

| Sewer diagnostic | Food score correlation | Top-area Jaccard |
| --- | ---: | ---: |
| pipe age | 0.414 | 0.211 |
| pipe depth | -0.015 | 0.080 |
| pipe diameter | -0.100 | 0.063 |
| system type | 0.054 | 0.003 |
| surface elevation | -0.353 | 0.002 |
| five-metric complete-case mean | -0.007 | 0.111 |

Interpretation proposed by the team: the five-metric composite is spatially distinct from food, but this does not show that it is better. Coverage and metric gates remain the dominant limitation.

Urban-renewal CSV profile:

- 2,365 rows, all coordinates in a broad Taipei review box.
- 2,280 exact coordinates; 85 duplicate excess rows, 168 rows in duplicate-coordinate groups.
- 1,604 planning/designation rows: excluded from primary.
- 85 government-led rows with unknown phase: excluded.
- 347 completed rows: excluded.
- 79 approved-project rows with blank/unknown status: excluded.
- 250 approved-rebuilding rows with explicit non-complete statuses: included as proxy, covering 197 S2 L15 cells before any radius.
- Source owner, license, provider publication date, and snapshot completeness are not documented in the repository; source lineage remains blocked.

## Proposed v0.3 primary specification

```text
Food(c) = frozen v0.1 food percentile

SewerDiagnostic(c) = mean(
  sewer system type,
  surface elevation,
  inverse pipe diameter,
  inverse pipe depth,
  pipe age
)
only on five-metric complete-case cells

Renewal150(c) = empirical percentile of included renewal-point count
within 150 m of the S2 cell's eligible geometry

ScenarioV03(c) = (Food(c) + SewerDiagnostic(c) + Renewal150(c)) / 3
```

Rules:

- Equal group weights `1/3, 1/3, 1/3`; no external coefficients and no outcome fitting.
- Missing group means the combined score is null; no dynamic reweighting.
- Primary radius 150 m; 0 m and 300 m are pre-registered sensitivities and cannot replace the primary based on retrospective results.
- Primary selection is the highest-ranked cells covering 10% of total Taipei eligible area, with all threshold ties included and actual selected share reported.
- Retrospective denominator includes all 889 eligible reports, including reports in unscored cells; report unscored outcome fraction.
- Primary retrospective outputs: Capture@10% total area, Lift over actual selected area, Delta Capture versus frozen food-only, and unscored outcome fraction.
- Secondary descriptive outputs: Top-area Jaccard and score correlation.
- React lab labels the score as candidate/not frozen/not probability; blocked/missing cells use hatch patterns and limitation codes.

## Review questions

1. Is it scientifically defensible to materialize this as a clearly labeled simulation-only scenario while sewer and urban-renewal gates remain blocked, or should the three-group composite be withheld entirely?
2. Is `approved rebuilding + explicit non-complete status` a defensible disturbance proxy for exploration? If not, what narrower non-outcome-based rule is supportable with these fields?
3. Is 150 m a defensible primary local-neighborhood radius given the cited evidence, provided we explicitly prohibit biological-diffusion claims? Should 150 m be sensitivity-only instead?
4. Are equal group weights the least assumption-heavy choice, or does the 49.28% sewer complete-case coverage make any three-group ranking misleading regardless of weighting?
5. Is selecting 10% of total Taipei area and retaining all 889 reports in the denominator the correct comparison under partial coverage? Identify any more honest alternative that does not tune against outcomes.
6. Are correlation and Top-area Jaccard sufficient for the outcome-free food-versus-sewer comparison? Name any additional descriptive spatial statistic that is useful without turning into model selection.
7. Audit the API/UI language and identify any phrase that could still be misread as prediction, probability, actual construction activity, or rat diffusion.
8. Give a final recommendation: `PROCEED_AS_SIMULATION`, `REVISE_BEFORE_SIMULATION`, or `WITHHOLD_COMPOSITE`. List required changes separately from optional improvements.

## Required response format

1. Verdict and confidence
2. Critical issues
3. Required changes before BigQuery composite materialization
4. Required changes before retrospective validation
5. Optional improvements
6. Short rewritten primary specification, if revision is recommended
