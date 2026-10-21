# Landmark sensitivity analyses

This directory contains the R code for the common-patient analysis (A) and the patient-level Hallmark-score survival analysis (B). The accompanying tables contain aggregate results. Patient-level expression matrices, clinical records and intermediate score matrices are not included.

## Inputs and configuration

Copy `config.example.json` to `config.json` and supply the three paths below. Paths may be absolute or relative to the configuration file. `config.json` is excluded from Git. Alternatively, set the `SIC_CONFIG` environment variable to a configuration file stored elsewhere.

| Key | Required input |
| --- | --- |
| `source_root` | Directory containing the two prepared matrices listed below. |
| `clinical` | Delimited clinical landmark file with the required columns below. |
| `hallmark` | Hallmark v2026.1 human gene-symbol GMT file. |

The matrix files, relative to `source_root`, are:

- `01_RNA_TMM/RNA_TMM_logCPM_gene_by_sample.rds`: the 14,541-gene TMM logCPM matrix.
- `02_Protein/Protein_QC_gene_by_sample.rds`: the 3,875-entry protein matrix.

Both RDS files contain finite numeric matrices with gene symbols as row names and sample names as column names. Use the prepared matrices corresponding to the reported analysis; these scripts do not normalise or filter raw measurements.

The clinical file requires `SampleName`, `PatientID`, `day_num`, `sTatus` and `surv_time`. `day_num` is 1, 3 or 5. `sTatus` is 1 for death within 60 days of ICU admission and 0 otherwise. `surv_time` is the elapsed time from ICU admission to death, or 60 for administrative censoring. The sample-name prefix before the first underscore identifies the recruiting centre. Outcomes and centre membership must agree across samples from the same patient.

Patient-level inputs remain subject to the source repository's access conditions. A code download does not provide access to those inputs. The aggregate tables can be inspected without them, but rerunning the patient-level models requires the prepared matrices and clinical file.

## Software

The analyses used R 4.4.2 with `survival` 3.7-0, `fgsea` 1.32.4, `data.table` 1.18.2.1 and `jsonlite` 2.0.0. The recorded R session information specifies the remaining dependencies. The scripts use the installed R library; the optional `SIC_R_LIBRARY` environment variable can prepend another library directory. They do not install packages or download inputs.

## Run

From this directory, use a new output directory outside the code package and the input matrix directory:

```text
Rscript --vanilla R/preflight.R ../../sensitivity_results
Rscript --vanilla R/run_A.R ../../sensitivity_results RNA
Rscript --vanilla R/run_A.R ../../sensitivity_results Protein
Rscript --vanilla R/run_B.R ../../sensitivity_results
```

The first command checks matrix dimensions, sample matching, outcome definitions and the six risk sets. It does not fit models. The following commands run the analyses and may take substantially longer. Existing files with the same output names can be replaced; use a separate output directory for each run.

The scripts locate `common.R` beside the entry script, so the code and output directories need not be colocated.

## Outputs

- `results/A/`: six feature-level Cox tables and six complete Hallmark tables for analysis A.
- `results/B/all_pathway_cox.tsv`: all 300 pathway-by-landmark rows for analysis B.
- `qa/`: coverage, risk-set counts and multiple-testing family summaries.
- `logs/`: execution logs and R session information.
- `local_cache/`: patient identifiers and patient-level score matrices used during the run. Keep this directory local and do not redistribute it with aggregate results.

Analysis A uses the same patients at all three landmarks within each molecular layer, with entry at day 4. It conditions on survival and complete sampling through Day 5; it does not isolate the effect of patient composition from the changed observation window. Analysis B tests patient-level mean-rank pathway scores rather than enrichment of feature-level Cox rankings. Neither analysis provides independent validation or re-evaluates the cross-omic models.

## Rebuild the aggregate comparisons and table data

The commands below use only the aggregate files included here. They do not require patient-level inputs or fit statistical models. Python 3.12.14, NumPy 2.3.5 and pandas 3.0.1 were used for these summaries; dependencies are listed in `environment/requirements.txt`.

```text
python scripts/summarise.py --results-root data --primary-results data/primary --output-dir ../../rebuilt_comparisons
python scripts/export_table_data.py --data-dir data --output-dir ../../table_data
```

Both output directories must be new. The first command rebuilds the five complete comparison TSV files from saved estimates. Compare them with `data/results/comparisons/`. The second exports the six data worksheets of Supplementary Tables S19 and S20 as TSV files, preserving source values and worksheet column order. It does not reproduce Excel formatting or the explanatory Notes sheets. The formatted workbooks are supplied in `supplementary_tables/`; `TABLE_MAP.tsv` records their data sources.

After rerunning models on controlled inputs, use that run's output directory as `--results-root`, keeping `--primary-results data/primary`. Saved primary and sensitivity estimates must refer to the same input definitions before they are compared.
