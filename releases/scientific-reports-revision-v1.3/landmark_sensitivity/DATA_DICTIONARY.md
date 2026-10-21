# Aggregate results

The files in `data/results/` and `data/qa/` report feature-level models, pathway-level models and cohort-level summaries. They do not contain individual expression values, survival records, patient identifiers or centre identifiers. `TABLE_MAP.tsv` links the data to Supplementary Tables S19 and S20.

## Files

| Files relative to `data/` | Contents |
| --- | --- |
| `results/A/{RNA,Protein}_{D1,D3,D5}_feature_cox.tsv` | One row per molecular feature in the common-patient analysis. Each RNA table contains 14,541 rows; each protein table contains 3,875 rows. |
| `results/A/{RNA,Protein}_{D1,D3,D5}_Hallmark.tsv` | All 50 Hallmark pathways at each landmark, including sets outside the enrichment coverage range. |
| `results/B/all_pathway_cox.tsv` | All 300 molecular-layer-by-landmark-by-pathway combinations. There are 294 estimated models and six protein rows with insufficient pathway coverage. |
| `results/comparisons/A_all_Hallmark_vs_original.tsv` | The 300 common-patient Hallmark results alongside the corresponding primary enrichment results. |
| `results/comparisons/A_summary.tsv` | Six within-landmark comparisons between common-patient and primary results. |
| `results/comparisons/A_cross_time_correlations.tsv` | Twelve between-landmark comparisons, separately for each molecular layer and analysis. |
| `results/comparisons/A_diagnostics.tsv` | Counts of feature fits, numerical warnings, proportional-hazards diagnostics and eligible enrichment results in the six common-patient datasets. |
| `results/comparisons/B_all_pathways_with_original_GSEA.tsv` | The 300 pathway-score model rows alongside the primary feature-ranking enrichment results. |
| `qa/preflight_counts.tsv` | Feature counts and cohort sizes for the six primary and common-patient datasets. |
| `qa/A_RNA_coverage.tsv`, `qa/A_Protein_coverage.tsv` | The measured-member count and enrichment eligibility of every Hallmark pathway. |
| `qa/B_family_summary.tsv` | Risk-set counts, coverage, model estimability and BH family sizes for the six pathway-score analyses. |

`A` denotes the common-patient analysis and `B` the patient-level Hallmark-score analysis. `original`, `Original` and `primary` refer to the corresponding primary landmark analysis, not to raw patient data. `RNA` and `Protein` identify the molecular layer; `D1`, `D3` and `D5` identify nominal sampling landmarks.

## Shared model fields

| Fields | Definition |
| --- | --- |
| `N`, `Events` | Patients and deaths in the fitted model. |
| `Riskset_N`, `Riskset_Events` | Patients and deaths in the eligible landmark risk set before pathway coverage is considered. |
| `Centres`, `Event_centres` | Number of represented centres and number with at least one death. These are counts, not centre codes. |
| `Entry`, `entry_day` | Follow-up entry in days from ICU admission: 4 for analysis A and 0, 2 or 4 for the Day 1, 3 or 5 models in analysis B. |
| `gene_symbol` | Molecular feature label. |
| `logHR`, `HR` | Cox coefficient and its exponentiated hazard ratio for a one-standard-deviation higher feature or pathway score within the model's dataset. |
| `lower95`, `upper95` | Lower and upper limits of the 95% confidence interval for the hazard ratio. |
| `SE`, `z`, `pval` | Coefficient standard error, Wald statistic and two-sided Wald P value in Cox tables. |
| `PH_p` | Nominal proportional-hazards test P value based on Schoenfeld residuals. It is a diagnostic, not a model-selection rule. |
| `fit_ok`, `Status` | Whether a model could be estimated and its estimation or coverage status. |
| `warning`, `error` | Numerical diagnostics reported during fitting, when present. |
| `padj`, `FDR` | Benjamini–Hochberg adjusted P value. The family depends on the table, as specified below. |

