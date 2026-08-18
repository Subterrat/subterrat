# SubTerrat v0.3 GPT Pro review record

- Review surface: ChatGPT Pro
- Conversation: https://chatgpt.com/c/6a834dff-6408-83e8-8bb6-8d30dd199a47
- Reviewed: 2026-08-18 (Asia/Taipei)
- Verdict: `REVISE_BEFORE_SIMULATION`
- Confidence: high
- Outcome access during review: the prompt contained previously known aggregate
  v0.1 retrospective results, but no raw Rat Radar rows. The reviewer explicitly
  prohibited using those results for feature, radius, weight, or model selection.

This file records the actionable disposition. It is not a claim that an external
model is Ground Truth.

## Accepted

- A deterministic, outcome-blinded composite may exist as an internal blocked
  simulation; it is not a probability, operational ranking, or trusted result.
- Equal group weights are the least contestable unsupported numerical choice,
  provided they are described as an assumption. Effective weights are food `1/3`,
  renewal `1/3`, and each of the five sewer diagnostics `1/15`.
- Missing groups remain `NULL`; dynamic reweighting is prohibited.
- A fixed 150 m window may remain the preregistered primary analysis window, with
  0 m and 300 m fixed sensitivities, if its geometry and non-biological meaning are
  explicit.
- The citywide 10% total-area budget with all 889 reports retained in the
  denominator is a defensible primary map-as-delivered comparison.

## Required changes accepted for implementation

1. Rename the renewal construct to an administrative redevelopment proxy. The
   available statuses do not establish demolition, construction, displacement,
   or rat disturbance.
2. Count unique administrative sites, not duplicate source rows. Preserve row,
   source-record-number, exact-coordinate, and duplicate counts for audit.
3. Freeze the spatial rule as distance `<= radius_m` from an eligible clipped cell
   polygon using BigQuery `GEOGRAPHY` metres. Call it a
   `cell_footprint_buffer`, not a home-range, displacement, or diffusion radius.
4. State transformations exactly: BigQuery cell-weighted `PERCENT_RANK`; lower-is-
   higher sewer values use descending raw-value rank, not numerical reciprocals;
   renewal zero counts map to zero; ties share a percentile.
5. Preserve every sewer and renewal gate explicitly. The composite gate remains
   `BLOCKED_INTERNAL_SIMULATION` regardless of the arithmetic result.
6. Rank only complete-case support and label the value
   `rank_within_scoreable_support`. Keep total and scoreable area, actual selected
   area after ties, threshold, and tie excess.
7. Lock specification identity before any further outcome access: contract hash,
   SQL hash, input snapshots, clean Git revision, review receipt, and exact output
   schema.
8. Rename the Rat Radar step to a one-shot retrospective report-location
   concordance evaluation. Add a fixed common-support food comparison and retain
   exact numerators and denominators.
9. Correct the Vancouver DOI from `10.1371/journal.pone.0097725` to
   `10.1371/journal.pone.0097776`.

## Rejected claims

- A canonical or generally consumable “primary v0.3 risk score” before gates pass.
- Calling approved non-complete cases active construction or disturbance.
- Calling the 150 m window a rat movement, diffusion, displacement, or causal
  influence radius.
- Calling the complete-case rank a Taipei-wide rank.
- Calling the 889-report exercise external, predictive, field, or rat-presence
  validation.
- Interpreting a difference from food as component attribution or using the result
  to change features, weights, radii, support, or normalization.

## Source-lineage follow-up

Repository and public-site investigation identifies the likely source as the
[Taipei Urban Renewal Map](https://www.ur.org.tw/classroom/map_view/11) maintained
by the Urban Regeneration R&D Foundation. The page embeds Google My Maps map ID
`1HIJwAuZc21A7FnoPBaIWPARkF7g` and states `All Rights Reserved`. No explicit data
reuse license, provider publication date, snapshot completeness statement, field
dictionary, or status taxonomy was found. Therefore lineage is improved from
unknown-owner to identified-but-unlicensed and remains blocked for publication.

The source `編號` field is populated on all 250 included rows but has 248 unique
values. Two duplicate numbers (`北494`, `北521`) show repeated administrative
records; exact-coordinate collapse alone would remove only one duplicate. v0.3
therefore uses a source-record-number administrative site key while keeping its
undocumented semantics as a limitation.

## Implementation decision

Proceed only as `V0_3_BLOCKED_INTERNAL_SIMULATION`. Component layers may be
materialized and viewed before the lock. The equal-group composite must not be
materialized until the revised contract and SQL are committed, hashed, reviewed,
and locked. Evidence remains `NO_TRUSTED_RESULT`; operational use is prohibited.

Post-review component materialization on 2026-08-18 produced 248 administrative
sites from 250 source rows; 247 sites matched the analysis-cell universe at each
registered window. SQL 15 completed all four statements and assertions. No v0.3
composite, map payload, lock, or Rat Radar concordance was materialized.
