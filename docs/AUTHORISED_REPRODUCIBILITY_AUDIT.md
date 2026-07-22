# Authorised reproducibility audit

This audit was run locally against the controlled CMAISE files obtained through
the approved data-access process. Controlled inputs and participant-level audit
outputs remain outside Git. Only aggregate QA summaries are tracked.

## Execution

The canonical statistical scripts in
`outputs/SIC_reanalysis_2026-07-11/code/` were executed without modifying their
frozen bytes or model definitions. The authorised runner uses the same stage
order and inserts one non-statistical production bridge after
`09_build_clinical_tables.R`: `analysis/build_clinical_workbook.R` assembles the
already-generated clinical CSV tables into the Excel workbook required by the
frozen final QA. It does not refit Cox, IPW, GSEA or cross-omics models.

## Results

- All 65 frozen QA checks passed.
- All RNA and protein sample/event counts and fitted-feature counts matched the
  frozen QA.
- Of 93 common CSV tables, 82 were byte-identical and nine GSEA tables were
  numerically equivalent within `1e-12` (maximum absolute difference
  `1.021405182655144e-14`).
- The remaining two differing CSVs were generated metadata: the file manifest
  and final QA table. No core result table differed beyond tolerance.
- Pre/post SHA256 auditing confirmed that all 201 files in the original frozen
  result snapshot remained unchanged.

The machine-readable aggregate evidence is in
`qa/authorised_reproducibility_summary.tsv`. The file-level classification in
`qa/authorised_reproducibility_file_audit.tsv` contains relative filenames and
aggregate comparison results only; it contains no participant identifiers or
individual weights.

## Interpretation

The authorised rerun supports computational reproducibility of the frozen
analysis under the archived Windows/R environment. It does not change the
study estimands, statistical results, inferential thresholds or the restricted
data-access conditions.