Patients who survived through day 60 were administratively censored at day 60. Analysis A includes 317 RNA patients with 53 subsequent deaths and 114 protein patients with 14 subsequent deaths. The three models within each molecular layer use the same patients and the same follow-up entry.

## Hallmark enrichment fields

`pathway` identifies the Hallmark gene set. In these tables, `pval` is the enrichment P value rather than a Cox-model P value. `ES` and `NES` are the enrichment score and normalised enrichment score. Positive NES indicates enrichment towards positive mortality-association ranks. `coverage` or `covered` counts measured pathway members, `size` counts members contributing to enrichment, and `ranked_features` counts features in the Cox Wald ranking.

`eligible` identifies pathways with 15–500 measured members. `family_n` gives the BH family size: 49 RNA pathways and 44 protein pathways at each landmark. Every table retains all 50 Hallmark rows. `log2err` is the estimated uncertainty of the log2 P value returned by fgsea. `precision_retry` records a numerical precision retry. `leadingEdge_text` lists leading-edge gene symbols separated by semicolons. Comparison-table suffixes `_A` and `_original` distinguish the common-patient and primary analyses.

The feature-level Cox-table `padj` values use all 14,541 RNA features or 3,875 protein features within each landmark as the BH family. They are distinct from the pathway-level enrichment family.

## Pathway-score fields

`Pathway` or `pathway` identifies the Hallmark set. `Coverage` counts measured pathway members, and `Coverage_min` is 10. `Eligible` indicates whether coverage meets that minimum. `Score_mean` and `Score_SD` summarise the patient-level scores before within-risk-set standardisation; no individual scores are included.

Scores are the mean fractional rank of the measured pathway members minus 0.5. Each model includes one standardised pathway score and is stratified by centre. `Nfamily` and `BH_denominator` give the pathway-score testing family: 50 for RNA and 48 for protein at each landmark. `FDR` uses those six separate families. `original_GSEA_NES`, `original_GSEA_P` and `original_GSEA_FDR` are primary feature-ranking enrichment results shown for comparison. Enrichment and pathway-score models test different questions.

## Summary fields

| Fields | Definition |
| --- | --- |
| `feature_rank_rho`, `NES_rho` | Spearman correlations of feature-level Wald ranks and pathway NES values, respectively. The comparison is defined by the table and row. |
| `NES_direction_agree`, `NES_pairs` | Number of matching NES signs and number of evaluable pathway pairs. |
| `Original_FDR05`, `A_FDR05` | Number of pathways with adjusted P <0.05 in the primary or common-patient analysis. |
| `Original_sig_same_direction` | Number of originally significant pathways retaining their NES sign. |
| `Original_sig_retained_FDR05` | Number of originally significant pathways also reaching adjusted P <0.05 in analysis A. |
| `Comparison`, `Analysis` | Landmark pair and analysis defining a cross-landmark correlation. |
| `features`, `fits_ok`, `warnings` | Number of molecular features, estimated models and models with numerical warnings. |
| `PH_nominal_below_05` | Number of feature models with nominal proportional-hazards P <0.05. |
| `GSEA_eligible`, `GSEA_estimable`, `GSEA_precision_retries` | Number of eligible pathways, available enrichment results and numerical precision retries. |
| `original_N`, `original_events`, `A_N`, `A_events` | Patient and event counts in the primary and common-patient datasets. |
| `Total_pathways`, `Insufficient_coverage`, `Estimated`, `Failed_eligible` | Reported pathway rows, rows below the coverage threshold, estimated models and failed eligible models. |
| `FDR_below_0_05` | Number of estimated pathway-score models with FDR <0.05. |

`NA` indicates an unavailable or inapplicable value, not zero. Empty warning or error fields mean no message was recorded. The full-pathway comparison tables retain rows below the coverage threshold.

The common-patient comparison changes the population and the start of follow-up for earlier measurements. It does not isolate patient-composition effects or establish within-patient trajectories. Neither analysis independently validates the primary results or evaluates the cross-omic models.
