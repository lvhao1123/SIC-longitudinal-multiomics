# Reproduction instructions

## Environment

The analyses used R 4.4.2, including survival 3.7-0 and fgsea 1.32.4. R session information is available in `environment/`, `plotting/environment/` and `landmark_sensitivity/environment/`. Use the session record for the analysis being run: the root renv lock does not include every dependency used in the additional analyses. Scripts do not install dependencies automatically.

## Controlled-input statistical route

Set SIC_PROJECT_DIR to the repository, CMAISE_DATA_DIR to authorised inputs, and SIC_OUTPUT_DIR to a new private output directory outside both. See `config/` and `docs/INPUT_CONTRACT.md` for field and file requirements.

```
Rscript --vanilla analysis/run_authorized.R --preflight-only
```

This command checks inputs without fitting models. The `--run-historical-pipeline` option runs the primary computations in a separate local directory; it does not assemble the final presentation tables. Those computations include the original 41-contrast clinical family. The reported clinical tables and Figure S9 use the 40 retained contrasts, with BH adjustment implemented in `revision/clinical/01_update_clinical_BH40.R`. `CODE_CHAIN.tsv` lists the other analyses and their input requirements. Some earlier annotation and QC preparation steps are not fully documented; running downstream models does not resolve those source limitations.

## Current aggregate table route

```
python analysis/run_current_tables.py NEW_TABLE_OUTPUT
```

This entry derives diagnostic counts from aggregate results and prepares Table 1 and S9 from the same descriptive summary. It checks source hashes and assembles the table blocks without fitting models or performing statistical tests. S1 excludes PCT, and S2 uses BH-adjusted values for the 40 retained clinical contrasts. This route covers S1–S18, not S19 or S20.

## Common-patient and pathway-score analyses

`landmark_sensitivity/README.md` describes the inputs and commands for analysis A (common patients and a shared follow-up window) and analysis B (patient-level Hallmark scores). Rerunning these models requires the controlled-access matrices and clinical records. These inputs are not distributed here.

The following command runs from the repository root and rebuilds five comparison tables using only the supplied aggregate results:

```text
python landmark_sensitivity/scripts/summarise.py --results-root landmark_sensitivity/data --primary-results landmark_sensitivity/data/primary --output-dir NEW_COMPARISON_OUTPUT
```

`NEW_COMPARISON_OUTPUT` must not already exist. The script joins the A/B and primary results and calculates correlations, direction agreement and diagnostic counts. It does not refit Cox models, rerun enrichment or recalculate FDR. `landmark_sensitivity/TABLE_MAP.tsv` links these tables and the pathway-score family summary to S19 and S20. `landmark_sensitivity/DATA_DICTIONARY.md` defines the fields and testing families. Thirteen result workbooks cover S1–S20 in total, in addition to the separate table-assembly templates.

## Figure route

See `plotting/README.md` and `plotting/FIGURE_CODE_DATA_INDEX.tsv` for commands, physical sizes and inputs for the 19 figures comprising 23 parts. R generates the quantitative figures from aggregate data. Reproducing those displays does not rerun the patient-level statistical analyses or validate experimental QC definitions.

## Interpretation and reproducibility

Reassembling tables and figures checks their correspondence with aggregate results. It is distinct from reproducing statistical models using patient-level inputs. Primary and sensitivity analyses have separate model specifications and multiple-testing families. The small number of Day-5 protein deaths, residual selection bias and uncertainty about the QC input scale and grouping limit interpretation. Analysis A also changes the follow-up window for earlier measurements; analysis B asks a different question from feature-ranking enrichment. Neither provides independent validation.

Runtime and memory use depend on the hardware and analysis. Session records document the software environments used.

