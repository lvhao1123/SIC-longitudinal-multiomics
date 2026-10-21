# SIC longitudinal multiomics

This study evaluates molecular associations with subsequent 60-day mortality in a fixed Day-1 sepsis-induced coagulopathy cohort. RNA-seq and plasma protein measurements are analysed in separate landmark models. The study does not establish SIC specificity, individual-level prediction or causality.

The repository contains analysis code, aggregate results, figure source data, data definitions and software environment records. Individual-level clinical records, expression matrices, protein matrices, weights, scores, model objects and centre-identity mappings are not included. OMIX011182 requires controlled access through the National Genomics Data Center.

## Reproduction routes

- `analysis/run_authorized.R`: checks controlled-access inputs and can run the primary statistical models in a separate local output directory.
- `analysis/run_current_tables.py`: assembles Table 1 and Supplementary Tables S1–S18 from aggregate results. Clinical displays use 40 Cox contrasts; Table 1 and S9 use the same descriptive summary.
- `plotting/`: produces quantitative figures from aggregate source data. The figure index maps all parts, scripts and inputs.
- `landmark_sensitivity/`: contains the common-patient analysis (A), patient-level Hallmark-score analysis (B), and Supplementary Tables S19 and S20. Its Python comparison script uses the supplied A/B and primary aggregate results without refitting models.

See `REPRODUCIBILITY.md` for commands and limitations, `docs/INPUT_CONTRACT.md` for derived-input requirements, and `DATA_ACCESS.md` for access restrictions. Code and content licences are specified separately; they do not grant access to controlled data or MSigDB resources.

Thirteen result workbooks cover Supplementary Tables S1–S20. The primary table-assembly route covers S1–S18; `landmark_sensitivity/TABLE_MAP.tsv` maps S19 and S20 to their source tables. The table-assembly templates are separate from these result workbooks. Controlled-input construction is documented in `docs/CONTROLLED_INPUT_ROUTES.md`.
