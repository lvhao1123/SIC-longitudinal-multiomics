# Logical input data dictionary

| Logical input | Required filename/location | Role | Access |
|---|---|---|---|
| `clinical` | `SIC_504_baseline_carried_forward_annotation.csv` | SIC cohort, baseline covariates and survival outcome | Controlled |
| `raw_clinical` | parent directory: `OMIX011182-01.csv` | Source sample annotation and time-point mapping | Controlled |
| `rna_counts` | `OMIX011182-04.txt` | Whole-blood RNA counts | Controlled |
| `protein` | `OMIX011182-05.xlsx` | Plasma protein abundance matrix | Controlled |
| `protein_qc` | `SIC_detailed_analysis_phase1/13_protein_feature_qc.csv` | Frozen protein feature-QC decisions | Controlled derivative |
| `hallmark` | `h.all.v2026.1.Hs.symbols.gmt` | Licensed Hallmark gene-set definitions | Licensed resource |

The runner validates only file presence before execution. It does not copy, hash or inspect participant-level content during the data-free contract check.
