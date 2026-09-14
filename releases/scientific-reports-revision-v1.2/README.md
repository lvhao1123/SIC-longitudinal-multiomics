# SIC longitudinal multiomics

This study evaluates molecular associations with subsequent 60-day mortality in a fixed Day-1 sepsis-induced coagulopathy cohort. RNA-seq and plasma protein measurements are analysed in separate landmark models. The study does not establish SIC specificity, individual-level prediction or causality.

The repository contains analysis code, aggregate results, figure source data, data definitions and software environment records. Individual-level clinical records, expression matrices, protein matrices, weights, scores, model objects and centre-identity mappings are not included. OMIX011182 requires controlled access through the National Genomics Data Center.

## Reproduction routes

- `analysis/run_authorized.R`: validates authorised controlled inputs; model execution requires an explicit execution flag and a new private output directory.
- `analysis/run_current_tables.py`: generates current tables from the supplied aggregate results. Clinical displays use 40 Cox contrasts after PCT withdrawal; Table 1 and S9 share one normalised descriptive summary.
- `plotting/`: produces quantitative figures from aggregate source data. The figure index maps all parts, scripts and inputs.

See `REPRODUCIBILITY.md` for commands and limitations, `docs/INPUT_CONTRACT.md` for derived-input requirements, and `DATA_ACCESS.md` for access restrictions. Code and content licences are specified separately; they do not grant access to controlled data or MSigDB resources.

Supplementary Tables S1–S18 are included. Controlled-input construction is documented in `docs/CONTROLLED_INPUT_ROUTES.md`.
